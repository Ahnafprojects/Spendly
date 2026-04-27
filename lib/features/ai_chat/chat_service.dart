import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/currency_settings.dart';
import '../../shared/services/env_config.dart';
import '../../shared/services/offline_store.dart';
import '../budget/budget_repository.dart';
import '../transaction/transaction_repository.dart';
import '../analytics/analytics_repository.dart';
import '../../shared/data/chat_database.dart';
import '../../shared/models/transaction_model.dart';
import 'chat_models.dart';

class ChatService {
  final SupabaseClient _supabase;
  final OfflineStore _offlineStore;
  final AnalyticsRepository _analyticsRepository;
  final TransactionRepository _transactionRepository;
  final BudgetRepository _budgetRepository;

  ChatService({
    SupabaseClient? supabase,
    required OfflineStore offlineStore,
    required AnalyticsRepository analyticsRepository,
    required TransactionRepository transactionRepository,
    required BudgetRepository budgetRepository,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _offlineStore = offlineStore,
       _analyticsRepository = analyticsRepository,
       _transactionRepository = transactionRepository,
       _budgetRepository = budgetRepository;

  Future<String> _resolveUserId() async {
    final authId = _supabase.auth.currentUser?.id;
    if (authId != null && authId.isNotEmpty) {
      await _offlineStore.saveLastUserId(authId);
      return authId;
    }
    final cached = await _offlineStore.readLastUserId();
    if (cached != null && cached.isNotEmpty) return cached;
    throw Exception('User belum login');
  }

  Future<ChatReply> sendMessage({
    required String userMessage,
    required List<ChatMessage> conversationHistory,
    String? accountId,
    String? spaceId,
  }) async {
    final groqApiKey = EnvConfig.get('GROQ_API_KEY');
    final groqModel = EnvConfig.get(
      'GROQ_MODEL',
      fallback: 'openai/gpt-oss-120b',
    );
    final groqBaseUrl = EnvConfig.get(
      'GROQ_BASE_URL',
      fallback: 'https://api.groq.com/openai/v1/chat/completions',
    );
    if (groqApiKey.trim().isEmpty) {
      throw Exception('GROQ_API_KEY belum diisi.');
    }

    final userId = await _resolveUserId();
    final context = await _buildFinanceContext(
      userId,
      userMessage: userMessage,
      accountId: accountId,
      spaceId: spaceId,
    );

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content':
            'Kamu adalah Spendly AI, asisten keuangan personal di aplikasi Spendly. '
            'Jawab dalam bahasa Indonesia yang natural, ringkas, akurat, dan grounded ke data user. '
            'Jangan mengada-ada. Jika data tidak cukup, bilang terus terang. '
            'Prioritaskan menjawab pertanyaan dari konteks keuangan yang diberikan. '
            'Jika user minta saran, berikan saran yang spesifik berdasarkan pola angkanya, bukan tips generik. '
            'Saat menyebut angka uang, gunakan format rupiah yang rapi. '
            'Kamu boleh menyimpulkan pola, tapi tandai sebagai perkiraan saat inferensi. '
            'Balas hanya JSON valid dengan shape: '
            '{"answer":"","follow_ups":["","",""],"sources":["","",""]}.',
      },
      {'role': 'system', 'content': jsonEncode(context)},
      ...conversationHistory
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .take(12)
          .map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': userMessage},
    ];

    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(groqBaseUrl));
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $groqApiKey',
      );
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'model': groqModel,
            'temperature': 0.3,
            'max_tokens': 1200,
            'messages': messages,
          }),
        ),
      );

      final response = await request.close();
      final raw = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Groq chat error ${response.statusCode}: $raw');
      }

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final content =
          ((((decoded['choices'] as List?)?.first as Map?)?['message']
                  as Map?)?['content'])
              ?.toString()
              .trim();
      if (content == null || content.isEmpty) {
        throw const FormatException('AI response kosong');
      }
      return _parseReply(content, context['source_summary'] as List<dynamic>?);
    } finally {
      client.close(force: true);
    }
  }

  ChatReply _parseReply(String raw, List<dynamic>? fallbackSources) {
    final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(cleaned) as Map);
      final reply = ChatReply.fromJson(decoded);
      if (reply.answer.isNotEmpty) {
        return ChatReply(
          answer: reply.answer,
          followUps: reply.followUps,
          sources: reply.sources.isNotEmpty
              ? reply.sources
              : (fallbackSources ?? const []).map((e) => e.toString()).toList(),
        );
      }
    } catch (_) {}
    return ChatReply(
      answer: cleaned,
      followUps: const [],
      sources: (fallbackSources ?? const []).map((e) => e.toString()).toList(),
    );
  }

  Future<Map<String, dynamic>> _buildFinanceContext(
    String userId, {
    required String userMessage,
    String? accountId,
    String? spaceId,
  }) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final monthTransactions = await _analyticsRepository
        .fetchTransactionsByDateRange(
          monthStart,
          monthEnd,
          accountId: accountId,
          spaceId: spaceId,
        );
    final recentTransactions = await _transactionRepository.fetchRecent(
      limit: 10,
      accountId: accountId,
      spaceId: spaceId,
    );
    final budgetUsage = await _budgetRepository.fetchBudgetUsage(
      monthStart,
      accountId: accountId,
      spaceId: spaceId,
    );
    final relevantTransactions = _searchRelevantTransactions(
      userMessage,
      pool: monthTransactions.length > recentTransactions.length
          ? monthTransactions
          : recentTransactions,
    );
    final topCategories = _analyticsRepository
        .getCategoryBreakdown(monthTransactions)
        .take(5)
        .map(
          (item) => {
            'category': item.category,
            'amount': item.amount,
            'formatted_amount': CurrencySettings.format(item.amount),
          },
        )
        .toList();

    var income = 0.0;
    var expense = 0.0;
    for (final tx in monthTransactions) {
      final isIncome =
          tx.type == 'income' ||
          (tx.type == 'transfer' && tx.transferDirection == 'in');
      final isExpense =
          tx.type == 'expense' ||
          (tx.type == 'transfer' && tx.transferDirection == 'out');
      if (isIncome) income += tx.amount;
      if (isExpense) expense += tx.amount;
    }

    return {
      'scope': {
        'user_id': userId,
        'account_id': accountId,
        'space_id': spaceId,
        'period': DateFormat('MMMM yyyy', 'id_ID').format(now),
      },
      'monthly_summary': {
        'income': income,
        'expense': expense,
        'savings': income - expense,
        'formatted_income': CurrencySettings.format(income),
        'formatted_expense': CurrencySettings.format(expense),
        'formatted_savings': CurrencySettings.format(income - expense),
      },
      'source_summary': [
        'berdasarkan ringkasan bulan ini',
        'berdasarkan 10 transaksi terbaru',
        if (budgetUsage.isNotEmpty) 'berdasarkan budget bulan ini',
        if (relevantTransactions.isNotEmpty)
          'berdasarkan transaksi yang cocok dengan pertanyaan',
      ],
      'top_categories': topCategories,
      'recent_transactions': recentTransactions
          .map(
            (tx) => {
              'date': DateFormat('yyyy-MM-dd').format(tx.date),
              'type': tx.type,
              'category': tx.category,
              'amount': tx.amount,
              'formatted_amount': CurrencySettings.format(tx.amount),
              'note': tx.note,
            },
          )
          .toList(),
      'matched_transactions': relevantTransactions
          .map(
            (tx) => {
              'date': DateFormat('yyyy-MM-dd').format(tx.date),
              'type': tx.type,
              'category': tx.category,
              'amount': tx.amount,
              'formatted_amount': CurrencySettings.format(tx.amount),
              'note': tx.note,
            },
          )
          .toList(),
      'budget_usage': budgetUsage
          .map(
            (b) => {
              'category': b.category,
              'usage_pct': b.usagePct,
              'is_over': b.isOver,
              'limit_amount': b.limitAmount,
              'spent_amount': b.spentAmount,
              'formatted_limit': CurrencySettings.format(b.limitAmount),
              'formatted_spent': CurrencySettings.format(b.spentAmount),
            },
          )
          .toList(),
    };
  }

  List<TransactionModel> _searchRelevantTransactions(
    String query, {
    required List<TransactionModel> pool,
  }) {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) return const [];

    DateTime? specificDate;
    final isoDateMatch = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(normalized);
    if (isoDateMatch != null) {
      specificDate = DateTime.tryParse(isoDateMatch.group(1)!);
    }

    final monthNames = <String, int>{
      'januari': 1,
      'februari': 2,
      'maret': 3,
      'april': 4,
      'mei': 5,
      'juni': 6,
      'juli': 7,
      'agustus': 8,
      'september': 9,
      'oktober': 10,
      'november': 11,
      'desember': 12,
      'january': 1,
      'february': 2,
      'march': 3,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'october': 10,
      'december': 12,
    };
    int? monthFilter;
    for (final entry in monthNames.entries) {
      if (normalized.contains(entry.key)) {
        monthFilter = entry.value;
        break;
      }
    }

    final words = normalized
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length >= 3)
        .toSet();

    final scored = <({TransactionModel tx, int score})>[];
    for (final tx in pool) {
      var score = 0;
      final haystack = '${tx.category} ${tx.note ?? ''} ${tx.type}'
          .toLowerCase();
      for (final word in words) {
        if (haystack.contains(word)) score += 2;
      }
      if (specificDate != null &&
          tx.date.year == specificDate.year &&
          tx.date.month == specificDate.month &&
          tx.date.day == specificDate.day) {
        score += 4;
      }
      if (monthFilter != null && tx.date.month == monthFilter) {
        score += 2;
      }
      if (normalized.contains('terakhir') || normalized.contains('last')) {
        score += 1;
      }
      if (score > 0) {
        scored.add((tx: tx, score: score));
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.tx.date.compareTo(a.tx.date);
    });
    return scored.take(5).map((item) => item.tx).toList();
  }
}

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(
    offlineStore: ref.watch(offlineStoreProvider),
    analyticsRepository: ref.watch(analyticsRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    budgetRepository: ref.watch(budgetRepositoryProvider),
  );
});

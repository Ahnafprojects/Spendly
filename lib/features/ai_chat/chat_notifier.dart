import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/data/chat_database.dart';
import '../account/account_notifier.dart';
import '../spaces/space_notifier.dart';
import 'chat_models.dart';
import 'chat_repository.dart';
import 'chat_service.dart';

class ChatUiState {
  final String activeSessionId;
  final List<ChatMessage> messages;
  final List<ChatSession> sessions;
  final bool isTyping;
  final List<String> suggestedFollowUps;
  final String? error;

  const ChatUiState({
    required this.activeSessionId,
    required this.messages,
    required this.sessions,
    required this.isTyping,
    required this.suggestedFollowUps,
    this.error,
  });

  ChatUiState copyWith({
    String? activeSessionId,
    List<ChatMessage>? messages,
    List<ChatSession>? sessions,
    bool? isTyping,
    List<String>? suggestedFollowUps,
    String? error,
  }) {
    return ChatUiState(
      activeSessionId: activeSessionId ?? this.activeSessionId,
      messages: messages ?? this.messages,
      sessions: sessions ?? this.sessions,
      isTyping: isTyping ?? this.isTyping,
      suggestedFollowUps: suggestedFollowUps ?? this.suggestedFollowUps,
      error: error,
    );
  }
}

class ChatNotifier extends AsyncNotifier<ChatUiState> {
  late final ChatRepository _repository;
  late final ChatService _service;
  StreamSubscription<List<ChatMessage>>? _messagesSub;
  StreamSubscription<List<ChatSession>>? _sessionsSub;

  @override
  FutureOr<ChatUiState> build() async {
    _repository = ref.watch(chatRepositoryProvider);
    _service = ref.watch(chatServiceProvider);
    final userName = Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.userMetadata?['full_name']
        ?.toString()
        .trim();
    final name = (userName == null || userName.isEmpty) ? 'teman' : userName;
    final sessionId = await _repository.ensureSession();
    await _repository.ensureWelcomeMessage(sessionId, name);

    _bindSessions();
    _bindMessages(sessionId);

    return ChatUiState(
      activeSessionId: sessionId,
      messages: await _repository.listMessages(sessionId),
      sessions: await _repository.watchSessions().first,
      isTyping: false,
      suggestedFollowUps: const [],
    );
  }

  void _bindSessions() {
    _sessionsSub?.cancel();
    _sessionsSub = _repository.watchSessions().listen((sessions) {
      final current = state.valueOrNull;
      if (current == null) return;
      state = AsyncData(current.copyWith(sessions: sessions, error: null));
    });
    ref.onDispose(() => _sessionsSub?.cancel());
  }

  void _bindMessages(String sessionId) {
    _messagesSub?.cancel();
    _messagesSub = _repository.watchMessages(sessionId).listen((messages) {
      final current = state.valueOrNull;
      if (current == null) return;
      state = AsyncData(
        current.copyWith(
          activeSessionId: sessionId,
          messages: messages,
          suggestedFollowUps: _extractLatestFollowUps(messages),
          error: null,
        ),
      );
    });
    ref.onDispose(() => _messagesSub?.cancel());
  }

  Future<void> openSession(String sessionId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    _bindMessages(sessionId);
    state = AsyncData(
      current.copyWith(
        activeSessionId: sessionId,
        messages: await _repository.listMessages(sessionId),
        suggestedFollowUps: _extractLatestFollowUps(
          await _repository.listMessages(sessionId),
        ),
        error: null,
      ),
    );
  }

  Future<void> startNewChat() async {
    final userName = Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.userMetadata?['full_name']
        ?.toString()
        .trim();
    final name = (userName == null || userName.isEmpty) ? 'teman' : userName;
    final sessionId = await _repository.startNewSession();
    await _repository.ensureWelcomeMessage(sessionId, name);
    await openSession(sessionId);
  }

  Future<void> clearCurrentChat() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final userName = Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.userMetadata?['full_name']
        ?.toString()
        .trim();
    final name = (userName == null || userName.isEmpty) ? 'teman' : userName;
    await _repository.clearCurrentSession(current.activeSessionId, name);
  }

  Future<void> sendMessage(String text) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final message = text.trim();
    if (message.isEmpty) return;

    await _repository.addMessage(
      sessionId: current.activeSessionId,
      role: 'user',
      content: message,
    );
    await _repository.updateTitleFromFirstUserMessage(current.activeSessionId);

    state = AsyncData(current.copyWith(isTyping: true, error: null));

    try {
      final reply = await _service.sendMessage(
        userMessage: message,
        conversationHistory: await _repository.listMessages(
          current.activeSessionId,
        ),
        accountId: ref.read(activeAccountIdProvider),
        spaceId: ref.read(activeSpaceIdProvider),
      );
      await _repository.addMessage(
        sessionId: current.activeSessionId,
        role: 'assistant',
        content: reply.answer,
        meta: ChatMessageMeta(
          followUps: reply.followUps,
          sources: reply.sources,
        ),
      );
      final latest = state.valueOrNull;
      if (latest != null) {
        state = AsyncData(
          latest.copyWith(
            isTyping: false,
            suggestedFollowUps: reply.followUps,
            error: null,
          ),
        );
      }
    } catch (e) {
      final latest = state.valueOrNull;
      if (latest != null) {
        state = AsyncData(
          latest.copyWith(isTyping: false, error: e.toString()),
        );
      }
    }
  }

  List<String> _extractLatestFollowUps(List<ChatMessage> messages) {
    for (final message in messages.reversed) {
      if (message.role != 'assistant') continue;
      final meta = ChatMessageMeta.decode(message.metadataJson);
      if (meta.followUps.isNotEmpty) return meta.followUps;
    }
    return const [];
  }
}

final chatNotifierProvider = AsyncNotifierProvider<ChatNotifier, ChatUiState>(
  () => ChatNotifier(),
);

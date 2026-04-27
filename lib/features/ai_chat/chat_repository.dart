import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/data/chat_database.dart';
import 'chat_models.dart';

class ChatRepository {
  final ChatDatabase _db;

  ChatRepository(this._db);

  Stream<List<ChatSession>> watchSessions() => _db.watchSessions();

  Stream<List<ChatMessage>> watchMessages(String sessionId) =>
      _db.watchMessages(sessionId);

  Future<String> ensureSession({String? sessionId}) async {
    final existing = await _db.listSessions();
    if (sessionId != null && existing.any((item) => item.id == sessionId)) {
      return sessionId;
    }

    if (existing.isNotEmpty) {
      return existing.first.id;
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    await _db.upsertSession(
      ChatSessionsCompanion.insert(id: id, createdAt: now, updatedAt: now),
    );
    return id;
  }

  Future<String> startNewSession() async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    await _db.upsertSession(
      ChatSessionsCompanion.insert(id: id, createdAt: now, updatedAt: now),
    );
    return id;
  }

  Future<List<ChatMessage>> listMessages(String sessionId) =>
      _db.listMessages(sessionId);

  Future<void> addMessage({
    required String sessionId,
    required String role,
    required String content,
    ChatMessageMeta? meta,
  }) async {
    final now = DateTime.now();
    await _db.insertMessage(
      ChatMessagesCompanion.insert(
        sessionId: sessionId,
        role: role,
        content: content,
        metadataJson: Value(meta?.encode()),
        createdAt: now,
      ),
    );
    await _db.touchSession(sessionId);
  }

  Future<void> ensureWelcomeMessage(String sessionId, String name) async {
    final messages = await _db.listMessages(sessionId);
    if (messages.isNotEmpty) return;
    await addMessage(
      sessionId: sessionId,
      role: 'assistant',
      content:
          'Halo $name! Aku Spendly AI. Tanyakan apa saja tentang keuanganmu.',
    );
  }

  Future<void> updateTitleFromFirstUserMessage(String sessionId) async {
    final messages = await _db.listMessages(sessionId);
    final firstUser = messages.where((m) => m.role == 'user').firstOrNull;
    if (firstUser == null) return;
    final text = firstUser.content.trim();
    final title = text.length <= 28 ? text : '${text.substring(0, 28)}...';
    await _db.updateSessionTitle(sessionId, title);
  }

  Future<void> clearCurrentSession(String sessionId, String name) async {
    await _db.clearSessionMessages(sessionId);
    await _db.updateSessionTitle(sessionId, 'Percakapan Baru');
    await ensureWelcomeMessage(sessionId, name);
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(chatDatabaseProvider));
});

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'chat_database.g.dart';

class ChatSessions extends Table {
  TextColumn get id => text()();
  TextColumn get title =>
      text().withDefault(const Constant('Percakapan Baru'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().references(ChatSessions, #id)();
  TextColumn get role => text()();
  TextColumn get content => text()();
  TextColumn get metadataJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [ChatSessions, ChatMessages])
class ChatDatabase extends _$ChatDatabase {
  ChatDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(chatMessages, chatMessages.metadataJson);
      }
    },
  );

  Future<List<ChatSession>> listSessions() {
    return (select(
      chatSessions,
    )..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])).get();
  }

  Stream<List<ChatSession>> watchSessions() {
    return (select(
      chatSessions,
    )..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])).watch();
  }

  Future<List<ChatMessage>> listMessages(String sessionId) {
    return (select(chatMessages)
          ..where((tbl) => tbl.sessionId.equals(sessionId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();
  }

  Stream<List<ChatMessage>> watchMessages(String sessionId) {
    return (select(chatMessages)
          ..where((tbl) => tbl.sessionId.equals(sessionId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .watch();
  }

  Future<void> upsertSession(ChatSessionsCompanion session) {
    return into(chatSessions).insertOnConflictUpdate(session);
  }

  Future<int> insertMessage(ChatMessagesCompanion message) {
    return into(chatMessages).insert(message);
  }

  Future<void> updateSessionTitle(String sessionId, String title) {
    return (update(
      chatSessions,
    )..where((tbl) => tbl.id.equals(sessionId))).write(
      ChatSessionsCompanion(
        title: Value(title),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> touchSession(String sessionId) {
    return (update(chatSessions)..where((tbl) => tbl.id.equals(sessionId)))
        .write(ChatSessionsCompanion(updatedAt: Value(DateTime.now())));
  }

  Future<void> clearSessionMessages(String sessionId) {
    return (delete(
      chatMessages,
    )..where((tbl) => tbl.sessionId.equals(sessionId))).go();
  }

  Future<void> deleteSession(String sessionId) async {
    await (delete(
      chatMessages,
    )..where((tbl) => tbl.sessionId.equals(sessionId))).go();
    await (delete(chatSessions)..where((tbl) => tbl.id.equals(sessionId))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'spendly_chat.sqlite'));
    return NativeDatabase(file);
  });
}

final chatDatabaseProvider = Provider<ChatDatabase>((ref) {
  final db = ChatDatabase();
  ref.onDispose(db.close);
  return db;
});

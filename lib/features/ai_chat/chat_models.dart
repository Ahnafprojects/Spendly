import 'dart:convert';

class ChatReply {
  final String answer;
  final List<String> followUps;
  final List<String> sources;

  const ChatReply({
    required this.answer,
    required this.followUps,
    required this.sources,
  });

  Map<String, dynamic> toJson() {
    return {'answer': answer, 'follow_ups': followUps, 'sources': sources};
  }

  factory ChatReply.fromJson(Map<String, dynamic> json) {
    return ChatReply(
      answer: (json['answer'] ?? '').toString(),
      followUps: ((json['follow_ups'] as List?) ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(3)
          .toList(),
      sources: ((json['sources'] as List?) ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(4)
          .toList(),
    );
  }

  String encode() => jsonEncode(toJson());

  factory ChatReply.decode(String raw) {
    return ChatReply.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }
}

class ChatMessageMeta {
  final List<String> followUps;
  final List<String> sources;

  const ChatMessageMeta({required this.followUps, required this.sources});

  factory ChatMessageMeta.empty() {
    return const ChatMessageMeta(followUps: [], sources: []);
  }

  Map<String, dynamic> toJson() {
    return {'follow_ups': followUps, 'sources': sources};
  }

  String encode() => jsonEncode(toJson());

  factory ChatMessageMeta.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return ChatMessageMeta.empty();
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return ChatMessageMeta(
        followUps: ((json['follow_ups'] as List?) ?? const [])
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .take(3)
            .toList(),
        sources: ((json['sources'] as List?) ?? const [])
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .take(4)
            .toList(),
      );
    } catch (_) {
      return ChatMessageMeta.empty();
    }
  }
}

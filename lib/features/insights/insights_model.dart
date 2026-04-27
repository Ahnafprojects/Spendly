import 'dart:convert';

enum InsightKind { warning, good, tip, trend }

InsightKind parseInsightKind(String value) {
  switch (value.trim().toLowerCase()) {
    case 'warning':
      return InsightKind.warning;
    case 'good':
      return InsightKind.good;
    case 'tip':
      return InsightKind.tip;
    default:
      return InsightKind.trend;
  }
}

String insightKindValue(InsightKind value) {
  switch (value) {
    case InsightKind.warning:
      return 'warning';
    case InsightKind.good:
      return 'good';
    case InsightKind.tip:
      return 'tip';
    case InsightKind.trend:
      return 'trend';
  }
}

class InsightItem {
  final String title;
  final String description;
  final InsightKind kind;
  final String category;

  const InsightItem({
    required this.title,
    required this.description,
    required this.kind,
    required this.category,
  });

  factory InsightItem.fromJson(Map<String, dynamic> json) {
    return InsightItem(
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      kind: parseInsightKind((json['kind'] ?? 'trend').toString()),
      category: (json['category'] ?? 'Lainnya').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'kind': insightKindValue(kind),
      'category': category,
    };
  }
}

class SupportingFact {
  final String label;
  final String value;

  const SupportingFact({required this.label, required this.value});

  factory SupportingFact.fromJson(Map<String, dynamic> json) {
    return SupportingFact(
      label: (json['label'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'label': label, 'value': value};
  }
}

class InsightsBundle {
  final InsightItem mainInsight;
  final List<InsightItem> weeklyFindings;
  final List<String> personalTips;
  final String prediction;
  final List<SupportingFact> supportingFacts;
  final List<InsightItem> history;
  final DateTime updatedAt;
  final String periodLabel;
  final String source;

  const InsightsBundle({
    required this.mainInsight,
    required this.weeklyFindings,
    required this.personalTips,
    required this.prediction,
    required this.supportingFacts,
    required this.history,
    required this.updatedAt,
    required this.periodLabel,
    required this.source,
  });

  factory InsightsBundle.fromJson(Map<String, dynamic> json) {
    return InsightsBundle(
      mainInsight: InsightItem.fromJson(
        Map<String, dynamic>.from(json['main_insight'] as Map),
      ),
      weeklyFindings: ((json['weekly_findings'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => InsightItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      personalTips: ((json['personal_tips'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      prediction: (json['prediction'] ?? '').toString(),
      supportingFacts: ((json['supporting_facts'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => SupportingFact.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      history: ((json['history'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => InsightItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.now(),
      periodLabel: (json['period_label'] ?? 'Bulan ini').toString(),
      source: (json['source'] ?? 'heuristic').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'main_insight': mainInsight.toJson(),
      'weekly_findings': weeklyFindings.map((item) => item.toJson()).toList(),
      'personal_tips': personalTips,
      'prediction': prediction,
      'supporting_facts': supportingFacts.map((item) => item.toJson()).toList(),
      'history': history.map((item) => item.toJson()).toList(),
      'updated_at': updatedAt.toIso8601String(),
      'period_label': periodLabel,
      'source': source,
    };
  }

  String encode() => jsonEncode(toJson());

  factory InsightsBundle.decode(String raw) {
    return InsightsBundle.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }
}

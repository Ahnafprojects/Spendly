class ReceiptItemData {
  final String name;
  final double? price;
  final int qty;
  final bool selected;
  final bool isUncertain;

  const ReceiptItemData({
    required this.name,
    required this.price,
    required this.qty,
    this.selected = true,
    this.isUncertain = false,
  });

  factory ReceiptItemData.fromJson(Map<String, dynamic> json) {
    return ReceiptItemData(
      name: (json['name'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble(),
      qty: (json['qty'] as num?)?.toInt() ?? 1,
      selected: json['selected'] != false,
      isUncertain: json['is_uncertain'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'qty': qty,
      'selected': selected,
      'is_uncertain': isUncertain,
    };
  }

  ReceiptItemData copyWith({
    String? name,
    double? price,
    int? qty,
    bool? selected,
    bool? isUncertain,
  }) {
    return ReceiptItemData(
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      selected: selected ?? this.selected,
      isUncertain: isUncertain ?? this.isUncertain,
    );
  }
}

class ReceiptData {
  final String? storeName;
  final DateTime? date;
  final double? totalAmount;
  final List<ReceiptItemData> items;
  final int confidence;
  final String suggestedCategory;
  final String imagePath;

  const ReceiptData({
    required this.storeName,
    required this.date,
    required this.totalAmount,
    required this.items,
    required this.confidence,
    required this.suggestedCategory,
    required this.imagePath,
  });

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date']?.toString();
    return ReceiptData(
      storeName: json['store_name']?.toString(),
      date: rawDate == null || rawDate.isEmpty
          ? null
          : DateTime.tryParse(rawDate),
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => ReceiptItemData.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      confidence: (json['confidence'] as num?)?.toInt() ?? 0,
      suggestedCategory: (json['suggested_category'] ?? 'Lainnya').toString(),
      imagePath: (json['image_path'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'store_name': storeName,
      'date': date?.toIso8601String().split('T').first,
      'total_amount': totalAmount,
      'items': items.map((item) => item.toJson()).toList(),
      'confidence': confidence,
      'suggested_category': suggestedCategory,
      'image_path': imagePath,
    };
  }

  ReceiptData copyWith({
    String? storeName,
    DateTime? date,
    double? totalAmount,
    List<ReceiptItemData>? items,
    int? confidence,
    String? suggestedCategory,
    String? imagePath,
  }) {
    return ReceiptData(
      storeName: storeName ?? this.storeName,
      date: date ?? this.date,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      confidence: confidence ?? this.confidence,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

class ReceiptTransactionDraft {
  final double amount;
  final String category;
  final String? note;
  final DateTime? date;
  final ReceiptData? receiptData;

  const ReceiptTransactionDraft({
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    this.receiptData,
  });
}

class ReceiptScanArgs {
  final String? transactionId;

  const ReceiptScanArgs({this.transactionId});
}

class ReceiptReviewArgs {
  final String imagePath;
  final String? transactionId;

  const ReceiptReviewArgs({required this.imagePath, this.transactionId});
}

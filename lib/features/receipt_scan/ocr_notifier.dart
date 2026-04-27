import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'receipt_data_model.dart';
import 'receipt_scan_service.dart';

class OcrState {
  final bool isScanning;
  final ReceiptData? receiptData;
  final String? error;
  final File? imageFile;
  final int processingStep;

  const OcrState({
    required this.isScanning,
    required this.receiptData,
    required this.error,
    required this.imageFile,
    required this.processingStep,
  });

  factory OcrState.initial() {
    return const OcrState(
      isScanning: false,
      receiptData: null,
      error: null,
      imageFile: null,
      processingStep: 0,
    );
  }

  OcrState copyWith({
    bool? isScanning,
    ReceiptData? receiptData,
    String? error,
    File? imageFile,
    int? processingStep,
  }) {
    return OcrState(
      isScanning: isScanning ?? this.isScanning,
      receiptData: receiptData ?? this.receiptData,
      error: error,
      imageFile: imageFile ?? this.imageFile,
      processingStep: processingStep ?? this.processingStep,
    );
  }
}

class OcrNotifier extends Notifier<OcrState> {
  @override
  OcrState build() => OcrState.initial();

  Future<File?> pickFromGallery() async {
    final file = await ref.read(receiptScanServiceProvider).pickFromGallery();
    if (file != null) {
      state = state.copyWith(imageFile: file, error: null, processingStep: 0);
    }
    return file;
  }

  Future<ReceiptData?> scan(File imageFile) async {
    state = state.copyWith(
      isScanning: true,
      imageFile: imageFile,
      error: null,
      processingStep: 1,
    );
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(processingStep: 2);
      final result = await ref
          .read(receiptScanServiceProvider)
          .scanReceipt(imageFile);
      state = state.copyWith(
        isScanning: false,
        receiptData: result,
        processingStep: 3,
        error: null,
      );
      return result;
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        processingStep: 0,
        error: _mapError(e.toString()),
      );
      return null;
    }
  }

  void updateReceipt(ReceiptData data) {
    state = state.copyWith(receiptData: data, error: null);
  }

  ReceiptTransactionDraft buildDraft(ReceiptData data) {
    final selectedItems = data.items.where((item) => item.selected).toList();
    final total =
        data.totalAmount ??
        selectedItems.fold<double>(
          0,
          (sum, item) => sum + ((item.price ?? 0) * item.qty),
        );
    final noteBase = (data.storeName == null || data.storeName!.trim().isEmpty)
        ? 'Struk belanja'
        : data.storeName!.trim();
    final note =
        '$noteBase${selectedItems.isNotEmpty ? ' • ${selectedItems.length} item' : ''}';
    return ReceiptTransactionDraft(
      amount: total,
      category: data.suggestedCategory,
      note: note,
      date: data.date,
      receiptData: data.copyWith(items: selectedItems),
    );
  }

  void clear() {
    state = OcrState.initial();
  }

  String _mapError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('not a receipt') || lower.contains('confidence')) {
      return 'Gambar tidak terdeteksi sebagai struk. Coba lagi?';
    }
    if (lower.contains('blur') ||
        lower.contains('dark') ||
        lower.contains('jelas')) {
      return 'Foto kurang jelas. Pastikan pencahayaan cukup.';
    }
    return 'Gagal membaca struk. Kamu masih bisa isi form manual.';
  }
}

final ocrNotifierProvider = NotifierProvider<OcrNotifier, OcrState>(
  () => OcrNotifier(),
);

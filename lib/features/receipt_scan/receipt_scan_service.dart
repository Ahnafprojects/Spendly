import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/services/env_config.dart';
import 'receipt_data_model.dart';

class ReceiptScanService {
  static const double _guideWidthRatio = 0.82;
  static const double _guideHeightRatio = 0.52;
  static const double _guideCenterYRatio = 0.44;
  final ImagePicker _picker;

  ReceiptScanService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  Future<File?> pickFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null) return null;
    return File(image.path);
  }

  Future<File> compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return file;

    final baked = img.bakeOrientation(decoded);
    final cropped = _cropToReceiptGuide(baked);
    final resized = cropped.width > 1600
        ? img.copyResize(cropped, width: 1600)
        : cropped;

    var quality = 85;
    List<int> encoded = img.encodeJpg(resized, quality: quality);
    while (encoded.length > 1024 * 1024 && quality > 45) {
      quality -= 10;
      encoded = img.encodeJpg(resized, quality: quality);
    }

    final tempDir = await getTemporaryDirectory();
    final out = File(
      p.join(
        tempDir.path,
        'receipt_${DateTime.now().microsecondsSinceEpoch}.jpg',
      ),
    );
    await out.writeAsBytes(encoded, flush: true);
    return out;
  }

  Future<ReceiptData> scanReceipt(File imageFile) async {
    final compressed = await compressImage(imageFile);
    final bytes = await compressed.readAsBytes();
    final base64 = base64Encode(bytes);

    final groqApiKey = EnvConfig.get('GROQ_API_KEY');
    final groqBaseUrl = EnvConfig.get(
      'GROQ_BASE_URL',
      fallback: 'https://api.groq.com/openai/v1/chat/completions',
    );
    if (groqApiKey.trim().isEmpty) {
      throw Exception('GROQ_API_KEY belum diisi.');
    }

    final client = HttpClient();
    try {
      final content = await _requestReceiptExtraction(
        client: client,
        apiKey: groqApiKey,
        baseUrl: groqBaseUrl,
        imageBase64: base64,
        prompt:
            'Ini adalah foto struk belanja. Ekstrak informasi berikut dan return HANYA JSON: '
            '{"store_name":string|null,"date":"YYYY-MM-DD"|null,"total_amount":number|null,'
            '"items":[{"name":string,"price":number|null,"qty":number}],"confidence":number}. '
            'Kalau bukan struk atau sangat tidak jelas, isi field penting null dan confidence rendah.',
      );
      var parsed = _parseReceiptResponse(content);
      var normalized = _normalizeReceiptJson(parsed);
      if (_shouldRetry(normalized)) {
        final retryContent = await _requestReceiptExtraction(
          client: client,
          apiKey: groqApiKey,
          baseUrl: groqBaseUrl,
          imageBase64: base64,
          prompt:
              'Baca ulang struk ini dengan sangat ketat. Fokus ke nama toko, tanggal, grand total/final total, dan item. '
              'Return HANYA JSON valid dengan shape: '
              '{"store_name":string|null,"date":"YYYY-MM-DD"|null,"total_amount":number|null,'
              '"items":[{"name":string,"price":number|null,"qty":number}],"confidence":number}.',
        );
        parsed = _parseReceiptResponse(retryContent);
        normalized = _normalizeReceiptJson(parsed);
      }
      final storeName = parsed['store_name']?.toString();
      final category = mapStoreToCategory(storeName ?? '');
      normalized = {...normalized, 'confidence': _blendConfidence(normalized)};
      return ReceiptData.fromJson({
        ...normalized,
        'suggested_category': category,
        'image_path': compressed.path,
      });
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _requestReceiptExtraction({
    required HttpClient client,
    required String apiKey,
    required String baseUrl,
    required String imageBase64,
    required String prompt,
  }) async {
    final request = await client.postUrl(Uri.parse(baseUrl));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.write(
      jsonEncode({
        'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
        'temperature': 0.1,
        'max_tokens': 1200,
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
              },
              {'type': 'text', 'text': prompt},
            ],
          },
        ],
      }),
    );
    final response = await request.close();
    final raw = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('OCR API error ${response.statusCode}: $raw');
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final content =
        ((((decoded['choices'] as List?)?.first as Map?)?['message']
                as Map?)?['content'])
            ?.toString()
            .trim();
    if (content == null || content.isEmpty) {
      throw Exception('OCR response kosong');
    }
    return content;
  }

  img.Image _cropToReceiptGuide(img.Image source) {
    final cropWidth = (source.width * _guideWidthRatio).round();
    final cropHeight = (source.height * _guideHeightRatio).round();
    final centerY = (source.height * _guideCenterYRatio).round();
    final left = ((source.width - cropWidth) / 2).round().clamp(
      0,
      source.width - 1,
    );
    final top = (centerY - (cropHeight / 2)).round().clamp(
      0,
      source.height - 1,
    );
    final safeWidth = cropWidth.clamp(1, source.width - left);
    final safeHeight = cropHeight.clamp(1, source.height - top);
    return img.copyCrop(
      source,
      x: left,
      y: top,
      width: safeWidth,
      height: safeHeight,
    );
  }

  Map<String, dynamic> _parseReceiptResponse(String content) {
    final cleaned = content
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    try {
      return Map<String, dynamic>.from(jsonDecode(cleaned) as Map);
    } catch (_) {
      return _heuristicParse(cleaned);
    }
  }

  Map<String, dynamic> _normalizeReceiptJson(Map<String, dynamic> input) {
    final items = ((input['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          final name = (map['name'] ?? '').toString();
          final price = map['price'] is num
              ? (map['price'] as num).toDouble()
              : _parseLooseAmount((map['price'] ?? '').toString());
          final qty = map['qty'] is num
              ? (map['qty'] as num).toInt()
              : int.tryParse((map['qty'] ?? '1').toString()) ?? 1;
          return {
            'name': name,
            'price': price,
            'qty': qty,
            'is_uncertain': _isUncertainItem(
              name: name,
              price: price,
              qty: qty,
            ),
          };
        })
        .where((item) => (item['name'] as String).trim().isNotEmpty)
        .toList();

    return {
      'store_name': input['store_name']?.toString(),
      'date': _normalizeDate(input['date']?.toString()),
      'total_amount': input['total_amount'] is num
          ? (input['total_amount'] as num).toDouble()
          : _parseLooseAmount((input['total_amount'] ?? '').toString()),
      'items': items,
      'confidence': input['confidence'] is num
          ? (input['confidence'] as num).toInt().clamp(0, 100)
          : 0,
    };
  }

  bool _shouldRetry(Map<String, dynamic> normalized) {
    final total = normalized['total_amount'] as double?;
    final store = normalized['store_name']?.toString();
    final confidence = (normalized['confidence'] as int?) ?? 0;
    return total == null ||
        total <= 0 ||
        store == null ||
        store.trim().isEmpty ||
        confidence < 55;
  }

  int _blendConfidence(Map<String, dynamic> normalized) {
    var score = ((normalized['confidence'] as int?) ?? 0).clamp(0, 100);
    final store = normalized['store_name']?.toString();
    final date = normalized['date']?.toString();
    final total = normalized['total_amount'] as double?;
    final items = (normalized['items'] as List?) ?? const [];

    if (store != null && store.trim().isNotEmpty) score += 10;
    if (date != null && date.trim().isNotEmpty) score += 10;
    if (total != null && total > 0) score += 15;
    if (items.isNotEmpty) score += 10;

    if (store == null || store.trim().isEmpty) score -= 12;
    if (total == null || total <= 0) score -= 18;

    return score.clamp(20, 98);
  }

  bool _isUncertainItem({
    required String name,
    required double? price,
    required int qty,
  }) {
    final trimmed = name.trim();
    if (trimmed.length < 3) return true;
    if (RegExp(r'^[0-9\W_]+$').hasMatch(trimmed)) return true;
    if (trimmed.contains('***') || trimmed.contains('???')) return true;
    if (price == null || price <= 0) return true;
    if (qty <= 0) return true;
    return false;
  }

  String? _normalizeDate(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw == 'null') return null;
    final trimmed = raw.trim();
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) {
      return iso.toIso8601String().split('T').first;
    }
    final slash = RegExp(
      r'^(\d{2})[\/\-](\d{2})[\/\-](\d{4})$',
    ).firstMatch(trimmed);
    if (slash != null) {
      return '${slash.group(3)}-${slash.group(2)}-${slash.group(1)}';
    }
    return null;
  }

  Map<String, dynamic> _heuristicParse(String raw) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    String? storeName;
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('indomaret') ||
          lower.contains('alfamart') ||
          lower.contains('mart') ||
          lower.contains('store') ||
          lower.contains('toko') ||
          lower.contains('cabang')) {
        storeName ??= line.replaceFirst(RegExp(r'^[^:]*:\s*'), '');
      }
    }
    storeName ??= lines.isEmpty ? null : lines.first;

    String? date;
    final dateIso = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(raw);
    final dateSlash = RegExp(
      r'(\d{2})[\/\-](\d{2})[\/\-](\d{4})',
    ).firstMatch(raw);
    if (dateIso != null) {
      date = dateIso.group(1);
    } else if (dateSlash != null) {
      date =
          '${dateSlash.group(3)}-${dateSlash.group(2)}-${dateSlash.group(1)}';
    }

    final amountMatches =
        RegExp(
              r'(?:rp\s*)?(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?|\d{4,})',
              caseSensitive: false,
            )
            .allMatches(raw)
            .map((m) => m.group(1) ?? '')
            .map(_parseLooseAmount)
            .whereType<double>()
            .toList();
    amountMatches.sort((a, b) => b.compareTo(a));
    final total = amountMatches.isEmpty ? null : amountMatches.first;

    final items = <Map<String, dynamic>>[];
    final itemRegex = RegExp(
      r'^(.+?)\s+(?:x?(\d+)\s+)?(?:rp\s*)?(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?|\d{3,})$',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = itemRegex.firstMatch(line);
      if (match == null) continue;
      final name = match.group(1)?.trim() ?? '';
      if (name.length < 2) continue;
      final price = _parseLooseAmount(match.group(3) ?? '');
      items.add({
        'name': name,
        'price': price,
        'qty': int.tryParse(match.group(2) ?? '1') ?? 1,
        'is_uncertain': _isUncertainItem(
          name: name,
          price: price,
          qty: int.tryParse(match.group(2) ?? '1') ?? 1,
        ),
      });
      if (items.length >= 12) break;
    }

    final confidence = [
      if (storeName != null && storeName.isNotEmpty) 28,
      if (date != null) 22,
      if (total != null) 30,
      if (items.isNotEmpty) 20,
    ].fold<int>(0, (sum, part) => sum + part);

    return {
      'store_name': storeName,
      'date': date,
      'total_amount': total,
      'items': items,
      'confidence': confidence.clamp(35, 82),
    };
  }

  double? _parseLooseAmount(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  String mapStoreToCategory(String storeName) {
    final name = storeName.toLowerCase();
    if (name.contains('indomaret') ||
        name.contains('alfamart') ||
        name.contains('superindo') ||
        name.contains('giant')) {
      return 'Belanja Bulanan';
    }
    if (name.contains('kfc') ||
        name.contains('mcd') ||
        name.contains('warteg') ||
        name.contains('bakso') ||
        name.contains('cafe') ||
        name.contains('kopi')) {
      return 'Makanan Harian';
    }
    if (name.contains('grab') ||
        name.contains('gojek') ||
        name.contains('gocar') ||
        name.contains('transjakarta')) {
      return 'Transport Umum';
    }
    if (name.contains('apotek') ||
        name.contains('kimia farma') ||
        name.contains('guardian')) {
      return 'Kesehatan & Obat';
    }
    return 'Lainnya';
  }
}

final receiptScanServiceProvider = Provider<ReceiptScanService>((ref) {
  return ReceiptScanService();
});

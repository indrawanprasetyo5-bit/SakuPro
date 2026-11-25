import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ScannedReceiptData {
  const ScannedReceiptData({
    required this.merchantName,
    required this.totalAmount,
    required this.suggestedCategory,
    required this.rawText,
  });

  final String merchantName;
  final int? totalAmount;
  final String suggestedCategory;
  final String rawText;
}

class ReceiptOcrException implements Exception {
  const ReceiptOcrException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ReceiptOcrService {
  ReceiptOcrService._();

  static final ImagePicker _picker = ImagePicker();

  static const List<String> _ignoredMerchantPrefixes = <String>[
    'selamat datang',
    'welcome',
    'terima kasih',
    'struk',
    'receipt',
    'npwp',
    'jl.',
    'jl ',
    'jalan ',
    'telp',
    'tlp',
    'phone',
    'tanggal',
    'tgl',
    'kasir',
    'cashier',
    'no.',
    'bon ',
    'copy',
  ];

  static const List<String> _totalPriorityLabels = <String>[
    'grand total',
    'total bayar',
    'total belanja',
    'jumlah bayar',
    'total tagihan',
    'total pembayaran',
    'harga jual',
    'nett',
    'subtotal',
    'total',
    'bayar',
    'tagihan',
  ];

  static const List<String> _nonTotalLineWords = <String>[
    'tunai',
    'cash',
    'kembali',
    'kembalian',
    'change',
    'diskon',
    'disc',
    'hemat',
    'voucher',
    'ppn',
    'pajak',
    'tax',
    'qty',
  ];

  static Future<ScannedReceiptData?> scanReceipt({
    ImageSource source = ImageSource.camera,
  }) async {
    if (kIsWeb) {
      throw const ReceiptOcrException(
        'Fitur Scan Struk OCR berjalan offline di perangkat Android/iOS dan tidak tersedia pada Web Preview.',
      );
    }

    XFile? image;
    try {
      image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 2200,
        requestFullMetadata: false,
      );
      if (image == null) {
        final LostDataResponse lost = await _picker.retrieveLostData();
        if (!lost.isEmpty && lost.file != null) {
          image = lost.file;
        }
      }
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') {
        throw const ReceiptOcrException(
          'Izin kamera ditolak. Aktifkan izin kamera di pengaturan aplikasi atau pilih dari Galeri.',
        );
      }
      if (e.code == 'no_available_camera') {
        throw const ReceiptOcrException(
          'Kamera tidak ditemukan pada perangkat ini. Silakan pilih foto struk dari Galeri.',
        );
      }
      throw ReceiptOcrException(
        'Gagal mengambil gambar (${e.code}): ${e.message ?? 'terjadi kendala kamera'}.',
      );
    }

    if (image == null || image.path.isEmpty) {
      return null;
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final recognized = await recognizer.processImage(inputImage);
      if (recognized.text.trim().isEmpty) {
        throw const ReceiptOcrException(
          'Teks struk tidak terbaca. Pastikan foto struk terang dan fokus.',
        );
      }
      return parseReceiptText(recognized.text);
    } on PlatformException catch (e) {
      throw ReceiptOcrException(
        'Mesin OCR gagal memproses foto (${e.code}): ${e.message ?? 'coba foto ulang dengan pencahayaan cukup'}.',
      );
    } finally {
      await recognizer.close();
    }
  }

  static ScannedReceiptData parseReceiptText(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final merchant = _extractMerchant(lines);
    final total = _extractTotalAmount(lines);
    final category =
        _inferCategoryByText(merchant) ??
        _inferCategoryByText(rawText) ??
        'Belanja';

    return ScannedReceiptData(
      merchantName: merchant,
      totalAmount: total,
      suggestedCategory: category,
      rawText: rawText,
    );
  }

  static String _extractMerchant(List<String> lines) {
    final topSlice = lines.take(7);
    for (final line in topSlice) {
      final clean = line.replaceAll(RegExp(r'[*=_#\-]{2,}'), '').trim();
      if (clean.length < 3) {
        continue;
      }
      // Skip lines dominated by digits (dates, phone numbers, codes).
      final letters = RegExp(r'[A-Za-z]').allMatches(clean).length;
      final digits = RegExp(r'\d').allMatches(clean).length;
      if (letters < 3 || digits > letters) {
        continue;
      }
      final lower = clean.toLowerCase();
      final isBoilerplate = _ignoredMerchantPrefixes.any(
        (prefix) => lower.startsWith(prefix) || lower.contains('npwp'),
      );
      if (isBoilerplate) {
        continue;
      }
      return _titleCase(clean);
    }
    return 'Belanja Struk';
  }

  static int? _extractTotalAmount(List<String> lines) {
    for (final keyword in _totalPriorityLabels) {
      for (var i = lines.length - 1; i >= 0; i--) {
        final lower = lines[i].toLowerCase();
        if (!lower.contains(keyword)) {
          continue;
        }
        // Avoid matching "TUNAI BAYAR" or "KEMBALI" lines when looking for "total"/"bayar".
        if (_nonTotalLineWords.any(
          (noise) => noise != keyword && lower.contains(noise),
        )) {
          continue;
        }

        final inlineAmounts = _extractAmountsFromLine(lines[i]);
        if (inlineAmounts.isNotEmpty) {
          return inlineAmounts.reduce((a, b) => a > b ? a : b);
        }

        if (i + 1 < lines.length) {
          final nextLineAmounts = _extractAmountsFromLine(lines[i + 1]);
          if (nextLineAmounts.isNotEmpty) {
            return nextLineAmounts.reduce((a, b) => a > b ? a : b);
          }
        }
      }
    }

    var maxAmount = 0;
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_nonTotalLineWords.any(lower.contains)) {
        continue;
      }
      for (final val in _extractAmountsFromLine(line)) {
        if (val > maxAmount) {
          maxAmount = val;
        }
      }
    }
    return maxAmount > 0 ? maxAmount : null;
  }

  static List<int> _extractAmountsFromLine(String line) {
    final results = <int>[];
    final pattern = RegExp(
      r'(?:rp\.?\s*)?(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?|\d{4,9})\b',
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(line)) {
      var token = match.group(1) ?? '';
      if (token.isEmpty) {
        continue;
      }
      // Strip trailing 2-digit decimals such as ,00 or .00.
      if (RegExp(r'[.,]\d{2}$').hasMatch(token) && token.length > 5) {
        token = token.substring(0, token.length - 3);
      }
      final digits = token.replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(digits);
      if (parsed == null) {
        continue;
      }
      // Filter out dates like 20261125 and unrealistic values.
      if (parsed >= 500 &&
          parsed <= 250000000 &&
          !(parsed >= 20200101 && parsed <= 20351231)) {
        results.add(parsed);
      }
    }
    return results;
  }

  static String? _inferCategoryByText(String content) {
    final lower = content.toLowerCase();
    if (_hasAny(lower, const <String>[
      'indomaret',
      'alfamart',
      'alfamidi',
      'superindo',
      'hypermart',
      'transmart',
      'yogya',
      'miniso',
      'mr.diy',
      'ikea',
      'belanja',
    ])) {
      return 'Belanja';
    }
    if (_hasAny(lower, const <String>[
      'kopi',
      'coffee',
      'starbucks',
      'fore',
      'janji jiwa',
      'kenangan',
      'cafe',
      'boba',
    ])) {
      return 'Ngopi';
    }
    if (_hasAny(lower, const <String>[
      'pertamina',
      'spbu',
      'shell',
      'vivo',
      'bp ',
      'pertalite',
      'pertamax',
      'parkir',
      'tol',
    ])) {
      return 'Transportasi';
    }
    if (_hasAny(lower, const <String>[
      'apotek',
      'kimia farma',
      'century',
      'guardian',
      'watsons',
      'klinik',
      'rs ',
    ])) {
      return 'Kesehatan';
    }
    if (_hasAny(lower, const <String>[
      'resto',
      'warung',
      'solaria',
      'hokben',
      'kfc',
      'mcd',
      'ayam',
      'bakso',
      'nasi',
      'mie',
      'bakery',
      'roti',
    ])) {
      return 'Makan & Minum';
    }
    if (_hasAny(lower, const <String>[
      'pln',
      'listrik',
      'pdam',
      'telkom',
      'indihome',
      'pulsa',
    ])) {
      return 'Tagihan & Utilitas';
    }
    return null;
  }

  static bool _hasAny(String source, List<String> keywords) {
    for (final k in keywords) {
      if (source.contains(k)) {
        return true;
      }
    }
    return false;
  }

  static String _titleCase(String raw) {
    final words = raw
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((word) {
          if (word.length <= 3 && word == word.toUpperCase()) {
            return word;
          }
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .toList();
    return words.join(' ');
  }
}

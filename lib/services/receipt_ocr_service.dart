import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptAmountCandidate {
  const ReceiptAmountCandidate({
    required this.label,
    required this.amount,
    required this.score,
  });

  final String label;
  final int amount;
  final int score;
}

class ScannedReceiptData {
  const ScannedReceiptData({
    required this.merchantName,
    required this.totalAmount,
    required this.suggestedCategory,
    required this.rawText,
    this.reconstructedLines = const <String>[],
    this.amountCandidates = const <ReceiptAmountCandidate>[],
  });

  final String merchantName;
  final int? totalAmount;
  final String suggestedCategory;
  final String rawText;
  final List<String> reconstructedLines;
  final List<ReceiptAmountCandidate> amountCandidates;
}

class ReceiptOcrException implements Exception {
  const ReceiptOcrException(this.message);
  final String message;

  @override
  String toString() => message;
}

class _SpatialLine {
  const _SpatialLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get height => math.max(1.0, bottom - top);
  double get centerY => (top + bottom) / 2.0;
}

class _ParsedPriceToken {
  const _ParsedPriceToken({
    required this.amount,
    required this.hasSeparatorOrCurrency,
    required this.endOffset,
  });

  final int amount;
  final bool hasSeparatorOrCurrency;
  final int endOffset;
}

class ReceiptOcrService {
  ReceiptOcrService._();

  static final ImagePicker _picker = ImagePicker();

  static const Map<String, String> _knownLegalEntities = <String, String>{
    'indomarco prismatama': 'Indomaret',
    'indomaret': 'Indomaret',
    'sumber alfaria trijaya': 'Alfamart',
    'alfamart': 'Alfamart',
    'midi utama indonesia': 'Alfamidi',
    'alfamidi': 'Alfamidi',
    'lion super indo': 'Super Indo',
    'superindo': 'Super Indo',
    'super indo': 'Super Indo',
    'fast food indonesia': 'KFC',
    'rekso nasional food': "McDonald's",
    'sari coffee indonesia': 'Starbucks',
    'bumi berkah boga': 'Kopi Kenangan',
    'fore kopi indonesia': 'Fore Coffee',
    'eka boginti': 'HokBen',
    'matahari putra prima': 'Hypermart',
    'trans retail indonesia': 'Transmart',
    'fajar mitra indah': 'FamilyMart',
    'lancartama sejati': 'Lawson',
    'pertamina': 'SPBU Pertamina',
    'kimia farma': 'Apotek Kimia Farma',
  };

  static const List<String> _ignoredMerchantTokens = <String>[
    'selamat datang',
    'welcome',
    'terima kasih',
    'thank you',
    'struk',
    'receipt',
    'invoice',
    'nota',
    'npwp',
    'pkp',
    'jl.',
    'jl ',
    'jalan ',
    'kec.',
    'kel.',
    'kab.',
    'kota ',
    'telp',
    'tlp',
    'phone',
    'fax',
    'wa ',
    'whatsapp',
    'tanggal',
    'tgl',
    'date',
    'kasir',
    'cashier',
    'no.',
    'bon ',
    'copy',
    'reprint',
    'layanan konsumen',
    'call center',
    'instagram',
    'www.',
    'http',
    'member',
    'pelanggan',
    'customer',
  ];

  static const List<String> _primaryTotalKeywords = <String>[
    'grand total',
    'total bayar',
    'total belanja',
    'total pembayaran',
    'total tagihan',
    'jumlah bayar',
    'total akhir',
    'net total',
    'nett total',
    'total due',
    'amount due',
    'total harga',
    'total pembelian',
    'total transaksi',
    'total (incl',
    'total incl',
  ];

  static const List<String> _secondaryTotalKeywords = <String>[
    'jumlah tagihan',
    'harga jual',
    'total jual',
    'tagihan',
    'jumlah',
    'nett',
    'netto',
    'amount',
    'bayar',
  ];

  static const List<String> _paymentMethodKeywords = <String>[
    'qris',
    'debit',
    'kredit',
    'credit',
    'gopay',
    'ovo',
    'dana',
    'shopeepay',
    'linkaja',
    'bca',
    'mandiri',
    'bni',
    'bri',
    'edc',
    'non tunai',
    'non-tunai',
    'e-wallet',
    'ewallet',
    'flazz',
    'emoney',
    'brizzi',
  ];

  static const List<String> _cashPaidKeywords = <String>[
    'tunai',
    'cash',
    'uang tunai',
    'diterima',
    'dibayar tunai',
    'bayar tunai',
    'tendered',
  ];

  static const List<String> _changeKeywords = <String>[
    'kembalian',
    'kembali',
    'change',
    'sisa kembali',
  ];

  static const List<String> _excludedTotalLineKeywords = <String>[
    'total item',
    'total qty',
    'total pcs',
    'total barang',
    'total produk',
    'total diskon',
    'total disc',
    'total hemat',
    'total potongan',
    'total poin',
    'total point',
    'total pajak',
    'total ppn',
    'total tax',
    'diskon',
    'disc',
    'hemat',
    'potongan',
    'voucher',
    'kupon',
    'ppn',
    'dpp',
    'pajak',
    'pb1',
    'tax',
    'service',
    'svc',
    'rounding',
    'pembulatan',
    'poin',
    'point',
    'saldo',
    'balance',
  ];

  static const List<String> _nonPriceLineKeywords = <String>[
    'npwp',
    'telp',
    'tlp',
    'phone',
    'hp ',
    'wa ',
    'fax',
    'kode pos',
    'no.',
    'no:',
    'inv',
    'trx',
    'ref',
    'trace',
    'batch',
    'appr',
    'approval',
    'mid',
    'tid',
    'merchant id',
    'terminal',
    'card',
    'kartu',
    'member',
    'kasir',
    'pos ',
    'struk',
    'nota',
    'bon ',
    'call center',
    'pengaduan',
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
        imageQuality: 92,
        maxWidth: 2048,
        maxHeight: 3200,
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

    return scanReceiptFile(image.path);
  }

  static Future<ScannedReceiptData> scanReceiptFile(String filePath) async {
    if (kIsWeb) {
      throw const ReceiptOcrException(
        'Fitur Scan Struk OCR berjalan offline di perangkat Android/iOS dan tidak tersedia pada Web Preview.',
      );
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final recognized = await recognizer.processImage(inputImage);
      if (recognized.text.trim().isEmpty) {
        throw const ReceiptOcrException(
          'Teks struk tidak terbaca. Pastikan foto struk terang, rata, dan fokus.',
        );
      }
      return parseRecognizedText(recognized);
    } on PlatformException catch (e) {
      throw ReceiptOcrException(
        'Mesin OCR gagal memproses foto (${e.code}): ${e.message ?? 'coba foto ulang dengan pencahayaan cukup'}.',
      );
    } finally {
      await recognizer.close();
    }
  }

  /// Reconstructs visual rows from MLKit bounding boxes so left labels and
  /// right-aligned prices merge onto the same line before parsing.
  static ScannedReceiptData parseRecognizedText(RecognizedText recognized) {
    final spatialLines = <_SpatialLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final cleaned = line.text.trim();
        if (cleaned.isEmpty) {
          continue;
        }
        final rect = line.boundingBox;
        spatialLines.add(
          _SpatialLine(
            text: cleaned,
            left: rect.left,
            top: rect.top,
            right: rect.right,
            bottom: rect.bottom,
          ),
        );
      }
    }

    if (spatialLines.isEmpty) {
      return parseReceiptText(recognized.text);
    }

    final rows = _clusterSpatialRows(spatialLines);
    final mergedLines = rows
        .map((row) {
          row.sort((a, b) => a.left.compareTo(b.left));
          return row.map((item) => item.text).join('  ');
        })
        .where((line) => line.trim().isNotEmpty)
        .toList();

    return _parseStructuredLines(
      lines: mergedLines,
      rawText: recognized.text,
    );
  }

  static List<List<_SpatialLine>> _clusterSpatialRows(
    List<_SpatialLine> lines,
  ) {
    final sorted = List<_SpatialLine>.from(lines)
      ..sort((a, b) => a.centerY.compareTo(b.centerY));

    final rows = <List<_SpatialLine>>[];
    for (final item in sorted) {
      List<_SpatialLine>? bestRow;
      var bestDelta = double.infinity;

      for (final row in rows) {
        final avgCenter =
            row.fold<double>(0.0, (sum, l) => sum + l.centerY) / row.length;
        final avgHeight =
            row.fold<double>(0.0, (sum, l) => sum + l.height) / row.length;
        final rowTop = row.map((l) => l.top).reduce(math.min);
        final rowBottom = row.map((l) => l.bottom).reduce(math.max);

        final overlap =
            math.min(rowBottom, item.bottom) - math.max(rowTop, item.top);
        final minHeight = math.min(avgHeight, item.height);
        final deltaY = (item.centerY - avgCenter).abs();
        final tolerance = math.max(avgHeight, item.height) * 0.55;

        if ((overlap > 0 && overlap / minHeight >= 0.32) ||
            deltaY <= tolerance) {
          if (deltaY < bestDelta) {
            bestDelta = deltaY;
            bestRow = row;
          }
        }
      }

      if (bestRow != null) {
        bestRow.add(item);
      } else {
        rows.add(<_SpatialLine>[item]);
      }
    }

    rows.sort((a, b) {
      final aY = a.fold<double>(0.0, (s, l) => s + l.centerY) / a.length;
      final bY = b.fold<double>(0.0, (s, l) => s + l.centerY) / b.length;
      return aY.compareTo(bY);
    });
    return rows;
  }

  static ScannedReceiptData parseReceiptText(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return _parseStructuredLines(lines: lines, rawText: rawText);
  }

  static ScannedReceiptData _parseStructuredLines({
    required List<String> lines,
    required String rawText,
  }) {
    final merchant = _extractMerchant(lines, rawText);
    final candidates = _rankTotalCandidates(lines);
    final bestTotal = candidates.isNotEmpty ? candidates.first.amount : null;

    final category =
        _inferCategoryByText(merchant) ??
        _inferCategoryByText(lines.join('\n')) ??
        'Belanja';

    return ScannedReceiptData(
      merchantName: merchant,
      totalAmount: bestTotal,
      suggestedCategory: category,
      rawText: rawText,
      reconstructedLines: lines,
      amountCandidates: candidates.take(4).toList(),
    );
  }

  static String _extractMerchant(List<String> lines, String rawText) {
    final headerText = lines.take(10).join(' ').toLowerCase();
    for (final entry in _knownLegalEntities.entries) {
      if (headerText.contains(entry.key)) {
        return entry.value;
      }
    }

    for (final line in lines.take(8)) {
      final clean = line
          .replaceAll(RegExp(r'[*=_#\-+]{2,}'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (clean.length < 3 || clean.length > 48) {
        continue;
      }
      final letters = RegExp(r'[A-Za-z]').allMatches(clean).length;
      final digits = RegExp(r'\d').allMatches(clean).length;
      if (letters < 3 || digits > letters) {
        continue;
      }
      final lower = clean.toLowerCase();
      if (_ignoredMerchantTokens.any(lower.contains)) {
        continue;
      }
      if (lower.startsWith('pt ') || lower.startsWith('pt.')) {
        continue;
      }
      // Avoid picking an item line that already carries a price on the right.
      if (_extractPriceTokens(clean).isNotEmpty) {
        continue;
      }
      return _titleCase(clean);
    }

    final fullLower = rawText.toLowerCase();
    for (final entry in _knownLegalEntities.entries) {
      if (fullLower.contains(entry.key)) {
        return entry.value;
      }
    }
    return 'Belanja Struk';
  }

  static List<ReceiptAmountCandidate> _rankTotalCandidates(List<String> lines) {
    final scored = <ReceiptAmountCandidate>[];

    int? cashPaid;
    int? changeAmount;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      if (_matchesAny(lower, _changeKeywords)) {
        final token = _rightmostPriceFromLineOrNext(lines, i);
        if (token != null) {
          changeAmount = token.amount;
        }
        continue;
      }

      if (_matchesAny(lower, _cashPaidKeywords) &&
          !lower.contains('non tunai') &&
          !lower.contains('non-tunai')) {
        final token = _rightmostPriceFromLineOrNext(lines, i);
        if (token != null) {
          cashPaid = token.amount;
        }
        continue;
      }

      if (_matchesAny(lower, _excludedTotalLineKeywords)) {
        continue;
      }

      if (_matchesAny(lower, _primaryTotalKeywords)) {
        final token = _rightmostPriceFromLineOrNext(lines, i);
        if (token != null) {
          scored.add(
            ReceiptAmountCandidate(
              label: _shortLabel(line, fallback: 'Total Bayar'),
              amount: token.amount,
              score: 100 + (token.hasSeparatorOrCurrency ? 10 : 0) + (i ~/ 4),
            ),
          );
        }
        continue;
      }

      if (_containsWholeWord(lower, 'total') &&
          !lower.contains('subtotal') &&
          !lower.contains('sub total') &&
          !lower.contains('sub-total')) {
        final token = _rightmostPriceFromLineOrNext(lines, i);
        if (token != null) {
          scored.add(
            ReceiptAmountCandidate(
              label: _shortLabel(line, fallback: 'Total'),
              amount: token.amount,
              score: 92 + (token.hasSeparatorOrCurrency ? 10 : 0) + (i ~/ 4),
            ),
          );
        }
        continue;
      }

      if (_matchesAny(lower, _secondaryTotalKeywords)) {
        final token = _rightmostPriceFromLineOrNext(lines, i);
        if (token != null) {
          scored.add(
            ReceiptAmountCandidate(
              label: _shortLabel(line, fallback: 'Total'),
              amount: token.amount,
              score: 76 + (token.hasSeparatorOrCurrency ? 8 : 0),
            ),
          );
        }
        continue;
      }

      if (_matchesAny(lower, _paymentMethodKeywords) &&
          !_matchesAny(lower, _nonPriceLineKeywords)) {
        final token = _rightmostPriceFromLineOrNext(lines, i);
        if (token != null) {
          scored.add(
            ReceiptAmountCandidate(
              label: _shortLabel(line, fallback: 'Pembayaran'),
              amount: token.amount,
              score: 74 + (token.hasSeparatorOrCurrency ? 8 : 0),
            ),
          );
        }
        continue;
      }

      if (lower.contains('subtotal') ||
          lower.contains('sub total') ||
          lower.contains('sub-total')) {
        final token = _rightmostPriceFromLineOrNext(lines, i);
        if (token != null) {
          scored.add(
            ReceiptAmountCandidate(
              label: 'Subtotal',
              amount: token.amount,
              score: 58 + (token.hasSeparatorOrCurrency ? 6 : 0),
            ),
          );
        }
      }
    }

    // Cross-check cash arithmetic: Tunai - Kembali = Exact Total.
    final int? cashDerivedTotal =
        (cashPaid != null && changeAmount != null && cashPaid > changeAmount)
        ? cashPaid - changeAmount
        : null;

    if (cashDerivedTotal != null && cashDerivedTotal >= 500) {
      var matchedExisting = false;
      for (var i = 0; i < scored.length; i++) {
        if (scored[i].amount == cashDerivedTotal) {
          scored[i] = ReceiptAmountCandidate(
            label: scored[i].label,
            amount: scored[i].amount,
            score: scored[i].score + 45,
          );
          matchedExisting = true;
        }
      }
      if (!matchedExisting) {
        scored.add(
          ReceiptAmountCandidate(
            label: 'Total (Tunai - Kembali)',
            amount: cashDerivedTotal,
            score: 96,
          ),
        );
      }
    }

    // Fallback when OCR split columns or missed the TOTAL keyword entirely.
    if (scored.isEmpty) {
      final fallbackPrices = <ReceiptAmountCandidate>[];
      for (var i = 0; i < lines.length; i++) {
        final lower = lines[i].toLowerCase();
        if (_matchesAny(lower, _nonPriceLineKeywords) ||
            _matchesAny(lower, _cashPaidKeywords) ||
            _matchesAny(lower, _changeKeywords) ||
            _matchesAny(lower, _excludedTotalLineKeywords)) {
          continue;
        }
        final tokens = _extractPriceTokens(lines[i]);
        if (tokens.isEmpty) {
          continue;
        }
        final rightmost = tokens.last;
        if (cashPaid != null && rightmost.amount == cashPaid) {
          continue;
        }
        if (changeAmount != null && rightmost.amount == changeAmount) {
          continue;
        }
        final score =
            (rightmost.hasSeparatorOrCurrency ? 40 : 15) +
            (i * 20 ~/ math.max(1, lines.length));
        fallbackPrices.add(
          ReceiptAmountCandidate(
            label: 'Nominal Terdeteksi',
            amount: rightmost.amount,
            score: score,
          ),
        );
      }

      if (fallbackPrices.isNotEmpty) {
        fallbackPrices.sort((a, b) {
          final scoreCmp = b.score.compareTo(a.score);
          return scoreCmp != 0 ? scoreCmp : b.amount.compareTo(a.amount);
        });
        scored.addAll(fallbackPrices.take(4));
      }
    }

    // Deduplicate by amount, keeping the highest-scored label per amount.
    final bestByAmount = <int, ReceiptAmountCandidate>{};
    for (final c in scored) {
      final existing = bestByAmount[c.amount];
      if (existing == null || c.score > existing.score) {
        bestByAmount[c.amount] = c;
      }
    }

    final result = bestByAmount.values.toList()
      ..sort((a, b) {
        final cmp = b.score.compareTo(a.score);
        return cmp != 0 ? cmp : b.amount.compareTo(a.amount);
      });
    return result;
  }

  static _ParsedPriceToken? _rightmostPriceFromLineOrNext(
    List<String> lines,
    int index,
  ) {
    final currentTokens = _extractPriceTokens(lines[index]);
    if (currentTokens.isNotEmpty) {
      return currentTokens.last;
    }

    // Only look at the next line if it is a standalone price line without another label.
    if (index + 1 < lines.length) {
      final nextLine = lines[index + 1];
      final nextLower = nextLine.toLowerCase();
      final hasOtherLabel =
          _matchesAny(nextLower, _cashPaidKeywords) ||
          _matchesAny(nextLower, _changeKeywords) ||
          _matchesAny(nextLower, _excludedTotalLineKeywords) ||
          _matchesAny(nextLower, _primaryTotalKeywords);
      if (!hasOtherLabel) {
        final nextLetters = RegExp(r'[A-Za-z]')
            .allMatches(
              nextLine.replaceAll(RegExp(r'\b(rp|idr)\b', caseSensitive: false), ''),
            )
            .length;
        if (nextLetters <= 2) {
          final nextTokens = _extractPriceTokens(nextLine);
          if (nextTokens.isNotEmpty) {
            return nextTokens.last;
          }
        }
      }
    }
    return null;
  }

  static List<_ParsedPriceToken> _extractPriceTokens(String rawLine) {
    // Strip dates (26/11/2026, 26-11-26) and timestamps (14:35:20) first.
    var sanitized = rawLine
        .replaceAll(RegExp(r'\b\d{1,4}[/-]\d{1,2}[/-]\d{2,4}\b'), ' ')
        .replaceAll(RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b'), ' ')
        .replaceAll(RegExp(r'\b0\d{7,13}\b'), ' ');

    // Collapse accidental OCR spaces around thousand separators (12. 5OO -> 12.5OO).
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(\d)\s*([.,])\s*([\dOo]{3})\b'),
      (m) => '${m.group(1)}${m.group(2)}${m.group(3)}',
    );
    // Normalize OCR letter-O confusion inside digit-led price tokens (12.5OO -> 12.500).
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b\d[\d.,Oo]{2,}\b'),
      (m) => m.group(0)!.replaceAll(RegExp(r'[Oo]'), '0'),
    );

    final tokens = <_ParsedPriceToken>[];
    final pattern = RegExp(
      r'(?:(?:rp|idr)\.?\s*)?(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?|\d{3,8}(?:[.,]\d{2})?)\b',
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(sanitized)) {
      final fullMatch = match.group(0) ?? '';
      var numberPart = match.group(1) ?? '';
      if (numberPart.isEmpty) {
        continue;
      }

      // Skip negative discount figures like -5.000 or (5.000).
      if (match.start > 0) {
        final prevChar = sanitized[match.start - 1];
        if (prevChar == '-' || prevChar == '(') {
          continue;
        }
      }

      // Skip unit multipliers right before 'x' or '@' (e.g. 2x 15.000).
      if (match.end < sanitized.length) {
        final trailing = sanitized.substring(match.end).trimLeft().toLowerCase();
        if (trailing.startsWith('x ') ||
            trailing.startsWith('x\t') ||
            trailing.startsWith('pcs') ||
            trailing.startsWith('kg') ||
            trailing.startsWith('gr') ||
            trailing.startsWith('ml') ||
            trailing.startsWith('ltr') ||
            trailing.startsWith('%')) {
          continue;
        }
      }

      final hasCurrencyPrefix = RegExp(
        r'^(?:rp|idr)',
        caseSensitive: false,
      ).hasMatch(fullMatch.trimLeft());

      var hasThousandSep = RegExp(r'\d[.,]\d{3}\b').hasMatch(numberPart);

      // Handle explicit trailing 2-digit decimals (,00 or .00) without breaking .000.
      if (RegExp(r'[.,]\d{2}$').hasMatch(numberPart)) {
        numberPart = numberPart.substring(0, numberPart.length - 3);
        hasThousandSep =
            hasThousandSep || RegExp(r'\d[.,]\d{3}\b').hasMatch(numberPart);
      }

      // Skip bare numbers with leading zero (e.g. 001234 receipt sequence).
      if (!hasThousandSep && numberPart.startsWith('0')) {
        continue;
      }

      final digits = numberPart.replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(digits);
      if (parsed == null) {
        continue;
      }

      if (parsed < 500 || parsed > 100000000) {
        continue;
      }
      // Reject years (2020..2035) and compact dates (20261126) unless clearly formatted.
      if (!hasCurrencyPrefix &&
          !hasThousandSep &&
          ((parsed >= 2020 && parsed <= 2035) ||
              (parsed >= 20200101 && parsed <= 20351231))) {
        continue;
      }

      tokens.add(
        _ParsedPriceToken(
          amount: parsed,
          hasSeparatorOrCurrency: hasCurrencyPrefix || hasThousandSep,
          endOffset: match.end,
        ),
      );
    }

    return tokens;
  }

  static String _shortLabel(String line, {required String fallback}) {
    final cleaned = line
        .replaceAll(RegExp(r'(?:rp|idr)\.?\s*[\d.,\s]+', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\d.,:]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length < 3 || cleaned.length > 26) {
      return fallback;
    }
    return _titleCase(cleaned);
  }

  static bool _matchesAny(String source, List<String> keywords) {
    for (final k in keywords) {
      if (source.contains(k)) {
        return true;
      }
    }
    return false;
  }

  static bool _containsWholeWord(String source, String word) {
    return RegExp('(^|[^a-z0-9])${RegExp.escape(word)}(\$|[^a-z0-9])')
        .hasMatch(source);
  }

  static String? _inferCategoryByText(String content) {
    final lower = content.toLowerCase();
    if (_matchesAny(lower, const <String>[
      'indomaret',
      'alfamart',
      'alfamidi',
      'superindo',
      'super indo',
      'hypermart',
      'transmart',
      'yogya',
      'miniso',
      'mr.diy',
      'ikea',
      'familymart',
      'lawson',
      'circle k',
      'belanja',
    ])) {
      return 'Belanja';
    }
    if (_matchesAny(lower, const <String>[
      'kopi',
      'coffee',
      'starbucks',
      'fore',
      'janji jiwa',
      'kenangan',
      'cafe',
      'kafe',
      'boba',
      'mixue',
      'chatime',
      'point coffee',
    ])) {
      return 'Ngopi';
    }
    if (_matchesAny(lower, const <String>[
      'pertamina',
      'spbu',
      'shell',
      'vivo',
      'bp ',
      'pertalite',
      'pertamax',
      'parkir',
      'tol',
      'bengkel',
    ])) {
      return 'Transportasi';
    }
    if (_matchesAny(lower, const <String>[
      'apotek',
      'kimia farma',
      'century',
      'guardian',
      'watsons',
      'klinik',
      'rumah sakit',
      'rs ',
    ])) {
      return 'Kesehatan';
    }
    if (_matchesAny(lower, const <String>[
      'resto',
      'warung',
      'solaria',
      'hokben',
      'kfc',
      'mcd',
      'burger',
      'pizza',
      'ayam',
      'bakso',
      'nasi',
      'mie',
      'sate',
      'bakery',
      'roti',
      'ramen',
      'sushi',
    ])) {
      return 'Makan & Minum';
    }
    if (_matchesAny(lower, const <String>[
      'pln',
      'listrik',
      'pdam',
      'telkom',
      'indihome',
      'pulsa',
      'biznet',
    ])) {
      return 'Tagihan & Utilitas';
    }
    return null;
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

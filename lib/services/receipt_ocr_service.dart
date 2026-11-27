import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/transaction_item.dart';
import '../theme/currency_format.dart';

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

class ReceiptLineItem {
  const ReceiptLineItem({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  final String name;
  final int price;
  final int quantity;

  String formatLine() {
    final prefix = quantity > 1 ? '${quantity}x ' : '';
    return '$prefix$name · ${IdrFormat.currency(price)}';
  }
}

class ScannedReceiptData {
  const ScannedReceiptData({
    required this.merchantName,
    required this.totalAmount,
    required this.suggestedCategory,
    required this.rawText,
    this.suggestedKind = TransactionKind.expense,
    this.detectedWalletName,
    this.paymentMethod,
    this.transferNote,
    this.adminFee,
    this.receiptDate,
    this.items = const <ReceiptLineItem>[],
    this.receiptDetailText = '',
    this.sourceImagePath,
    this.reconstructedLines = const <String>[],
    this.amountCandidates = const <ReceiptAmountCandidate>[],
  });

  final String merchantName;
  final int? totalAmount;
  final String suggestedCategory;
  final TransactionKind suggestedKind;
  final String? detectedWalletName;
  final String? paymentMethod;
  final String? transferNote;
  final int? adminFee;
  final DateTime? receiptDate;
  final List<ReceiptLineItem> items;
  final String receiptDetailText;
  final String? sourceImagePath;
  final String rawText;
  final List<String> reconstructedLines;
  final List<ReceiptAmountCandidate> amountCandidates;

  ScannedReceiptData copyWith({String? sourceImagePath}) {
    return ScannedReceiptData(
      merchantName: merchantName,
      totalAmount: totalAmount,
      suggestedCategory: suggestedCategory,
      suggestedKind: suggestedKind,
      detectedWalletName: detectedWalletName,
      paymentMethod: paymentMethod,
      transferNote: transferNote,
      adminFee: adminFee,
      receiptDate: receiptDate,
      items: items,
      receiptDetailText: receiptDetailText,
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      rawText: rawText,
      reconstructedLines: reconstructedLines,
      amountCandidates: amountCandidates,
    );
  }
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
    required this.hasCurrencyPrefix,
    required this.startOffset,
    required this.endOffset,
  });

  final int amount;
  final bool hasSeparatorOrCurrency;
  final bool hasCurrencyPrefix;
  final int startOffset;
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
    'transaksi berhasil',
    'transfer berhasil',
    'pembayaran berhasil',
    'berhasil',
    'sukses',
    'selesai',
    'bukti transaksi',
    'bukti transfer',
    'rincian transaksi',
    'detail transaksi',
    'e-receipt',
    'm-transfer',
    'bi-fast',
    'bank jago',
    'jago',
    'seabank',
    'bca mobile',
    'mybca',
    'livin',
    'brimo',
    'dari kantong',
    'kantong utama',
    'sumber dana',
    'rincian',
    'detail',
    'penerima',
    'pengirim',
    'tujuan',
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
    'total transfer',
    'total kirim',
    'total debit',
    'jumlah transfer',
    'jumlah transaksi',
    'jumlah kirim',
    'nominal transfer',
    'nominal transaksi',
    'nominal',
    'uang keluar',
    'dana terkirim',
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
    'biaya admin',
    'biaya transaksi',
    'biaya layanan',
    'biaya transfer',
    'admin fee',
    'biaya',
  ];

  static const List<String> _nonPriceLineKeywords = <String>[
    'npwp',
    'telp',
    'tlp',
    'phone',
    'telepon',
    'handphone',
    'ponsel',
    'no hp',
    'no. hp',
    'nomor hp',
    'hp ',
    'wa ',
    'fax',
    'kode pos',
    'rekening',
    'no rek',
    'no. rek',
    'norek',
    'kantong',
    'virtual account',
    'nomor va',
    'id transaksi',
    'no referensi',
    'nomor referensi',
    'referensi',
    'bi-fast',
    'bifast',
    'rrn',
    'stan',
    'kode bayar',
    'nomor kartu',
    'id pelanggan',
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

  static const Map<String, List<String>> _expenseCategoryRules =
      <String, List<String>>{
        'Ngopi': <String>[
          'kopi',
          'coffee',
          'starbucks',
          'fore',
          'janji jiwa',
          'kenangan',
          'tuku',
          'tomoro',
          'kulo',
          'point coffee',
          'flash coffee',
          'cotti',
          'arabica',
          'cafe',
          'kafe',
          'latte',
          'americano',
          'cappuccino',
          'espresso',
          'matcha',
          'boba',
          'mixue',
          'chatime',
          'haus',
          'xing fu tang',
          'koi the',
          'teazzi',
        ],
        'Makan & Minum': <String>[
          'gofood',
          'grabfood',
          'shopeefood',
          'resto',
          'restoran',
          'warung',
          'warteg',
          'padang',
          'rm ',
          'rumah makan',
          'kantin',
          'catering',
          'solaria',
          'hokben',
          'kfc',
          'mcd',
          'mcdonald',
          'burger',
          'pizza',
          'richeese',
          'wendy',
          'marugame',
          'yoshinoya',
          'kimukatsu',
          'gacoan',
          'bakmi',
          'ayam',
          'geprek',
          'bebek',
          'bakso',
          'nasi',
          'mie',
          'sate',
          'soto',
          'pecel',
          'seblak',
          'dimsum',
          'martabak',
          'steak',
          'kebab',
          'ramen',
          'sushi',
          'bakery',
          'breadtalk',
          'mako',
          'jco',
          'dunkin',
          'roti',
          'croissant',
          'kue',
          'cake',
          'es teh',
          'jus',
          'makan',
          'sarapan',
          'snack',
          'gorengan',
          'minum',
          'susu',
        ],
        'Transportasi': <String>[
          'pertamina',
          'spbu',
          'shell',
          'vivo',
          'bp ',
          'pertalite',
          'pertamax',
          'solar',
          'bensin',
          'bbm',
          'parkir',
          'tol',
          'e-toll',
          'etoll',
          'flazz',
          'brizzi',
          'bengkel',
          'servis motor',
          'cuci motor',
          'cuci mobil',
          'oli',
          'gojek',
          'goride',
          'gocar',
          'grab',
          'grabbike',
          'grabcar',
          'maxim',
          'indrive',
          'bluebird',
          'taksi',
          'ojek',
          'transjakarta',
          'mrt',
          'lrt',
          'krl',
          'commuter',
          'kai',
          'whoosh',
          'kereta',
          'pesawat',
          'garuda',
          'lion air',
          'citilink',
          'airasia',
          'traveloka',
          'tiket.com',
        ],
        'Tagihan & Utilitas': <String>[
          'pln',
          'listrik',
          'token listrik',
          'pdam',
          'air bersih',
          'telkom',
          'indihome',
          'biznet',
          'myrepublic',
          'first media',
          'oxygen',
          'wifi',
          'internet',
          'pulsa',
          'paket data',
          'kuota',
          'telkomsel',
          'xl axiata',
          'indosat',
          'im3',
          'smartfren',
          'by.u',
          'axis',
          'bpjs',
          'pascabayar',
          'tagihan',
          'kos',
          'kost',
          'kontrakan',
          'sewa',
          'ipl',
          'cicilan',
          'paylater',
          'spaylater',
          'kredivo',
          'akulaku',
          'kartu kredit',
          'pbb',
          'samsat',
          'stnk',
        ],
        'Kesehatan': <String>[
          'apotek',
          'apotik',
          'kimia farma',
          'k-24',
          'k24',
          'century',
          'guardian',
          'watsons',
          'halodoc',
          'alodokter',
          'klinik',
          'rumah sakit',
          'rs ',
          'rsud',
          'dokter',
          'dental',
          'gigi',
          'prodia',
          'lab ',
          'obat',
          'vitamin',
          'paracetamol',
          'panadol',
          'tolak angin',
          'gym',
          'fitness',
          'fithub',
        ],
        'Hiburan': <String>[
          'netflix',
          'spotify',
          'youtube premium',
          'disney',
          'vidio',
          'viu',
          'wetv',
          'bioskop',
          'xxi',
          'cinema',
          'cgv',
          'cinepolis',
          'steam',
          'playstation',
          'xbox',
          'nintendo',
          'mobile legends',
          'valorant',
          'roblox',
          'genshin',
          'codashop',
          'unipin',
          'top up game',
          'voucher game',
          'karaoke',
          'billiard',
          'bowling',
          'konser',
          'tiket nonton',
          'nonton',
        ],
        'Pendidikan & Kerja': <String>[
          'gramedia',
          'buku',
          'atk',
          'fotokopi',
          'print',
          'udemy',
          'coursera',
          'dicoding',
          'kursus',
          'les ',
          'kampus',
          'spp',
          'ukt',
          'seminar',
          'workshop',
          'chatgpt',
          'openai',
          'notion',
          'figma',
          'canva',
          'github',
          'adobe',
          'domain',
          'hosting',
          'cloud',
        ],
        'Keluarga & Sosial': <String>[
          'zakat',
          'infaq',
          'infak',
          'sedekah',
          'donasi',
          'kitabisa',
          'baznas',
          'dompet dhuafa',
          'arisan',
          'kado',
          'hadiah',
          'sumbangan',
          'kondangan',
          'orang tua',
          'mama',
          'papa',
          'ibu',
          'ayah',
          'adek',
          'adik',
          'kakak',
          'istri',
          'suami',
          'keluarga',
          'uang jajan',
        ],
        'Belanja': <String>[
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
          'shopee',
          'tokopedia',
          'lazada',
          'blibli',
          'tiktok shop',
          'zalora',
          'uniqlo',
          'zara',
          'h&m',
          'sociolla',
          'sephora',
          'ace hardware',
          'informa',
          'decathlon',
          'deterjen',
          'sabun',
          'shampoo',
          'skincare',
          'sunscreen',
          'tisu',
          'pasta gigi',
          'belanja',
          'supermarket',
          'minimarket',
        ],
      };

  static const Map<String, List<String>> _incomeCategoryRules =
      <String, List<String>>{
        'Gaji': <String>['gaji', 'payroll', 'salary', 'upah', 'honor'],
        'Bonus & THR': <String>['bonus', 'thr', 'insentif', 'hadiah', 'angpao'],
        'Cashback & Refund': <String>[
          'cashback',
          'refund',
          'pengembalian',
          'kompensasi',
          'retur',
        ],
        'Investasi & Bunga': <String>[
          'bunga',
          'dividen',
          'bagi hasil',
          'deposito',
          'reksadana',
          'bibit',
          'stockbit',
        ],
        'Bisnis & Freelance': <String>[
          'freelance',
          'proyek',
          'project',
          'klien',
          'invoice',
          'omzet',
          'penjualan',
          'komisi',
        ],
      };

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
      return parseRecognizedText(recognized).copyWith(
        sourceImagePath: filePath,
      );
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
    final detectedWallet = _detectSourceWallet(lines);
    final paymentMethod = _detectPaymentMethod(lines);
    final transferNote = _extractTransferNote(lines);
    final adminFee = _extractAdminFee(lines);
    final suggestedKind = _detectTransactionKind(lines);
    final items = _extractLineItems(lines, bestTotal);
    final receiptDate = _parseReceiptDateTime(lines);

    final category = _inferSmartCategory(
      kind: suggestedKind,
      merchant: merchant,
      transferNote: transferNote,
      items: items,
      lines: lines,
      isDigitalReceipt: detectedWallet != null,
    );

    final detailSummary = _buildDetailSummary(
      merchant: merchant,
      detectedWallet: detectedWallet,
      paymentMethod: paymentMethod,
      transferNote: transferNote,
      adminFee: adminFee,
      items: items,
      lines: lines,
      suggestedKind: suggestedKind,
    );

    return ScannedReceiptData(
      merchantName: merchant,
      totalAmount: bestTotal,
      suggestedCategory: category,
      suggestedKind: suggestedKind,
      detectedWalletName: detectedWallet,
      paymentMethod: paymentMethod,
      transferNote: transferNote,
      adminFee: adminFee,
      receiptDate: receiptDate,
      items: items,
      receiptDetailText: detailSummary,
      rawText: rawText,
      reconstructedLines: lines,
      amountCandidates: candidates.take(4).toList(),
    );
  }

  static String? classifyNoteCategory(
    String text, {
    TransactionKind kind = TransactionKind.expense,
  }) {
    final trimmed = text.trim();
    if (trimmed.length < 2 || kind == TransactionKind.transfer) {
      return null;
    }
    if (kind == TransactionKind.income) {
      return _matchCategoryMap(trimmed, _incomeCategoryRules);
    }
    return _matchCategoryMap(trimmed, _expenseCategoryRules);
  }

  static TransactionKind _detectTransactionKind(List<String> lines) {
    final header = lines.take(8).join(' ').toLowerCase();
    const incomeSignals = <String>[
      'transfer masuk',
      'uang masuk',
      'saldo masuk',
      'dana masuk',
      'kamu menerima',
      'anda menerima',
      'terima dana',
      'penerimaan dana',
      'terima transfer',
      'refund berhasil',
      'cashback diterima',
    ];
    if (_matchesAny(header, incomeSignals)) {
      return TransactionKind.income;
    }
    return TransactionKind.expense;
  }

  static String? _detectSourceWallet(List<String> lines) {
    // Check explicit "Sumber Dana / Dari Kantong / Metode Pembayaran" context first.
    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      final isSourceContext =
          lower.contains('sumber dana') ||
          lower.contains('dari kantong') ||
          lower.contains('rekening sumber') ||
          lower.contains('dibayar dengan') ||
          lower.contains('metode bayar') ||
          lower.contains('metode pembayaran');
      if (isSourceContext) {
        final window = lines
            .sublist(i, math.min(lines.length, i + 3))
            .join(' ')
            .toLowerCase();
        final matched = _matchWalletBrand(window);
        if (matched != null) {
          return matched;
        }
      }
    }

    // Otherwise check top lines of digital bank / e-wallet screenshot.
    final topHeader = lines.take(4).join(' ').toLowerCase();
    return _matchWalletBrand(topHeader);
  }

  static String? _matchWalletBrand(String lowerText) {
    if (lowerText.contains('bank jago') ||
        _containsWholeWord(lowerText, 'jago') ||
        lowerText.contains('kantong utama')) {
      return 'Bank Jago';
    }
    if (lowerText.contains('seabank')) {
      return 'SeaBank';
    }
    if (lowerText.contains('shopeepay')) {
      return 'ShopeePay';
    }
    if (lowerText.contains('gopay')) {
      return 'GoPay';
    }
    if (_containsWholeWord(lowerText, 'dana')) {
      return 'DANA';
    }
    if (_containsWholeWord(lowerText, 'ovo')) {
      return 'OVO';
    }
    if (lowerText.contains('mybca') ||
        lowerText.contains('bca mobile') ||
        lowerText.contains('m-bca') ||
        _containsWholeWord(lowerText, 'bca')) {
      return 'BCA';
    }
    if (lowerText.contains('livin') || lowerText.contains('mandiri')) {
      return 'Mandiri';
    }
    if (lowerText.contains('brimo') || _containsWholeWord(lowerText, 'bri')) {
      return 'BRI';
    }
    if (lowerText.contains('blu by bca') || _containsWholeWord(lowerText, 'blu')) {
      return 'blu';
    }
    return null;
  }

  static String? _detectPaymentMethod(List<String> lines) {
    final full = lines.join(' ').toLowerCase();
    if (full.contains('qris')) {
      return 'QRIS';
    }
    if (full.contains('bi-fast') || full.contains('bifast')) {
      return 'Transfer BI-FAST';
    }
    if (full.contains('virtual account') || _containsWholeWord(full, 'va')) {
      return 'Virtual Account';
    }
    if (full.contains('top up') || full.contains('topup')) {
      return 'Top Up';
    }
    if (full.contains('transfer') || full.contains('kirim uang')) {
      return 'Transfer';
    }
    if (full.contains('debit')) {
      return 'Kartu Debit';
    }
    if (full.contains('tunai') || _containsWholeWord(full, 'cash')) {
      return 'Tunai';
    }
    return null;
  }

  static String? _extractTransferNote(List<String> lines) {
    const noteLabels = <String>[
      'catatan',
      'berita',
      'berita transfer',
      'keterangan',
      'pesan',
      'memo',
      'note',
    ];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lower = line.toLowerCase();
      final matched = noteLabels.any(
        (lbl) =>
            lower == lbl ||
            lower.startsWith('$lbl:') ||
            lower.startsWith('$lbl '),
      );
      if (!matched) {
        continue;
      }

      if (line.contains(':')) {
        final after = line.split(':').sublist(1).join(':').trim();
        if (after.length >= 2 &&
            after != '-' &&
            !_looksLikePhoneOrAccountLine(after)) {
          return after;
        }
      }

      if (i + 1 < lines.length) {
        final next = lines[i + 1].trim();
        final nextLower = next.toLowerCase();
        if (next.length >= 2 &&
            next.length <= 70 &&
            next != '-' &&
            !_looksLikePhoneOrAccountLine(next) &&
            !_matchesAny(nextLower, _nonPriceLineKeywords) &&
            !_matchesAny(nextLower, _excludedTotalLineKeywords) &&
            !_matchesAny(nextLower, _primaryTotalKeywords)) {
          return next;
        }
      }
    }
    return null;
  }

  static int? _extractAdminFee(List<String> lines) {
    const feeLabels = <String>[
      'biaya admin',
      'biaya transaksi',
      'biaya transfer',
      'biaya layanan',
      'admin fee',
    ];
    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      if (!_matchesAny(lower, feeLabels)) {
        continue;
      }
      if (RegExp(r'rp\.?\s*0\b|gratis|free').hasMatch(lower)) {
        return 0;
      }
      final tokens = _extractPriceTokens(lines[i]);
      if (tokens.isNotEmpty) {
        return tokens.last.amount;
      }
      if (i + 1 < lines.length) {
        final nextTokens = _extractPriceTokens(lines[i + 1]);
        if (nextTokens.isNotEmpty && nextTokens.last.amount <= 25000) {
          return nextTokens.last.amount;
        }
      }
    }
    return null;
  }

  static List<ReceiptLineItem> _extractLineItems(
    List<String> lines,
    int? bestTotal,
  ) {
    final items = <ReceiptLineItem>[];
    final seen = <String>{};

    // Stop scanning item lines once we hit summary/footer lines on store receipts.
    var reachedSummarySection = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lower = line.toLowerCase();

      if (_matchesAny(lower, _primaryTotalKeywords) ||
          _matchesAny(lower, _cashPaidKeywords) ||
          _matchesAny(lower, _changeKeywords) ||
          lower.contains('subtotal') ||
          lower.contains('sub total') ||
          lower.contains('harga jual') ||
          _containsWholeWord(lower, 'total')) {
        reachedSummarySection = true;
        continue;
      }
      if (reachedSummarySection) {
        continue;
      }

      if (_matchesAny(lower, _excludedTotalLineKeywords) ||
          _matchesAny(lower, _nonPriceLineKeywords) ||
          _matchesAny(lower, _paymentMethodKeywords) ||
          _matchesAny(lower, _ignoredMerchantTokens) ||
          _looksLikePhoneOrAccountLine(line)) {
        continue;
      }

      final tokens = _extractPriceTokens(line);
      if (tokens.isEmpty) {
        continue;
      }

      final priceToken = tokens.last;
      if (bestTotal != null &&
          priceToken.amount > bestTotal &&
          bestTotal >= 1000) {
        continue;
      }

      // Extract the item name sitting to the left of the price token.
      var namePart = line.substring(0, math.min(line.length, priceToken.startOffset)).trim();
      if (namePart.isEmpty) {
        // Fallback: strip the formatted price from the end of the line.
        namePart = line
            .replaceAll(
              RegExp(
                r'(?:rp|idr)?\.?\s*\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?\s*$',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
      }

      var qty = 1;
      final leadingQty = RegExp(r'^(\d{1,2})\s*[xX*]\s+').firstMatch(namePart);
      if (leadingQty != null) {
        qty = int.tryParse(leadingQty.group(1)!) ?? 1;
        namePart = namePart.substring(leadingQty.end).trim();
      } else {
        final trailingQty = RegExp(r'\s+(\d{1,2})\s*[xX*@]\s*[\d.,]*$').firstMatch(namePart);
        if (trailingQty != null) {
          qty = int.tryParse(trailingQty.group(1)!) ?? 1;
          namePart = namePart.substring(0, trailingQty.start).trim();
        }
      }

      namePart = namePart
          .replaceAll(RegExp(r'^[\-\*\•\d\.\)\s]{1,4}(?=[A-Za-z])'), '')
          .replaceAll(RegExp(r'[\s:\-]+$'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final letters = RegExp(r'[A-Za-z]').allMatches(namePart).length;
      if (letters < 3 || namePart.length > 48) {
        continue;
      }

      final cleanName = _titleCase(namePart);
      final dedupeKey = '${cleanName.toLowerCase()}_${priceToken.amount}';
      if (seen.add(dedupeKey)) {
        items.add(
          ReceiptLineItem(
            name: cleanName,
            price: priceToken.amount,
            quantity: qty,
          ),
        );
      }
      if (items.length >= 15) {
        break;
      }
    }

    return items;
  }

  static String _inferSmartCategory({
    required TransactionKind kind,
    required String merchant,
    required String? transferNote,
    required List<ReceiptLineItem> items,
    required List<String> lines,
    required bool isDigitalReceipt,
  }) {
    if (kind == TransactionKind.income) {
      final full = '$merchant ${transferNote ?? ''} ${lines.join(' ')}';
      return _matchCategoryMap(full, _incomeCategoryRules) ?? 'Pemasukan Lain';
    }

    // 1. Explicit transfer note carries the user's exact intent ("bayar kos", "beli obat").
    if (transferNote != null && transferNote.trim().isNotEmpty) {
      final fromNote = _matchCategoryMap(transferNote, _expenseCategoryRules);
      if (fromNote != null) {
        return fromNote;
      }
    }

    // 2. Merchant / recipient name (e.g. "Indomaret", "Kopi Kenangan", "PLN", "Warung Sate").
    final fromMerchant = _matchCategoryMap(merchant, _expenseCategoryRules);
    if (fromMerchant != null) {
      return fromMerchant;
    }

    // 3. Majority vote across extracted receipt line items (e.g. unknown shop name selling coffee or medicine).
    if (items.isNotEmpty) {
      final votes = <String, int>{};
      for (final item in items) {
        final cat = _matchCategoryMap(item.name, _expenseCategoryRules);
        if (cat != null) {
          votes[cat] = (votes[cat] ?? 0) + item.price;
        }
      }
      if (votes.isNotEmpty) {
        final ranked = votes.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return ranked.first.key;
      }
    }

    // 4. Full receipt text scan (excluding wallet brand header lines to avoid false matches).
    final fromAll = _matchCategoryMap(lines.join('\n'), _expenseCategoryRules);
    if (fromAll != null) {
      return fromAll;
    }

    // 5. Intelligent fallback: person-to-person digital transfer vs store receipt.
    if (isDigitalReceipt && items.isEmpty) {
      return 'Lainnya';
    }
    return 'Belanja';
  }

  static String? _matchCategoryMap(
    String content,
    Map<String, List<String>> rules,
  ) {
    final lower = content.toLowerCase();
    for (final entry in rules.entries) {
      if (_matchesAny(lower, entry.value)) {
        return entry.key;
      }
    }
    return null;
  }

  static String _buildDetailSummary({
    required String merchant,
    required String? detectedWallet,
    required String? paymentMethod,
    required String? transferNote,
    required int? adminFee,
    required List<ReceiptLineItem> items,
    required List<String> lines,
    required TransactionKind suggestedKind,
  }) {
    final buffer = <String>[];

    if (detectedWallet != null || paymentMethod != null) {
      final parts = <String>[
        ?detectedWallet,
        ?paymentMethod,
      ];
      buffer.add('Sumber: ${parts.join(' · ')}');
    }

    if (merchant.isNotEmpty && merchant != 'Belanja Struk') {
      final label = detectedWallet != null && items.isEmpty
          ? (suggestedKind == TransactionKind.income ? 'Pengirim' : 'Penerima')
          : 'Toko';
      buffer.add('$label: $merchant');
    }

    if (transferNote != null && transferNote.trim().isNotEmpty) {
      buffer.add('Catatan resi: $transferNote');
    }

    if (adminFee != null && adminFee > 0) {
      buffer.add('Biaya admin: ${IdrFormat.currency(adminFee)}');
    }

    if (items.isNotEmpty) {
      buffer.add('Rincian item (${items.length}):');
      for (final item in items) {
        buffer.add('- ${item.formatLine()}');
      }
    }

    final dateLine = _extractReceiptDateLine(lines);
    if (dateLine != null) {
      buffer.add('Waktu resi: $dateLine');
    }

    return buffer.join('\n').trim();
  }

  static String? _extractReceiptDateLine(List<String> lines) {
    final pattern = RegExp(
      r'\b(?:\d{1,2}\s+(?:jan|feb|mar|apr|mei|may|jun|jul|agu|aug|sep|okt|oct|nov|des|dec)[a-z]*\s+\d{4}(?:[,\s]+\d{1,2}:\d{2}(?:\s*wib|wita|wit)?)?|\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2})?|\d{4}[/-]\d{1,2}[/-]\d{1,2}(?:\s+\d{1,2}:\d{2})?)\b',
      caseSensitive: false,
    );
    for (final line in lines) {
      final m = pattern.firstMatch(line);
      if (m != null) {
        return m.group(0)?.trim();
      }
    }
    return null;
  }

  static DateTime? _parseReceiptDateTime(List<String> lines) {
    const monthLookup = <String, int>{
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'mei': 5,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'agu': 8,
      'aug': 8,
      'sep': 9,
      'okt': 10,
      'oct': 10,
      'nov': 11,
      'des': 12,
      'dec': 12,
    };

    DateTime? validate(int year, int month, int day, int hour, int minute) {
      final maxYear = DateTime.now().year + 1;
      if (year < 2020 || year > maxYear) return null;
      if (month < 1 || month > 12) return null;
      if (day < 1 || day > 31) return null;
      final safeHour = (hour >= 0 && hour <= 23) ? hour : 12;
      final safeMin = (minute >= 0 && minute <= 59) ? minute : 0;
      final dt = DateTime(year, month, day, safeHour, safeMin);
      if (dt.month != month || dt.day != day) return null;
      return dt;
    }

    final namedPattern = RegExp(
      r'\b(\d{1,2})\s+(jan|feb|mar|apr|mei|may|jun|jul|agu|aug|sep|okt|oct|nov|des|dec)[a-z]*\s+(\d{4})(?:[,\s]+(\d{1,2})[:.](\d{2}))?\b',
      caseSensitive: false,
    );
    final dmyPattern = RegExp(
      r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})(?:\s+(\d{1,2})[:.](\d{2}))?\b',
    );
    final ymdPattern = RegExp(
      r'\b(\d{4})[/-](\d{1,2})[/-](\d{1,2})(?:\s+(\d{1,2})[:.](\d{2}))?\b',
    );

    for (final line in lines) {
      final named = namedPattern.firstMatch(line);
      if (named != null) {
        final day = int.tryParse(named.group(1) ?? '') ?? 0;
        final monthKey = (named.group(2) ?? '').toLowerCase();
        final month = monthLookup[monthKey] ?? 0;
        final year = int.tryParse(named.group(3) ?? '') ?? 0;
        final hour = int.tryParse(named.group(4) ?? '') ?? 12;
        final minute = int.tryParse(named.group(5) ?? '') ?? 0;
        final dt = validate(year, month, day, hour, minute);
        if (dt != null) return dt;
      }

      final ymd = ymdPattern.firstMatch(line);
      if (ymd != null) {
        final year = int.tryParse(ymd.group(1) ?? '') ?? 0;
        final month = int.tryParse(ymd.group(2) ?? '') ?? 0;
        final day = int.tryParse(ymd.group(3) ?? '') ?? 0;
        final hour = int.tryParse(ymd.group(4) ?? '') ?? 12;
        final minute = int.tryParse(ymd.group(5) ?? '') ?? 0;
        final dt = validate(year, month, day, hour, minute);
        if (dt != null) return dt;
      }

      final dmy = dmyPattern.firstMatch(line);
      if (dmy != null) {
        final day = int.tryParse(dmy.group(1) ?? '') ?? 0;
        final month = int.tryParse(dmy.group(2) ?? '') ?? 0;
        var year = int.tryParse(dmy.group(3) ?? '') ?? 0;
        if (year > 0 && year < 100) {
          year += 2000;
        }
        final hour = int.tryParse(dmy.group(4) ?? '') ?? 12;
        final minute = int.tryParse(dmy.group(5) ?? '') ?? 0;
        final dt = validate(year, month, day, hour, minute);
        if (dt != null) return dt;
      }
    }
    return null;
  }

  static String _extractMerchant(List<String> lines, String rawText) {
    // 1. Digital bank/e-wallet transfer receipts: extract Recipient / Merchant explicitly.
    const recipientLabels = <String>[
      'penerima',
      'dikirim ke',
      'kirim ke',
      'transfer ke',
      'bayar ke',
      'pembayaran ke',
      'nama merchant',
      'merchant',
      'tujuan',
    ];
    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase().trim();
      final matchedLabel = recipientLabels.any(
        (lbl) =>
            lower == lbl ||
            lower.startsWith('$lbl ') ||
            lower.startsWith('$lbl:'),
      );
      if (!matchedLabel) {
        continue;
      }
      final afterColon = lines[i].contains(':')
          ? lines[i].split(':').sublist(1).join(':').trim()
          : '';
      if (afterColon.length >= 3 &&
          RegExp(r'[A-Za-z]{3,}').hasMatch(afterColon) &&
          !_looksLikePhoneOrAccountLine(afterColon)) {
        return _titleCase(afterColon);
      }
      for (var j = i + 1; j < math.min(lines.length, i + 4); j++) {
        final cand = lines[j].trim();
        final candLower = cand.toLowerCase();
        if (cand.length < 3 || cand.length > 48) {
          continue;
        }
        if (_looksLikePhoneOrAccountLine(cand) ||
            _extractPriceTokens(cand).isNotEmpty ||
            _ignoredMerchantTokens.any(candLower.contains)) {
          continue;
        }
        final letters = RegExp(r'[A-Za-z]').allMatches(cand).length;
        final digits = RegExp(r'\d').allMatches(cand).length;
        if (letters >= 3 && digits <= 2) {
          return _titleCase(cand);
        }
      }
    }

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

  static bool _looksLikePhoneOrAccountLine(String line) {
    final trimmed = line.trim();
    if (RegExp(r'(?:\+?62|0)[\s.\-]*8\d(?:[\s.\-]*\d){6,12}').hasMatch(trimmed)) {
      return true;
    }
    if (RegExp(r'[*•xX]{2,}\s*\d{2,}').hasMatch(trimmed)) {
      return true;
    }
    if (RegExp(r'^\+?\d[\d\s.\-]{7,}$').hasMatch(trimmed)) {
      return true;
    }
    return false;
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

      if (_matchesAny(lower, _nonPriceLineKeywords)) {
        continue;
      }

      if (_matchesAny(lower, _paymentMethodKeywords)) {
        final token = _rightmostPriceFromLineOrNext(lines, i);
        if (token != null && token.hasSeparatorOrCurrency) {
          scored.add(
            ReceiptAmountCandidate(
              label: _shortLabel(line, fallback: 'Pembayaran'),
              amount: token.amount,
              score: 74 + (token.hasCurrencyPrefix ? 8 : 4),
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
        continue;
      }

      final explicitTokens = _extractPriceTokens(line)
          .where((t) => t.hasCurrencyPrefix)
          .toList();
      if (explicitTokens.isNotEmpty) {
        final nonCurrencyLetters = RegExp(r'[A-Za-z]')
            .allMatches(
              line.replaceAll(RegExp(r'\b(rp|idr)\b', caseSensitive: false), ''),
            )
            .length;
        final heroToken = explicitTokens.last;
        scored.add(
          ReceiptAmountCandidate(
            label: nonCurrencyLetters <= 2
                ? 'Nominal Transaksi'
                : _shortLabel(line, fallback: 'Nominal Rp'),
            amount: heroToken.amount,
            score: nonCurrencyLetters <= 2 ? 90 : 72,
          ),
        );
      }
    }

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
              nextLine.replaceAll(
                RegExp(r'\b(rp|idr)\b', caseSensitive: false),
                '',
              ),
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
    final lowerLine = rawLine.toLowerCase();
    final isDiscountLine = _matchesAny(lowerLine, const <String>[
      'diskon',
      'disc',
      'potongan',
      'hemat',
      'voucher',
      'kupon',
      'promo',
    ]);

    var sanitized = rawLine
        .replaceAll(RegExp(r'\b\d{1,4}[/-]\d{1,2}[/-]\d{2,4}\b'), ' ')
        .replaceAll(RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b'), ' ')
        .replaceAll(RegExp(r'(?:\+?62|0)[\s.\-]*8\d(?:[\s.\-]*\d){6,12}'), ' ')
        .replaceAll(RegExp(r'\b8\d{2}[\s.\-]\d{3,4}[\s.\-]\d{3,5}\b'), ' ')
        .replaceAll(RegExp(r'(?:\+?62|0)[\s.\-]*2\d(?:[\s.\-]*\d){6,10}'), ' ')
        .replaceAll(RegExp(r'[*•xX]{2,}[\s\-]*\d{2,8}'), ' ')
        .replaceAll(RegExp(r'\b\d{4}[\s\-]\d{4}(?:[\s\-]\d{2,6})+\b'), ' ')
        .replaceAll(RegExp(r'\b[A-Za-z]+\d{4,}[A-Za-z0-9]*\b'), ' ')
        .replaceAll(RegExp(r'\b\d{4,}[A-Za-z]+[A-Za-z0-9]*\b'), ' ')
        .replaceAll(RegExp(r'\b\d{9,}\b'), ' ');

    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(\d)\s*([.,])\s*([\dOo]{3})\b'),
      (m) => '${m.group(1)}${m.group(2)}${m.group(3)}',
    );
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

      final hasCurrencyPrefix = RegExp(
        r'^(?:rp|idr)',
        caseSensitive: false,
      ).hasMatch(fullMatch.trimLeft());

      if (match.start > 0) {
        final leadingSlice = sanitized.substring(0, match.start).trimRight();
        if (leadingSlice.endsWith('(')) {
          continue;
        }
        if (leadingSlice.endsWith('-') &&
            (!hasCurrencyPrefix || isDiscountLine)) {
          continue;
        }
      }

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

      var hasThousandSep = RegExp(r'\d[.,]\d{3}\b').hasMatch(numberPart);

      if (RegExp(r'[.,]\d{2}$').hasMatch(numberPart)) {
        numberPart = numberPart.substring(0, numberPart.length - 3);
        hasThousandSep =
            hasThousandSep || RegExp(r'\d[.,]\d{3}\b').hasMatch(numberPart);
      }

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
      if (!hasCurrencyPrefix && !hasThousandSep) {
        if ((parsed >= 2020 && parsed <= 2035) ||
            (parsed >= 20200101 && parsed <= 20351231)) {
          continue;
        }
        if (digits.length >= 7 && parsed % 100 != 0) {
          continue;
        }
      }

      tokens.add(
        _ParsedPriceToken(
          amount: parsed,
          hasSeparatorOrCurrency: hasCurrencyPrefix || hasThousandSep,
          hasCurrencyPrefix: hasCurrencyPrefix,
          startOffset: match.start,
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

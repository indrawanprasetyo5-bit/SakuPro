import '../models/transaction_item.dart';
import '../models/wallet.dart';

class BankNotificationSource {
  const BankNotificationSource({
    required this.id,
    required this.name,
    required this.walletName,
    required this.walletKind,
    required this.walletColor,
    required this.walletIconKey,
    required this.packages,
    this.isPrimary = false,
  });

  final String id;
  final String name;
  final String walletName;
  final WalletKind walletKind;
  final int walletColor;
  final String walletIconKey;
  final List<String> packages;
  final bool isPrimary;
}

class RawBankNotification {
  const RawBankNotification({
    required this.packageName,
    required this.title,
    required this.text,
    this.subText = '',
    required this.postTimeMs,
    this.fingerprint = '',
  });

  final String packageName;
  final String title;
  final String text;
  final String subText;
  final int postTimeMs;
  final String fingerprint;

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(postTimeMs);

  String get effectiveFingerprint {
    if (fingerprint.isNotEmpty) {
      return fingerprint;
    }
    final bucket = postTimeMs ~/ 20000;
    return '${packageName.toLowerCase()}|${title.toLowerCase()}|${text.toLowerCase()}|$bucket';
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'packageName': packageName,
    'title': title,
    'text': text,
    'subText': subText,
    'postTime': postTimeMs,
    'fingerprint': effectiveFingerprint,
  };

  factory RawBankNotification.fromJson(Map<String, Object?> map) {
    return RawBankNotification(
      packageName: (map['packageName'] as String?)?.trim() ?? '',
      title: (map['title'] as String?)?.trim() ?? '',
      text: (map['text'] as String?)?.trim() ?? '',
      subText: (map['subText'] as String?)?.trim() ?? '',
      postTimeMs:
          (map['postTime'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      fingerprint: (map['fingerprint'] as String?)?.trim() ?? '',
    );
  }
}

class ParsedBankNotification {
  const ParsedBankNotification({
    required this.fingerprint,
    required this.sourceId,
    required this.sourceName,
    required this.suggestedWalletName,
    required this.kind,
    required this.amount,
    required this.merchant,
    required this.category,
    required this.note,
    required this.timestamp,
    required this.rawTitle,
    required this.rawText,
    this.targetWalletHint,
  });

  final String fingerprint;
  final String sourceId;
  final String sourceName;
  final String suggestedWalletName;
  final TransactionKind kind;
  final int amount;
  final String merchant;
  final String category;
  final String note;
  final DateTime timestamp;
  final String rawTitle;
  final String rawText;
  final String? targetWalletHint;

  Map<String, Object?> toJson() => <String, Object?>{
    'fingerprint': fingerprint,
    'sourceId': sourceId,
    'sourceName': sourceName,
    'suggestedWalletName': suggestedWalletName,
    'kind': kind.code,
    'amount': amount,
    'merchant': merchant,
    'category': category,
    'note': note,
    'timestamp': timestamp.toIso8601String(),
    'rawTitle': rawTitle,
    'rawText': rawText,
    if (targetWalletHint != null) 'targetWalletHint': targetWalletHint,
  };

  factory ParsedBankNotification.fromJson(Map<String, Object?> map) {
    return ParsedBankNotification(
      fingerprint: (map['fingerprint'] as String?) ?? '',
      sourceId: (map['sourceId'] as String?) ?? 'unknown',
      sourceName: (map['sourceName'] as String?) ?? 'Bank',
      suggestedWalletName: (map['suggestedWalletName'] as String?) ?? 'Cash',
      kind: TransactionKind.fromCode((map['kind'] as String?) ?? 'expense'),
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      merchant: (map['merchant'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'Lainnya',
      note: (map['note'] as String?) ?? '',
      timestamp:
          DateTime.tryParse((map['timestamp'] as String?) ?? '') ??
          DateTime.now(),
      rawTitle: (map['rawTitle'] as String?) ?? '',
      rawText: (map['rawText'] as String?) ?? '',
      targetWalletHint: map['targetWalletHint'] as String?,
    );
  }
}

class AutoCaptureLogEntry {
  const AutoCaptureLogEntry({
    required this.sourceName,
    required this.title,
    required this.text,
    required this.statusLabel,
    required this.accepted,
    required this.timestamp,
  });

  final String sourceName;
  final String title;
  final String text;
  final String statusLabel;
  final bool accepted;
  final DateTime timestamp;
}

class BankNotificationPreset {
  const BankNotificationPreset({
    required this.label,
    required this.packageName,
    required this.title,
    required this.text,
  });

  final String label;
  final String packageName;
  final String title;
  final String text;
}

class BankNotificationParser {
  BankNotificationParser._();

  static const List<BankNotificationSource> supportedSources =
      <BankNotificationSource>[
        BankNotificationSource(
          id: 'seabank',
          name: 'SeaBank',
          walletName: 'SeaBank',
          walletKind: WalletKind.bank,
          walletColor: 0xFFEA580C,
          walletIconKey: 'account_balance',
          packages: <String>['id.co.bankbkemobile.digitalbank'],
          isPrimary: true,
        ),
        BankNotificationSource(
          id: 'dana',
          name: 'DANA',
          walletName: 'DANA',
          walletKind: WalletKind.ewallet,
          walletColor: 0xFF0284C7,
          walletIconKey: 'smartphone',
          packages: <String>['id.dana'],
          isPrimary: true,
        ),
        BankNotificationSource(
          id: 'gopay',
          name: 'GoPay / Gojek',
          walletName: 'GoPay',
          walletKind: WalletKind.ewallet,
          walletColor: 0xFF00AED6,
          walletIconKey: 'qr_code',
          packages: <String>['com.gojek.gopay', 'com.gojek.app'],
          isPrimary: true,
        ),
        BankNotificationSource(
          id: 'jago',
          name: 'Bank Jago',
          walletName: 'Bank Jago',
          walletKind: WalletKind.bank,
          walletColor: 0xFFD97706,
          walletIconKey: 'account_balance',
          packages: <String>['com.jago.digitalBanking'],
          isPrimary: true,
        ),
        BankNotificationSource(
          id: 'bca',
          name: 'BCA / myBCA',
          walletName: 'BCA',
          walletKind: WalletKind.bank,
          walletColor: 0xFF1D4ED8,
          walletIconKey: 'account_balance',
          packages: <String>['com.bca', 'com.bca.mybca.omni.android'],
        ),
        BankNotificationSource(
          id: 'mandiri',
          name: "Livin' Mandiri",
          walletName: 'Mandiri',
          walletKind: WalletKind.bank,
          walletColor: 0xFF1E3A8A,
          walletIconKey: 'account_balance',
          packages: <String>['id.bmri.livin'],
        ),
        BankNotificationSource(
          id: 'bri',
          name: 'BRImo',
          walletName: 'BRI',
          walletKind: WalletKind.bank,
          walletColor: 0xFF0369A1,
          walletIconKey: 'account_balance',
          packages: <String>['id.co.bri.brimo'],
        ),
        BankNotificationSource(
          id: 'ovo',
          name: 'OVO',
          walletName: 'OVO',
          walletKind: WalletKind.ewallet,
          walletColor: 0xFF6D28D9,
          walletIconKey: 'smartphone',
          packages: <String>['ovo.id'],
        ),
        BankNotificationSource(
          id: 'shopeepay',
          name: 'ShopeePay',
          walletName: 'ShopeePay',
          walletKind: WalletKind.ewallet,
          walletColor: 0xFFDC2626,
          walletIconKey: 'smartphone',
          packages: <String>['com.shopeepay.id', 'com.shopee.id'],
        ),
        BankNotificationSource(
          id: 'blu',
          name: 'blu by BCA',
          walletName: 'blu',
          walletKind: WalletKind.bank,
          walletColor: 0xFF0891B2,
          walletIconKey: 'account_balance',
          packages: <String>['com.bcadigital.blu'],
        ),
      ];

  static const Set<String> defaultEnabledSourceIds = <String>{
    'seabank',
    'dana',
    'gopay',
    'jago',
  };

  static const List<BankNotificationPreset> testPresets =
      <BankNotificationPreset>[
        BankNotificationPreset(
          label: 'SeaBank QRIS Kopi',
          packageName: 'id.co.bankbkemobile.digitalbank',
          title: 'Pembayaran QRIS Berhasil',
          text:
              'Kamu telah membayar Rp28.000 ke Kopi Kenangan menggunakan QRIS.',
        ),
        BankNotificationPreset(
          label: 'DANA QRIS Indomaret',
          packageName: 'id.dana',
          title: 'Pembayaran Berhasil',
          text: 'Kamu berhasil bayar Rp42.500 di Indomaret menggunakan DANA.',
        ),
        BankNotificationPreset(
          label: 'GoPay QRIS Makan',
          packageName: 'com.gojek.gopay',
          title: 'Pembayaran GoPay Berhasil',
          text: 'Kamu bayar Rp36.000 ke Mie Gacoan pakai GoPay QRIS.',
        ),
        BankNotificationPreset(
          label: 'Bank Jago QRIS',
          packageName: 'com.jago.digitalBanking',
          title: 'Pembayaran QRIS berhasil',
          text:
              'Transaksi QRIS sebesar Rp55.000 di Fore Coffee berhasil dari Kantong Utama.',
        ),
        BankNotificationPreset(
          label: 'SeaBank Transfer Masuk',
          packageName: 'id.co.bankbkemobile.digitalbank',
          title: 'Transfer Masuk',
          text: 'Kamu menerima transfer sebesar Rp750.000 dari Raka Pratama.',
        ),
        BankNotificationPreset(
          label: 'SeaBank Top Up DANA',
          packageName: 'id.co.bankbkemobile.digitalbank',
          title: 'Top Up E-Wallet Berhasil',
          text: 'Kamu berhasil top up DANA sebesar Rp200.000 dari SeaBank.',
        ),
        BankNotificationPreset(
          label: 'Promo Spam (Diabaikan)',
          packageName: 'id.dana',
          title: 'Cashback hingga Rp50.000!',
          text: 'Bayar QRIS hari ini dan dapatkan voucher diskon spesial.',
        ),
      ];

  static String normalizeMerchantKey(String raw) {
    var cleaned = raw.trim().toLowerCase();
    cleaned = cleaned.replaceFirst(RegExp(r'^qris\s+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  static BankNotificationSource? findSourceByPackage(String packageName) {
    final lower = packageName.trim().toLowerCase();
    for (final source in supportedSources) {
      for (final pkg in source.packages) {
        if (pkg.toLowerCase() == lower) {
          return source;
        }
      }
    }
    return null;
  }

  static BankNotificationSource? findSourceById(String id) {
    for (final source in supportedSources) {
      if (source.id == id) {
        return source;
      }
    }
    return null;
  }

  static List<String> packagesForSourceIds(Iterable<String> sourceIds) {
    final result = <String>{};
    for (final id in sourceIds) {
      final src = findSourceById(id);
      if (src != null) {
        result.addAll(src.packages);
      }
    }
    return result.toList();
  }

  static final RegExp _rejectNoiseRegex = RegExp(
    r'\b(otp|kode\s+verifikasi|verification\s+code|kode\s+rahasia|jangan\s+berikan|'
    r'pin\s+anda|promo|diskon|voucher|kupon|cashback\s+hingga|cashback\s+s/?d|'
    r'gratis\s+ongkir|ajak\s+teman|undang\s+teman|menangkan|undian|hadiah|'
    r'gagal|dibatalkan|failed|cancelled|canceled|declined|kadaluarsa|expired|'
    r'menunggu\s+pembayaran|belum\s+dibayar|pengingat|jatuh\s+tempo|tagihan\s+akan|'
    r'dapatkan\s+rp|raih\s+rp|hemat\s+hingga|klaim\s+sekarang|serbu|flash\s+sale)\b',
    caseSensitive: false,
  );

  static final RegExp _txActionVerbRegex = RegExp(
    r'\b(qris|pembayaran|bayar|dibayar|membayar|transaksi|transfer|terima|'
    r'diterima|menerima|masuk|keluar|kirim|dikirim|mengirim|debit|kredit|'
    r'top\s*up|isi\s+saldo|tarik\s+tunai|pembelian|berhasil|sukses|'
    r'paid|payment|received|sent|credited|debited)\b',
    caseSensitive: false,
  );

  static final RegExp _incomeCueRegex = RegExp(
    r'\b(transfer\s+masuk|uang\s+masuk|saldo\s+masuk|dana\s+masuk|'
    r'gopay\s+masuk|terima\s+uang|kamu\s+menerima|anda\s+menerima|'
    r'kamu\s+terima|telah\s+menerima|berhasil\s+menerima|kredit|'
    r'credited|received|refund|pengembalian\s+dana|bunga\s+cair|'
    r'pencairan|top\s*up\s+.*\s+berhasil|isi\s+saldo\s+.*\s+berhasil|'
    r'top\s*up\s+berhasil|isi\s+saldo\s+berhasil)\b',
    caseSensitive: false,
  );

  static final RegExp _expenseCueRegex = RegExp(
    r'\b(qris|pembayaran|bayar|membayar|dibayar|uang\s+keluar|transfer\s+keluar|'
    r'saldo\s+keluar|pembelian|tarik\s+tunai|debit|debited|paid|payment|'
    r'kirim\s+uang|mengirim|terpotong|autodebit)\b',
    caseSensitive: false,
  );

  static final RegExp _currencyAmountRegex = RegExp(
    r'(?:rp\.?|idr)\s*([0-9]{1,3}(?:[.,][0-9]{3})+|[0-9]{3,9})(?:[.,]([0-9]{1,2}))?(?!\d)',
    caseSensitive: false,
  );

  static ParsedBankNotification? parse(
    RawBankNotification raw, {
    Map<String, String> learnedCategories = const <String, String>{},
  }) {
    final source = findSourceByPackage(raw.packageName);
    if (source == null) {
      return null;
    }

    final combined = '${raw.title} ${raw.text} ${raw.subText}'.trim();
    if (combined.isEmpty) {
      return null;
    }

    if (_rejectNoiseRegex.hasMatch(combined)) {
      return null;
    }

    if (!_txActionVerbRegex.hasMatch(combined)) {
      return null;
    }

    final amount = _extractAmount(raw.text) ?? _extractAmount(combined);
    if (amount == null || amount < 500 || amount > 500000000) {
      return null;
    }

    final hasIncomeCue = _incomeCueRegex.hasMatch(combined);
    final hasExpenseCue = _expenseCueRegex.hasMatch(combined);

    // Outgoing top-up/transfer from a bank to another e-wallet is detected explicitly
    // before classifying generic "top up berhasil" as incoming balance.
    final targetWalletHint = _detectExplicitTargetWallet(
      combined: combined,
      sourceWalletName: source.walletName,
    );

    final isQris = RegExp(r'\bqris\b', caseSensitive: false).hasMatch(combined);
    final TransactionKind kind;
    if (isQris || targetWalletHint != null) {
      kind = TransactionKind.expense;
    } else if (hasIncomeCue && !hasExpenseCue) {
      kind = TransactionKind.income;
    } else if (hasIncomeCue &&
        RegExp(
          r'\b(transfer\s+masuk|uang\s+masuk|saldo\s+masuk|menerima|terima\s+rp|top\s*up|isi\s+saldo|refund)\b',
          caseSensitive: false,
        ).hasMatch(combined)) {
      kind = TransactionKind.income;
    } else {
      kind = TransactionKind.expense;
    }

    final merchant = _extractMerchant(
      title: raw.title,
      body: raw.text,
      kind: kind,
      sourceName: source.name,
    );
    final category = _resolveCategoryWithMemory(
      kind: kind,
      merchant: merchant,
      combinedText: combined,
      learnedCategories: learnedCategories,
    );

    final prefix = isQris
        ? 'QRIS'
        : (kind == TransactionKind.income ? 'Masuk' : source.name);
    final note = merchant.isNotEmpty
        ? (isQris ? 'QRIS $merchant' : merchant)
        : (raw.title.isNotEmpty ? raw.title : '$prefix ${source.name}');

    return ParsedBankNotification(
      fingerprint: raw.effectiveFingerprint,
      sourceId: source.id,
      sourceName: source.name,
      suggestedWalletName: source.walletName,
      kind: kind,
      amount: amount,
      merchant: merchant,
      category: category,
      note: note,
      timestamp: raw.timestamp,
      rawTitle: raw.title,
      rawText: raw.text,
      targetWalletHint: targetWalletHint,
    );
  }

  static String? _detectExplicitTargetWallet({
    required String combined,
    required String sourceWalletName,
  }) {
    final lower = combined.toLowerCase();
    final isOutgoingMove = RegExp(
      r'\b(top\s*up|isi\s+saldo|transfer\s+keluar|transfer\s+ke|kirim\s+ke|bayar\s+ke)\b',
    ).hasMatch(lower);
    if (!isOutgoingMove) {
      return null;
    }

    const aliases = <String, String>{
      'seabank': 'SeaBank',
      'dana': 'DANA',
      'gopay': 'GoPay',
      'bank jago': 'Bank Jago',
      'jago': 'Bank Jago',
      'bca': 'BCA',
      'mandiri': 'Mandiri',
      'bri': 'BRI',
      'ovo': 'OVO',
      'shopeepay': 'ShopeePay',
      'blu': 'blu',
    };

    for (final entry in aliases.entries) {
      if (entry.value.toLowerCase() == sourceWalletName.toLowerCase()) {
        continue;
      }
      final pattern = RegExp(
        '(?:top\\s*up|isi\\s+saldo|ke|to)\\s+(?:e-?wallet\\s+|rekening\\s+)?${RegExp.escape(entry.key)}\\b',
      );
      if (pattern.hasMatch(lower)) {
        return entry.value;
      }
    }
    return null;
  }

  static String _resolveCategoryWithMemory({
    required TransactionKind kind,
    required String merchant,
    required String combinedText,
    required Map<String, String> learnedCategories,
  }) {
    if (learnedCategories.isNotEmpty && merchant.isNotEmpty) {
      final key = normalizeMerchantKey(merchant);
      if (key.isNotEmpty) {
        final exact = learnedCategories[key];
        if (exact != null && exact.isNotEmpty) {
          return exact;
        }
        for (final entry in learnedCategories.entries) {
          if (entry.key.length >= 4 &&
              (key.contains(entry.key) || entry.key.contains(key))) {
            return entry.value;
          }
        }
      }
    }
    return _inferCategory(
      kind: kind,
      merchant: merchant,
      combinedText: combinedText,
    );
  }

  static int? _extractAmount(String text) {
    final matches = _currencyAmountRegex.allMatches(text);
    for (final m in matches) {
      final rawInteger = m.group(1) ?? '';
      final digits = rawInteger.replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(digits);
      if (parsed != null && parsed >= 500) {
        return parsed;
      }
    }
    return null;
  }

  static String _extractMerchant({
    required String title,
    required String body,
    required TransactionKind kind,
    required String sourceName,
  }) {
    final cleanBody = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final patterns = kind == TransactionKind.income
        ? <RegExp>[
            RegExp(r'\bdari\s+([^.,;!\n]+)', caseSensitive: false),
            RegExp(r'\bfrom\s+([^.,;!\n]+)', caseSensitive: false),
          ]
        : <RegExp>[
            RegExp(r'\bmerchant\s*[:\-]?\s*([^.,;!\n]+)', caseSensitive: false),
            RegExp(r'\b(?:ke|di|pada|to|at)\s+([^.,;!\n]+)', caseSensitive: false),
          ];

    for (final regex in patterns) {
      final match = regex.firstMatch(cleanBody);
      if (match == null) {
        continue;
      }
      var candidate = (match.group(1) ?? '').trim();
      candidate = candidate.replaceAll(
        RegExp(
          r'\b(berhasil|sukses|menggunakan|pakai|via|dengan|dari\s+kantong|'
          r'sebesar|senilai|pada\s+tanggal|menggunakan\s+qris|qris|dana|gopay|'
          r'seabank|bank\s+jago|ovo|shopeepay)\b.*$',
          caseSensitive: false,
        ),
        '',
      );
      candidate = candidate
          .replaceAll(RegExp(r'^[\s:\-]+|[\s:\-]+$'), '')
          .trim();
      if (candidate.length >= 2 &&
          candidate.toLowerCase() != sourceName.toLowerCase() &&
          !RegExp(r'^(rekening|saldo|akun|kantong)\b', caseSensitive: false)
              .hasMatch(candidate)) {
        return candidate.length > 42 ? candidate.substring(0, 42).trim() : candidate;
      }
    }

    final cleanTitle = title
        .replaceAll(
          RegExp(
            r'\b(pembayaran|transaksi|transfer|qris|berhasil|sukses|masuk|keluar|gopay|dana|seabank|bank\s+jago)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanTitle.length >= 3) {
      return cleanTitle;
    }
    return '';
  }

  static String _inferCategory({
    required TransactionKind kind,
    required String merchant,
    required String combinedText,
  }) {
    final hay = '${merchant.toLowerCase()} ${combinedText.toLowerCase()}';
    if (kind == TransactionKind.income) {
      if (RegExp(r'\b(gaji|payroll|salary)\b').hasMatch(hay)) {
        return 'Gaji';
      }
      if (RegExp(r'\b(bonus|thr)\b').hasMatch(hay)) {
        return 'Bonus & THR';
      }
      if (RegExp(r'\b(bunga|dividen|invest|bibit|stockbit|reksadana)\b')
          .hasMatch(hay)) {
        return 'Investasi & Bunga';
      }
      if (RegExp(r'\b(cashback|refund|pengembalian)\b').hasMatch(hay)) {
        return 'Cashback & Refund';
      }
      return 'Pemasukan Lain';
    }

    if (RegExp(
      r'\b(kopi|coffee|kenangan|fore|starbucks|janji\s+jiwa|point\s+coffee|'
      r'tomoro|tuku|chatime|mixue|haus|boba|cafe|kafe|jajan|snack|bakery|roti)\b',
    ).hasMatch(hay)) {
      return 'Ngopi';
    }
    if (RegExp(
      r'\b(makan|resto|restoran|warung|warteg|gacoan|solaria|kfc|mcd|'
      r'mcdonald|hokben|burger|pizza|bakso|mie|soto|sate|ayam|padang|sushi|'
      r'gofood|grabfood|shopeefood|kantin|kuliner)\b',
    ).hasMatch(hay)) {
      return 'Makan & Minum';
    }
    if (RegExp(
      r'\b(pertamina|shell|bp\s+akr|spbu|bensin|bbm|grab|goride|gocar|'
      r'maxim|bluebird|parkir|tol|kai|kereta|mrt|lrt|transjakarta|tiket)\b',
    ).hasMatch(hay)) {
      return 'Transportasi';
    }
    if (RegExp(
      r'\b(pln|listrik|pdam|indihome|biznet|myrepublic|wifi|internet|'
      r'telkomsel|indosat|xl|tri|smartfren|pulsa|paket\s+data|bpjs|tagihan|iuran)\b',
    ).hasMatch(hay)) {
      return 'Tagihan & Utilitas';
    }
    if (RegExp(
      r'\b(indomaret|alfamart|alfamidi|superindo|hypermart|transmart|hero|'
      r'lotte|guardian|watsons|sociolla|uniqlo|zara|tokopedia|shopee|blibli|'
      r'lazada|minimarket|mart|store|mall|belanja)\b',
    ).hasMatch(hay)) {
      return 'Belanja';
    }
    if (RegExp(
      r'\b(apotek|kimia\s+farma|k24|halodoc|klinik|rumah\s+sakit|rs\b|dokter|obat)\b',
    ).hasMatch(hay)) {
      return 'Kesehatan';
    }
    if (RegExp(
      r'\b(xxi|cgv|cinepolis|bioskop|netflix|spotify|youtube|steam|game|karaoke|konser)\b',
    ).hasMatch(hay)) {
      return 'Hiburan';
    }
    return 'Lainnya';
  }
}

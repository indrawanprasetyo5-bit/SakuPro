import '../models/transaction_item.dart';
import '../models/wallet.dart';

class ParsedQuickInput {
  const ParsedQuickInput({
    required this.rawText,
    required this.kind,
    required this.amount,
    required this.category,
    required this.note,
    required this.wallet,
    this.toWallet,
    required this.hasExplicitAmount,
    required this.hasExplicitWallet,
    required this.hasExplicitCategory,
  });

  final String rawText;
  final TransactionKind kind;
  final int? amount;
  final String category;
  final String note;
  final WalletModel? wallet;
  final WalletModel? toWallet;
  final bool hasExplicitAmount;
  final bool hasExplicitWallet;
  final bool hasExplicitCategory;

  bool get isReadyToSave {
    if (amount == null || amount! <= 0 || wallet == null) {
      return false;
    }
    if (kind == TransactionKind.transfer) {
      return toWallet != null && toWallet!.id != wallet!.id;
    }
    return true;
  }
}

class QuickInputParser {
  QuickInputParser._();

  static final RegExp _amountWithUnitPattern = RegExp(
    r'(?:rp\.?\s*)?(\d+(?:[.,]\d+)?)\s*(juta|jt|ribu|rb|k|m)\b',
    caseSensitive: false,
  );

  static final RegExp _plainAmountPattern = RegExp(
    r'(?:rp\.?\s*)?(\d{1,3}(?:\.\d{3})+|\d{3,})\b',
    caseSensitive: false,
  );

  static const Map<String, List<String>> _incomeRules = <String, List<String>>{
    'Gaji': <String>['gaji', 'upah', 'payroll', 'salary', 'honor'],
    'Bonus & THR': <String>['bonus', 'thr', 'insentif', 'hadiah', 'angpao'],
    'Bisnis & Freelance': <String>[
      'freelance',
      'proyek',
      'project',
      'klien',
      'omzet',
      'penjualan',
      'jualan',
      'komisi',
      'fee',
    ],
    'Investasi & Bunga': <String>[
      'dividen',
      'bunga',
      'kupon',
      'cuan',
      'profit',
      'reksadana',
      'deposito',
    ],
    'Cashback & Refund': <String>['cashback', 'refund', 'kembalian'],
    'Pemasukan Lain': <String>[
      'pemasukan',
      'uang masuk',
      'kiriman',
      'dikirim',
      'terima',
    ],
  };

  static const Map<String, List<String>> _expenseRules = <String, List<String>>{
    'Ngopi': <String>[
      'kopi',
      'ngopi',
      'boba',
      'kafe',
      'cafe',
      'latte',
      'espresso',
      'americano',
      'matcha',
    ],
    'Makan & Minum': <String>[
      'makan',
      'sarapan',
      'siang',
      'malam',
      'jajan',
      'minum',
      'teh',
      'bakso',
      'mie',
      'nasi',
      'ayam',
      'sate',
      'warteg',
      'resto',
      'gofood',
      'grabfood',
      'shopeefood',
      'roti',
      'cemilan',
      'snack',
      'susu',
    ],
    'Transportasi': <String>[
      'bensin',
      'pertalite',
      'pertamax',
      'shell',
      'solar',
      'parkir',
      'tol',
      'etoll',
      'gojek',
      'goride',
      'gocar',
      'grab',
      'maxim',
      'ojek',
      'krl',
      'mrt',
      'lrt',
      'kereta',
      'bus',
      'transjakarta',
      'tiket',
      'oli',
      'servis',
      'tambal',
    ],
    'Belanja': <String>[
      'belanja',
      'indomaret',
      'alfamart',
      'supermarket',
      'pasar',
      'shopee',
      'tokopedia',
      'lazada',
      'baju',
      'celana',
      'sepatu',
      'sabun',
      'shampo',
      'skincare',
      'galon',
      'gas',
      'kebutuhan',
    ],
    'Tagihan & Utilitas': <String>[
      'listrik',
      'pln',
      'token',
      'air',
      'pdam',
      'wifi',
      'internet',
      'indihome',
      'biznet',
      'pulsa',
      'kuota',
      'paket data',
      'bpjs',
      'pajak',
      'ipl',
      'kos',
      'kontrakan',
      'sewa',
      'tagihan',
    ],
    'Hiburan': <String>[
      'nonton',
      'bioskop',
      'netflix',
      'spotify',
      'youtube',
      'game',
      'voucher',
      'liburan',
      'hotel',
      'wisata',
      'hobi',
      'konser',
    ],
    'Kesehatan': <String>[
      'obat',
      'apotek',
      'dokter',
      'klinik',
      'vitamin',
      'gym',
      'olahraga',
      'gigi',
      'medis',
    ],
    'Pendidikan & Kerja': <String>[
      'buku',
      'kursus',
      'kelas',
      'seminar',
      'ujian',
      'print',
      'fotokopi',
      'domain',
      'hosting',
      'langganan kerja',
    ],
    'Keluarga & Sosial': <String>[
      'sedekah',
      'infaq',
      'zakat',
      'donasi',
      'kondangan',
      'kado',
      'ortu',
      'orang tua',
      'anak',
    ],
  };

  static const Set<String> _transferKeywords = <String>{
    'transfer',
    'tf',
    'pindah',
    'mutasi',
    'topup',
  };

  static const Map<String, String> _walletAliases = <String, String>{
    'tunai': 'cash',
    'dompet': 'cash',
    'uang tunai': 'cash',
    'rekening': 'bca',
    'celengan': 'tabungan',
    'simpanan': 'tabungan',
  };

  static ParsedQuickInput parse(String input, List<WalletModel> wallets) {
    final trimmed = input.trim();
    final fallbackWallet = wallets.isNotEmpty ? wallets.first : null;

    if (trimmed.isEmpty) {
      return ParsedQuickInput(
        rawText: '',
        kind: TransactionKind.expense,
        amount: null,
        category: 'Lainnya',
        note: '',
        wallet: fallbackWallet,
        hasExplicitAmount: false,
        hasExplicitWallet: false,
        hasExplicitCategory: false,
      );
    }

    String working = trimmed;
    int? parsedAmount;
    bool explicitAmount = false;

    final unitMatch = _amountWithUnitPattern.firstMatch(working);
    if (unitMatch != null) {
      final rawNum = unitMatch.group(1)!.replaceAll(',', '.');
      final unit = unitMatch.group(2)!.toLowerCase();
      final value = double.tryParse(rawNum);
      if (value != null) {
        final multiplier = (unit == 'jt' || unit == 'juta' || unit == 'm')
            ? 1000000
            : 1000;
        parsedAmount = (value * multiplier).round();
        explicitAmount = true;
        working = working.replaceRange(unitMatch.start, unitMatch.end, ' ');
      }
    } else {
      final plainMatch = _plainAmountPattern.firstMatch(working);
      if (plainMatch != null) {
        final digitsOnly = plainMatch.group(1)!.replaceAll('.', '');
        final value = int.tryParse(digitsOnly);
        if (value != null && value > 0) {
          parsedAmount = value;
          explicitAmount = true;
          working = working.replaceRange(plainMatch.start, plainMatch.end, ' ');
        }
      }
    }

    final lowerWorking = working.toLowerCase();
    final words = lowerWorking
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final isTransfer = words.any(_transferKeywords.contains) ||
        lowerWorking.contains('top up');

    final matchedWallets = _extractWallets(working, wallets);
    WalletModel? sourceWallet;
    WalletModel? targetWallet;
    bool explicitWallet = false;

    if (matchedWallets.isNotEmpty) {
      sourceWallet = matchedWallets.first.wallet;
      explicitWallet = true;
      if (matchedWallets.length >= 2) {
        targetWallet = matchedWallets[1].wallet;
      }
      // Remove matched spans from right to left so indices stay valid.
      final spans = List<_WalletMatch>.from(matchedWallets)
        ..sort((a, b) => b.start.compareTo(a.start));
      for (final match in spans) {
        working = working.replaceRange(match.start, match.end, ' ');
      }
    } else {
      sourceWallet = fallbackWallet;
    }

    if (isTransfer) {
      targetWallet ??= wallets
          .where((w) => w.id != sourceWallet?.id)
          .cast<WalletModel?>()
          .firstWhere((w) => w != null, orElse: () => null);

      final cleanedNote = _cleanNote(
        working,
        stripWords: const <String>{
          'transfer',
          'tf',
          'pindah',
          'mutasi',
          'dari',
          'ke',
          'top',
          'up',
          'topup',
        },
      );

      return ParsedQuickInput(
        rawText: trimmed,
        kind: TransactionKind.transfer,
        amount: parsedAmount,
        category: 'Transfer Dompet',
        note: cleanedNote.isEmpty ? 'Transfer antar dompet' : cleanedNote,
        wallet: sourceWallet,
        toWallet: targetWallet,
        hasExplicitAmount: explicitAmount,
        hasExplicitWallet: explicitWallet,
        hasExplicitCategory: true,
      );
    }

    final cleanTextLower = working.toLowerCase();

    for (final entry in _incomeRules.entries) {
      for (final keyword in entry.value) {
        if (_containsKeyword(cleanTextLower, keyword)) {
          final note = _cleanNote(working);
          return ParsedQuickInput(
            rawText: trimmed,
            kind: TransactionKind.income,
            amount: parsedAmount,
            category: entry.key,
            note: note.isEmpty ? entry.key : note,
            wallet: sourceWallet,
            hasExplicitAmount: explicitAmount,
            hasExplicitWallet: explicitWallet,
            hasExplicitCategory: true,
          );
        }
      }
    }

    for (final entry in _expenseRules.entries) {
      for (final keyword in entry.value) {
        if (_containsKeyword(cleanTextLower, keyword)) {
          final note = _cleanNote(working);
          return ParsedQuickInput(
            rawText: trimmed,
            kind: TransactionKind.expense,
            amount: parsedAmount,
            category: entry.key,
            note: note.isEmpty ? entry.key : note,
            wallet: sourceWallet,
            hasExplicitAmount: explicitAmount,
            hasExplicitWallet: explicitWallet,
            hasExplicitCategory: true,
          );
        }
      }
    }

    final fallbackNote = _cleanNote(working);
    return ParsedQuickInput(
      rawText: trimmed,
      kind: TransactionKind.expense,
      amount: parsedAmount,
      category: 'Lainnya',
      note: fallbackNote,
      wallet: sourceWallet,
      hasExplicitAmount: explicitAmount,
      hasExplicitWallet: explicitWallet,
      hasExplicitCategory: false,
    );
  }

  static bool _containsKeyword(String text, String keyword) {
    final pattern = RegExp(
      '(^|\\s|[^a-z0-9])${RegExp.escape(keyword)}(\$|\\s|[^a-z0-9])',
      caseSensitive: false,
    );
    return pattern.hasMatch(text);
  }

  static List<_WalletMatch> _extractWallets(
    String text,
    List<WalletModel> wallets,
  ) {
    final candidates = <_WalletCandidate>[];
    for (final wallet in wallets) {
      candidates.add(
        _WalletCandidate(token: wallet.name.toLowerCase(), wallet: wallet),
      );
    }
    for (final alias in _walletAliases.entries) {
      final matched = wallets
          .where((w) => w.name.toLowerCase() == alias.value)
          .cast<WalletModel?>()
          .firstWhere((w) => w != null, orElse: () => null);
      if (matched != null) {
        candidates.add(_WalletCandidate(token: alias.key, wallet: matched));
      }
    }
    candidates.sort((a, b) => b.token.length.compareTo(a.token.length));

    final matches = <_WalletMatch>[];
    for (final candidate in candidates) {
      if (candidate.token.isEmpty) {
        continue;
      }
      final regex = RegExp(
        '(^|\\s)(${RegExp.escape(candidate.token)})(?=\\s|\$)',
        caseSensitive: false,
      );
      for (final m in regex.allMatches(text)) {
        final tokenStart = m.start + (m.group(1)?.length ?? 0);
        final tokenEnd = m.end;
        final overlaps = matches.any(
          (existing) => tokenStart < existing.end && tokenEnd > existing.start,
        );
        if (!overlaps) {
          matches.add(
            _WalletMatch(
              wallet: candidate.wallet,
              start: tokenStart,
              end: tokenEnd,
            ),
          );
        }
      }
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    return matches;
  }

  static String _cleanNote(
    String raw, {
    Set<String> stripWords = const <String>{'pakai', 'via', 'di', 'pake'},
  }) {
    final tokens = raw
        .replaceAll(RegExp(r'[,:;]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    while (tokens.isNotEmpty &&
        stripWords.contains(tokens.last.toLowerCase())) {
      tokens.removeLast();
    }
    while (tokens.isNotEmpty &&
        stripWords.contains(tokens.first.toLowerCase())) {
      tokens.removeAt(0);
    }

    if (tokens.isEmpty) {
      return '';
    }

    final joined = tokens.join(' ');
    return '${joined[0].toUpperCase()}${joined.substring(1)}';
  }
}

class _WalletCandidate {
  const _WalletCandidate({required this.token, required this.wallet});
  final String token;
  final WalletModel wallet;
}

class _WalletMatch {
  const _WalletMatch({
    required this.wallet,
    required this.start,
    required this.end,
  });
  final WalletModel wallet;
  final int start;
  final int end;
}

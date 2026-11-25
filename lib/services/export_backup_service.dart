import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction_item.dart';
import '../models/wallet.dart';
import 'file_saver_io.dart'
    if (dart.library.js_interop) 'file_saver_web.dart';

class ExportBackupService {
  ExportBackupService._();

  static const List<String> _monthNames = <String>[
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static Uint8List buildMonthlyExcelBytes({
    required DateTime month,
    required List<TransactionModel> monthTransactions,
    required List<WalletModel> wallets,
    required int netWorth,
  }) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    const reportSheetName = 'Laporan Bulanan';
    if (defaultSheet != null && defaultSheet != reportSheetName) {
      excel.rename(defaultSheet, reportSheetName);
    }

    final sheet = excel[reportSheetName];
    final monthLabel =
        '${_monthNames[(month.month - 1).clamp(0, 11)]} ${month.year}';

    var totalIncome = 0;
    var totalExpense = 0;
    for (final tx in monthTransactions) {
      if (tx.kind == TransactionKind.income) {
        totalIncome += tx.amount;
      } else if (tx.kind == TransactionKind.expense) {
        totalExpense += tx.amount;
      }
    }

    final walletMap = <int, String>{
      for (final w in wallets)
        if (w.id != null) w.id!: w.name,
    };

    sheet.appendRow(<CellValue>[
      TextCellValue('LAPORAN KEUANGAN SAKUPRO - $monthLabel'),
    ]);
    sheet.appendRow(<CellValue>[
      TextCellValue(
        'Dicetak pada: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
      ),
    ]);
    sheet.appendRow(<CellValue>[TextCellValue('')]);

    sheet.appendRow(<CellValue>[
      TextCellValue('RINGKASAN BULAN INI'),
      TextCellValue('NOMINAL (RP)'),
    ]);
    sheet.appendRow(<CellValue>[
      TextCellValue('Total Pemasukan'),
      IntCellValue(totalIncome),
    ]);
    sheet.appendRow(<CellValue>[
      TextCellValue('Total Pengeluaran'),
      IntCellValue(totalExpense),
    ]);
    sheet.appendRow(<CellValue>[
      TextCellValue('Arus Kas Bersih'),
      IntCellValue(totalIncome - totalExpense),
    ]);
    sheet.appendRow(<CellValue>[
      TextCellValue('Saldo Akhir Bersih Seluruh Dompet'),
      IntCellValue(netWorth),
    ]);
    sheet.appendRow(<CellValue>[TextCellValue('')]);

    sheet.appendRow(<CellValue>[
      TextCellValue('SALDO DOMPET'),
      TextCellValue('TIPE'),
      TextCellValue('SALDO AKHIR (RP)'),
    ]);
    for (final wallet in wallets) {
      sheet.appendRow(<CellValue>[
        TextCellValue(wallet.name),
        TextCellValue(wallet.kind.label),
        IntCellValue(wallet.balance),
      ]);
    }
    sheet.appendRow(<CellValue>[TextCellValue('')]);

    sheet.appendRow(<CellValue>[
      TextCellValue('TANGGAL'),
      TextCellValue('TIPE'),
      TextCellValue('KATEGORI'),
      TextCellValue('CATATAN'),
      TextCellValue('DOMPET'),
      TextCellValue('NOMINAL (RP)'),
    ]);

    final sortedTx = List<TransactionModel>.from(monthTransactions)
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

    for (final tx in sortedTx) {
      final fromName = walletMap[tx.walletId] ?? 'Dompet';
      final toName = tx.toWalletId != null ? walletMap[tx.toWalletId!] : null;
      final walletDesc = tx.kind == TransactionKind.transfer && toName != null
          ? '$fromName -> $toName'
          : fromName;

      final signedVal = tx.kind == TransactionKind.expense
          ? -tx.amount
          : tx.amount;

      sheet.appendRow(<CellValue>[
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(tx.transactionDate)),
        TextCellValue(tx.kind.label),
        TextCellValue(tx.category),
        TextCellValue(tx.displayTitle),
        TextCellValue(walletDesc),
        IntCellValue(signedVal),
      ]);
    }

    final encoded = excel.encode();
    return Uint8List.fromList(encoded ?? const <int>[]);
  }

  static Future<void> shareMonthlyExcel({
    required DateTime month,
    required List<TransactionModel> monthTransactions,
    required List<WalletModel> wallets,
    required int netWorth,
  }) async {
    final bytes = buildMonthlyExcelBytes(
      month: month,
      monthTransactions: monthTransactions,
      wallets: wallets,
      netWorth: netWorth,
    );
    final ym =
        '${month.year}${month.month.toString().padLeft(2, '0')}';
    final fileName = 'SakuPro_Laporan_$ym.xlsx';
    final xFile = await createShareableTempFile(
      bytes: bytes,
      fileName: fileName,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    await Share.shareXFiles(
      <XFile>[xFile],
      subject: 'Laporan Keuangan SakuPro $ym',
      text: 'Laporan transaksi bulanan SakuPro ($ym)',
    );
  }

  static String encodeBackupJson(Map<String, Object?> snapshot) {
    return const JsonEncoder.withIndent('  ').convert(snapshot);
  }

  static Map<String, Object?> decodeAndValidateBackupJson(String rawJson) {
    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('Format JSON backup tidak valid.');
    }
    final map = Map<String, Object?>.from(decoded);
    if (map['app'] != 'saku_pro' || map['wallets'] is! List) {
      throw const FormatException(
        'Data bukan berkas backup SakuPro yang sah.',
      );
    }
    return map;
  }

  static Future<void> shareBackupJsonFile(Map<String, Object?> snapshot) async {
    final jsonString = encodeBackupJson(snapshot);
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fileName = 'SakuPro_Backup_$stamp.json';
    final xFile = await createShareableTempFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'application/json',
    );
    await Share.shareXFiles(
      <XFile>[xFile],
      subject: 'Backup Data SakuPro',
      text: 'Cadangan data lokal SakuPro ($stamp)',
    );
  }
}

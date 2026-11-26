import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/roadmap_models.dart';
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

  static const String _sheetSummary = 'Ringkasan Eksekutif';
  static const String _sheetLedger = 'Buku Transaksi';
  static const String _sheetCategory = 'Analisa Kategori & Budget';
  static const String _sheetWallets = 'Dompet & Aset';
  static const String _sheetPlan = 'Rencana & Kewajiban';

  static final ExcelColor _brandDark = ExcelColor.fromHexString('FF0B3B36');
  static final ExcelColor _brandPrimary = ExcelColor.fromHexString('FF0F766E');
  static final ExcelColor _brandSoft = ExcelColor.fromHexString('FFE6F4F1');
  static final ExcelColor _goldAccent = ExcelColor.fromHexString('FFC59D47');
  static final ExcelColor _goldSoft = ExcelColor.fromHexString('FFFDF6E7');
  static final ExcelColor _zebraRow = ExcelColor.fromHexString('FFF8FAFC');
  static final ExcelColor _white = ExcelColor.fromHexString('FFFFFFFF');
  static final ExcelColor _inkPrimary = ExcelColor.fromHexString('FF0F172A');
  static final ExcelColor _inkMuted = ExcelColor.fromHexString('FF475569');
  static final ExcelColor _borderLight = ExcelColor.fromHexString('FFDCE4EC');
  static final ExcelColor _borderStrong = ExcelColor.fromHexString('FF0F766E');

  static final ExcelColor _incomeInk = ExcelColor.fromHexString('FF047857');
  static final ExcelColor _incomeBg = ExcelColor.fromHexString('FFECFDF5');
  static final ExcelColor _expenseInk = ExcelColor.fromHexString('FFBE123C');
  static final ExcelColor _expenseBg = ExcelColor.fromHexString('FFFFF1F2');
  static final ExcelColor _warningInk = ExcelColor.fromHexString('FFB45309');
  static final ExcelColor _warningBg = ExcelColor.fromHexString('FFFFFBEB');
  static final ExcelColor _transferInk = ExcelColor.fromHexString('FF1D4ED8');
  static final ExcelColor _transferBg = ExcelColor.fromHexString('FFEFF6FF');

  static final NumFormat _idrFormat = NumFormat.custom(
    formatCode: '"Rp "#,##0;-"Rp "#,##0;"Rp "0',
  );
  static final NumFormat _signedIdrFormat = NumFormat.custom(
    formatCode: '+"Rp "#,##0;-"Rp "#,##0;"Rp "0',
  );
  static final NumFormat _percentFormat = NumFormat.custom(
    formatCode: '0.0%',
  );
  static final NumFormat _intFormat = NumFormat.custom(formatCode: '#,##0');

  static Border _thinBorder([ExcelColor? color]) => Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: color ?? _borderLight,
  );

  static Border _mediumBorder(ExcelColor color) => Border(
    borderStyle: BorderStyle.Medium,
    borderColorHex: color,
  );

  static Border _doubleBorder(ExcelColor color) => Border(
    borderStyle: BorderStyle.Double,
    borderColorHex: color,
  );

  static CellStyle _titleBannerStyle() => CellStyle(
    fontFamily: 'Calibri',
    fontSize: 15,
    bold: true,
    fontColorHex: _white,
    backgroundColorHex: _brandDark,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    bottomBorder: _mediumBorder(_goldAccent),
  );

  static CellStyle _subtitleStripStyle() => CellStyle(
    fontFamily: 'Calibri',
    fontSize: 10,
    italic: true,
    fontColorHex: _inkMuted,
    backgroundColorHex: _goldSoft,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    bottomBorder: _thinBorder(_goldAccent),
  );

  static CellStyle _sectionTitleStyle() => CellStyle(
    fontFamily: 'Calibri',
    fontSize: 11,
    bold: true,
    fontColorHex: _brandDark,
    backgroundColorHex: _brandSoft,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _mediumBorder(_brandPrimary),
    topBorder: _thinBorder(_borderLight),
    bottomBorder: _thinBorder(_brandPrimary),
    rightBorder: _thinBorder(_borderLight),
  );

  static CellStyle _tableHeaderStyle({
    HorizontalAlign align = HorizontalAlign.Left,
  }) => CellStyle(
    fontFamily: 'Calibri',
    fontSize: 10,
    bold: true,
    fontColorHex: _white,
    backgroundColorHex: _brandPrimary,
    horizontalAlign: align,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _thinBorder(_brandDark),
    rightBorder: _thinBorder(_brandDark),
    topBorder: _thinBorder(_brandDark),
    bottomBorder: _mediumBorder(_goldAccent),
  );

  static CellStyle _dataStyle({
    bool zebra = false,
    bool bold = false,
    HorizontalAlign align = HorizontalAlign.Left,
    ExcelColor? fontColor,
    ExcelColor? bgColor,
    NumFormat numberFormat = NumFormat.standard_0,
    bool wrap = false,
  }) => CellStyle(
    fontFamily: 'Calibri',
    fontSize: 10,
    bold: bold,
    fontColorHex: fontColor ?? _inkPrimary,
    backgroundColorHex: bgColor ?? (zebra ? _zebraRow : _white),
    horizontalAlign: align,
    verticalAlign: VerticalAlign.Center,
    textWrapping: wrap ? TextWrapping.WrapText : null,
    numberFormat: numberFormat,
    leftBorder: _thinBorder(),
    rightBorder: _thinBorder(),
    topBorder: _thinBorder(),
    bottomBorder: _thinBorder(),
  );

  static CellStyle _totalRowStyle({
    HorizontalAlign align = HorizontalAlign.Left,
    ExcelColor? fontColor,
    NumFormat numberFormat = NumFormat.standard_0,
  }) => CellStyle(
    fontFamily: 'Calibri',
    fontSize: 10,
    bold: true,
    fontColorHex: fontColor ?? _brandDark,
    backgroundColorHex: _goldSoft,
    horizontalAlign: align,
    verticalAlign: VerticalAlign.Center,
    numberFormat: numberFormat,
    leftBorder: _thinBorder(_borderLight),
    rightBorder: _thinBorder(_borderLight),
    topBorder: _mediumBorder(_borderStrong),
    bottomBorder: _doubleBorder(_borderStrong),
  );

  static void _writeCell(
    Sheet sheet,
    int col,
    int row,
    CellValue value,
    CellStyle style,
  ) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = value;
    cell.cellStyle = style;
  }

  static void _writeMergedBanner(
    Sheet sheet, {
    required int row,
    required int startCol,
    required int endCol,
    required String text,
    required CellStyle style,
    double? rowHeight,
  }) {
    final start = CellIndex.indexByColumnRow(
      columnIndex: startCol,
      rowIndex: row,
    );
    final end = CellIndex.indexByColumnRow(columnIndex: endCol, rowIndex: row);
    sheet.merge(start, end, customValue: TextCellValue(text));
    for (var c = startCol; c <= endCol; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
          .cellStyle = style;
    }
    if (rowHeight != null) {
      sheet.setRowHeight(row, rowHeight);
    }
  }

  static int _r(int zeroBasedRow) => zeroBasedRow + 1;

  static int _daysInMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  static String _visualBar(double ratio) {
    const slots = 10;
    final filled = (ratio.clamp(0.0, 1.0) * slots).round();
    final empty = slots - filled;
    return '${'█' * filled}${'░' * empty}';
  }

  static Uint8List buildMonthlyExcelBytes({
    required DateTime month,
    required List<TransactionModel> monthTransactions,
    required List<WalletModel> wallets,
    required int netWorth,
    int monthlyBudget = 0,
    List<BudgetModel> categoryBudgets = const <BudgetModel>[],
    List<GoalModel> goals = const <GoalModel>[],
    List<BillModel> bills = const <BillModel>[],
    List<DebtModel> debts = const <DebtModel>[],
    int previousMonthExpense = 0,
    List<String> insights = const <String>[],
  }) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != _sheetSummary) {
      excel.rename(defaultSheet, _sheetSummary);
    }

    final summarySheet = excel[_sheetSummary];
    final ledgerSheet = excel[_sheetLedger];
    final categorySheet = excel[_sheetCategory];
    final walletSheet = excel[_sheetWallets];
    final planSheet = excel[_sheetPlan];

    final monthLabel =
        '${_monthNames[(month.month - 1).clamp(0, 11)]} ${month.year}';
    final printedAt = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());
    final subtitleText =
        'Periode: $monthLabel   |   Dicetak: $printedAt   |   Mata Uang: IDR (Rp)';

    final sortedTx = List<TransactionModel>.from(monthTransactions)
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

    final walletMap = <int, String>{
      for (final w in wallets)
        if (w.id != null) w.id!: w.name,
    };

    var totalIncome = 0;
    var totalExpense = 0;
    var transferCount = 0;
    final expenseByCategory = <String, int>{};
    final countByCategory = <String, int>{};
    final txCountByWallet = <int, int>{};

    for (final tx in sortedTx) {
      txCountByWallet[tx.walletId] = (txCountByWallet[tx.walletId] ?? 0) + 1;
      if (tx.toWalletId != null) {
        txCountByWallet[tx.toWalletId!] =
            (txCountByWallet[tx.toWalletId!] ?? 0) + 1;
      }
      if (tx.kind == TransactionKind.income) {
        totalIncome += tx.amount;
      } else if (tx.kind == TransactionKind.expense) {
        totalExpense += tx.amount;
        expenseByCategory[tx.category] =
            (expenseByCategory[tx.category] ?? 0) + tx.amount;
        countByCategory[tx.category] = (countByCategory[tx.category] ?? 0) + 1;
      } else {
        transferCount++;
      }
    }

    final ledgerRange = _buildLedgerSheet(
      sheet: ledgerSheet,
      monthLabel: monthLabel,
      subtitleText: subtitleText,
      sortedTx: sortedTx,
      walletMap: walletMap,
    );

    final walletRange = _buildWalletsSheet(
      sheet: walletSheet,
      monthLabel: monthLabel,
      subtitleText: subtitleText,
      wallets: wallets,
      txCountByWallet: txCountByWallet,
    );

    _buildCategoryAndBudgetSheet(
      sheet: categorySheet,
      monthLabel: monthLabel,
      subtitleText: subtitleText,
      expenseByCategory: expenseByCategory,
      countByCategory: countByCategory,
      totalExpense: totalExpense,
      monthlyBudget: monthlyBudget,
      categoryBudgets: categoryBudgets,
    );

    _buildPlanAndObligationsSheet(
      sheet: planSheet,
      month: month,
      monthLabel: monthLabel,
      subtitleText: subtitleText,
      goals: goals,
      bills: bills,
      debts: debts,
      totalAllWallets: wallets.fold<int>(0, (sum, w) => sum + w.balance),
    );

    _buildExecutiveSummarySheet(
      sheet: summarySheet,
      month: month,
      monthLabel: monthLabel,
      subtitleText: subtitleText,
      sortedTx: sortedTx,
      walletMap: walletMap,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      transferCount: transferCount,
      netWorth: netWorth,
      monthlyBudget: monthlyBudget,
      previousMonthExpense: previousMonthExpense,
      insights: insights,
      ledgerStartRow: ledgerRange.$1,
      ledgerEndRow: ledgerRange.$2,
      walletStartRow: walletRange.$1,
      walletEndRow: walletRange.$2,
    );

    excel.setDefaultSheet(_sheetSummary);

    final encoded = excel.encode();
    return Uint8List.fromList(encoded ?? const <int>[]);
  }

  static (int, int) _buildLedgerSheet({
    required Sheet sheet,
    required String monthLabel,
    required String subtitleText,
    required List<TransactionModel> sortedTx,
    required Map<int, String> walletMap,
  }) {
    _writeMergedBanner(
      sheet,
      row: 0,
      startCol: 0,
      endCol: 9,
      text: 'SAKUPROWANN  |  BUKU TRANSAKSI HARIAN ($monthLabel)',
      style: _titleBannerStyle(),
      rowHeight: 32,
    );
    _writeMergedBanner(
      sheet,
      row: 1,
      startCol: 0,
      endCol: 9,
      text: subtitleText,
      style: _subtitleStripStyle(),
      rowHeight: 21,
    );
    sheet.setRowHeight(2, 10);

    const headerRow = 3;
    sheet.setRowHeight(headerRow, 26);
    final headers = <(String, HorizontalAlign)>[
      ('No', HorizontalAlign.Center),
      ('Tanggal', HorizontalAlign.Center),
      ('Jam', HorizontalAlign.Center),
      ('Tipe', HorizontalAlign.Center),
      ('Kategori', HorizontalAlign.Left),
      ('Keterangan / Catatan', HorizontalAlign.Left),
      ('Dompet / Tujuan', HorizontalAlign.Left),
      ('Pemasukan (Rp)', HorizontalAlign.Right),
      ('Pengeluaran (Rp)', HorizontalAlign.Right),
      ('Arus Bersih (Rp)', HorizontalAlign.Right),
    ];
    for (var i = 0; i < headers.length; i++) {
      _writeCell(
        sheet,
        i,
        headerRow,
        TextCellValue(headers[i].$1),
        _tableHeaderStyle(align: headers[i].$2),
      );
    }

    const dataStartRow = 4;
    if (sortedTx.isEmpty) {
      _writeMergedBanner(
        sheet,
        row: dataStartRow,
        startCol: 0,
        endCol: 9,
        text: 'Belum ada transaksi tercatat pada periode $monthLabel.',
        style: _dataStyle(
          align: HorizontalAlign.Center,
          fontColor: _inkMuted,
        ),
        rowHeight: 26,
      );
      _setLedgerColumnWidths(sheet);
      return (-1, -1);
    }

    for (var idx = 0; idx < sortedTx.length; idx++) {
      final tx = sortedTx[idx];
      final row = dataStartRow + idx;
      final zebra = idx.isOdd;
      sheet.setRowHeight(row, 21);

      final fromName = walletMap[tx.walletId] ?? 'Dompet';
      final toName = tx.toWalletId != null ? walletMap[tx.toWalletId!] : null;
      final walletDesc = tx.kind == TransactionKind.transfer && toName != null
          ? '$fromName -> $toName'
          : fromName;

      final incomeVal = tx.kind == TransactionKind.income ? tx.amount : 0;
      final expenseVal = tx.kind == TransactionKind.expense ? tx.amount : 0;

      final (badgeInk, badgeBg) = switch (tx.kind) {
        TransactionKind.income => (_incomeInk, _incomeBg),
        TransactionKind.expense => (_expenseInk, _expenseBg),
        TransactionKind.transfer => (_transferInk, _transferBg),
      };

      _writeCell(
        sheet,
        0,
        row,
        IntCellValue(idx + 1),
        _dataStyle(
          zebra: zebra,
          align: HorizontalAlign.Center,
          numberFormat: _intFormat,
        ),
      );
      _writeCell(
        sheet,
        1,
        row,
        TextCellValue(DateFormat('yyyy-MM-dd').format(tx.transactionDate)),
        _dataStyle(zebra: zebra, align: HorizontalAlign.Center),
      );
      _writeCell(
        sheet,
        2,
        row,
        TextCellValue(DateFormat('HH:mm').format(tx.transactionDate)),
        _dataStyle(
          zebra: zebra,
          align: HorizontalAlign.Center,
          fontColor: _inkMuted,
        ),
      );
      _writeCell(
        sheet,
        3,
        row,
        TextCellValue(tx.kind.label),
        _dataStyle(
          bold: true,
          align: HorizontalAlign.Center,
          fontColor: badgeInk,
          bgColor: badgeBg,
        ),
      );
      _writeCell(
        sheet,
        4,
        row,
        TextCellValue(tx.category),
        _dataStyle(zebra: zebra),
      );
      _writeCell(
        sheet,
        5,
        row,
        TextCellValue(tx.displayTitle),
        _dataStyle(zebra: zebra, wrap: true),
      );
      _writeCell(
        sheet,
        6,
        row,
        TextCellValue(walletDesc),
        _dataStyle(zebra: zebra),
      );
      _writeCell(
        sheet,
        7,
        row,
        IntCellValue(incomeVal),
        _dataStyle(
          zebra: zebra,
          align: HorizontalAlign.Right,
          fontColor: incomeVal > 0 ? _incomeInk : _inkMuted,
          numberFormat: _idrFormat,
        ),
      );
      _writeCell(
        sheet,
        8,
        row,
        IntCellValue(expenseVal),
        _dataStyle(
          zebra: zebra,
          align: HorizontalAlign.Right,
          fontColor: expenseVal > 0 ? _expenseInk : _inkMuted,
          numberFormat: _idrFormat,
        ),
      );
      final excelRowNum = _r(row);
      _writeCell(
        sheet,
        9,
        row,
        FormulaCellValue('H$excelRowNum-I$excelRowNum'),
        _dataStyle(
          zebra: zebra,
          bold: true,
          align: HorizontalAlign.Right,
          fontColor: tx.kind == TransactionKind.income
              ? _incomeInk
              : tx.kind == TransactionKind.expense
              ? _expenseInk
              : _transferInk,
          numberFormat: _signedIdrFormat,
        ),
      );
    }

    final dataEndRow = dataStartRow + sortedTx.length - 1;
    final totalRow = dataEndRow + 1;
    sheet.setRowHeight(totalRow, 25);

    _writeMergedBanner(
      sheet,
      row: totalRow,
      startCol: 0,
      endCol: 6,
      text: 'TOTAL ARUS KAS BULAN INI (${sortedTx.length} TRANSAKSI)',
      style: _totalRowStyle(align: HorizontalAlign.Right),
      rowHeight: 25,
    );
    final startR = _r(dataStartRow);
    final endR = _r(dataEndRow);
    _writeCell(
      sheet,
      7,
      totalRow,
      FormulaCellValue('SUM(H$startR:H$endR)'),
      _totalRowStyle(
        align: HorizontalAlign.Right,
        fontColor: _incomeInk,
        numberFormat: _idrFormat,
      ),
    );
    _writeCell(
      sheet,
      8,
      totalRow,
      FormulaCellValue('SUM(I$startR:I$endR)'),
      _totalRowStyle(
        align: HorizontalAlign.Right,
        fontColor: _expenseInk,
        numberFormat: _idrFormat,
      ),
    );
    _writeCell(
      sheet,
      9,
      totalRow,
      FormulaCellValue('SUM(J$startR:J$endR)'),
      _totalRowStyle(
        align: HorizontalAlign.Right,
        fontColor: _brandDark,
        numberFormat: _signedIdrFormat,
      ),
    );

    _setLedgerColumnWidths(sheet);
    return (startR, endR);
  }

  static void _setLedgerColumnWidths(Sheet sheet) {
    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 13);
    sheet.setColumnWidth(2, 9);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 21);
    sheet.setColumnWidth(5, 32);
    sheet.setColumnWidth(6, 22);
    sheet.setColumnWidth(7, 19);
    sheet.setColumnWidth(8, 19);
    sheet.setColumnWidth(9, 20);
  }

  static (int, int) _buildWalletsSheet({
    required Sheet sheet,
    required String monthLabel,
    required String subtitleText,
    required List<WalletModel> wallets,
    required Map<int, int> txCountByWallet,
  }) {
    _writeMergedBanner(
      sheet,
      row: 0,
      startCol: 0,
      endCol: 6,
      text: 'SAKUPROWANN  |  POSISI DOMPET & ALOKASI ASET ($monthLabel)',
      style: _titleBannerStyle(),
      rowHeight: 32,
    );
    _writeMergedBanner(
      sheet,
      row: 1,
      startCol: 0,
      endCol: 6,
      text: subtitleText,
      style: _subtitleStripStyle(),
      rowHeight: 21,
    );
    sheet.setRowHeight(2, 10);

    const headerRow = 3;
    sheet.setRowHeight(headerRow, 26);
    final headers = <(String, HorizontalAlign)>[
      ('No', HorizontalAlign.Center),
      ('Nama Dompet', HorizontalAlign.Left),
      ('Kategori Dompet', HorizontalAlign.Left),
      ('Masuk Saldo Bersih', HorizontalAlign.Center),
      ('Saldo Akhir (Rp)', HorizontalAlign.Right),
      ('Alokasi (%)', HorizontalAlign.Right),
      ('Aktivitas Bulan Ini', HorizontalAlign.Center),
    ];
    for (var i = 0; i < headers.length; i++) {
      _writeCell(
        sheet,
        i,
        headerRow,
        TextCellValue(headers[i].$1),
        _tableHeaderStyle(align: headers[i].$2),
      );
    }

    const dataStartRow = 4;
    if (wallets.isEmpty) {
      _writeMergedBanner(
        sheet,
        row: dataStartRow,
        startCol: 0,
        endCol: 6,
        text: 'Belum ada dompet terdaftar.',
        style: _dataStyle(align: HorizontalAlign.Center, fontColor: _inkMuted),
        rowHeight: 24,
      );
      _setWalletColumnWidths(sheet);
      return (-1, -1);
    }

    final totalRow = dataStartRow + wallets.length;
    final totalRowExcel = _r(totalRow);

    for (var idx = 0; idx < wallets.length; idx++) {
      final wallet = wallets[idx];
      final row = dataStartRow + idx;
      final zebra = idx.isOdd;
      final rowExcel = _r(row);
      sheet.setRowHeight(row, 22);

      final included = !wallet.excludeFromTotal;
      final txCount = wallet.id != null ? (txCountByWallet[wallet.id!] ?? 0) : 0;

      _writeCell(
        sheet,
        0,
        row,
        IntCellValue(idx + 1),
        _dataStyle(
          zebra: zebra,
          align: HorizontalAlign.Center,
          numberFormat: _intFormat,
        ),
      );
      _writeCell(
        sheet,
        1,
        row,
        TextCellValue(wallet.name),
        _dataStyle(zebra: zebra, bold: true),
      );
      _writeCell(
        sheet,
        2,
        row,
        TextCellValue(wallet.kind.label),
        _dataStyle(zebra: zebra, fontColor: _inkMuted),
      );
      _writeCell(
        sheet,
        3,
        row,
        TextCellValue(included ? 'Ya' : 'Terpisah'),
        _dataStyle(
          bold: true,
          align: HorizontalAlign.Center,
          fontColor: included ? _incomeInk : _warningInk,
          bgColor: included ? _incomeBg : _warningBg,
        ),
      );
      _writeCell(
        sheet,
        4,
        row,
        IntCellValue(wallet.balance),
        _dataStyle(
          zebra: zebra,
          bold: true,
          align: HorizontalAlign.Right,
          fontColor: wallet.balance < 0 ? _expenseInk : _inkPrimary,
          numberFormat: _idrFormat,
        ),
      );
      _writeCell(
        sheet,
        5,
        row,
        FormulaCellValue(
          'IF(E$totalRowExcel>0,E$rowExcel/E$totalRowExcel,0)',
        ),
        _dataStyle(
          zebra: zebra,
          align: HorizontalAlign.Right,
          numberFormat: _percentFormat,
        ),
      );
      _writeCell(
        sheet,
        6,
        row,
        IntCellValue(txCount),
        _dataStyle(
          zebra: zebra,
          align: HorizontalAlign.Center,
          numberFormat: _intFormat,
        ),
      );
    }

    final startR = _r(dataStartRow);
    final endR = _r(dataStartRow + wallets.length - 1);

    _writeMergedBanner(
      sheet,
      row: totalRow,
      startCol: 0,
      endCol: 3,
      text: 'TOTAL SELURUH DOMPET',
      style: _totalRowStyle(align: HorizontalAlign.Right),
      rowHeight: 25,
    );
    _writeCell(
      sheet,
      4,
      totalRow,
      FormulaCellValue('SUM(E$startR:E$endR)'),
      _totalRowStyle(align: HorizontalAlign.Right, numberFormat: _idrFormat),
    );
    _writeCell(
      sheet,
      5,
      totalRow,
      FormulaCellValue('SUM(F$startR:F$endR)'),
      _totalRowStyle(
        align: HorizontalAlign.Right,
        numberFormat: _percentFormat,
      ),
    );
    _writeCell(
      sheet,
      6,
      totalRow,
      FormulaCellValue('SUM(G$startR:G$endR)'),
      _totalRowStyle(align: HorizontalAlign.Center, numberFormat: _intFormat),
    );

    final netRow = totalRow + 2;
    _writeMergedBanner(
      sheet,
      row: netRow,
      startCol: 0,
      endCol: 3,
      text: 'Saldo Bersih Aktif (Tidak Termasuk Dompet Terpisah)',
      style: _dataStyle(bold: true, bgColor: _brandSoft, fontColor: _brandDark),
      rowHeight: 24,
    );
    _writeCell(
      sheet,
      4,
      netRow,
      FormulaCellValue('SUMIF(D$startR:D$endR,"Ya",E$startR:E$endR)'),
      _dataStyle(
        bold: true,
        align: HorizontalAlign.Right,
        bgColor: _brandSoft,
        fontColor: _brandDark,
        numberFormat: _idrFormat,
      ),
    );
    _writeMergedBanner(
      sheet,
      row: netRow,
      startCol: 5,
      endCol: 6,
      text: 'Basis Net Worth Beranda',
      style: _dataStyle(
        align: HorizontalAlign.Center,
        bgColor: _brandSoft,
        fontColor: _inkMuted,
      ),
    );

    _setWalletColumnWidths(sheet);
    return (startR, endR);
  }

  static void _setWalletColumnWidths(Sheet sheet) {
    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 20);
    sheet.setColumnWidth(4, 21);
    sheet.setColumnWidth(5, 14);
    sheet.setColumnWidth(6, 20);
  }

  static void _buildCategoryAndBudgetSheet({
    required Sheet sheet,
    required String monthLabel,
    required String subtitleText,
    required Map<String, int> expenseByCategory,
    required Map<String, int> countByCategory,
    required int totalExpense,
    required int monthlyBudget,
    required List<BudgetModel> categoryBudgets,
  }) {
    _writeMergedBanner(
      sheet,
      row: 0,
      startCol: 0,
      endCol: 5,
      text: 'SAKUPROWANN  |  ANALISA KATEGORI & REALISASI BUDGET ($monthLabel)',
      style: _titleBannerStyle(),
      rowHeight: 32,
    );
    _writeMergedBanner(
      sheet,
      row: 1,
      startCol: 0,
      endCol: 5,
      text: subtitleText,
      style: _subtitleStripStyle(),
      rowHeight: 21,
    );
    sheet.setRowHeight(2, 10);

    var cursor = 3;
    _writeMergedBanner(
      sheet,
      row: cursor,
      startCol: 0,
      endCol: 5,
      text: 'A. KOMPOSISI PENGELUARAN PER KATEGORI',
      style: _sectionTitleStyle(),
      rowHeight: 24,
    );
    cursor++;

    sheet.setRowHeight(cursor, 25);
    final catHeaders = <(String, HorizontalAlign)>[
      ('Kategori Pengeluaran', HorizontalAlign.Left),
      ('Jumlah Tx', HorizontalAlign.Center),
      ('Total Pengeluaran (Rp)', HorizontalAlign.Right),
      ('Porsi (%)', HorizontalAlign.Right),
      ('Rata-rata / Tx (Rp)', HorizontalAlign.Right),
      ('Distribusi Visual', HorizontalAlign.Left),
    ];
    for (var i = 0; i < catHeaders.length; i++) {
      _writeCell(
        sheet,
        i,
        cursor,
        TextCellValue(catHeaders[i].$1),
        _tableHeaderStyle(align: catHeaders[i].$2),
      );
    }
    cursor++;

    final sortedCategories = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedCategories.isEmpty) {
      _writeMergedBanner(
        sheet,
        row: cursor,
        startCol: 0,
        endCol: 5,
        text: 'Belum ada transaksi pengeluaran pada periode $monthLabel.',
        style: _dataStyle(align: HorizontalAlign.Center, fontColor: _inkMuted),
        rowHeight: 24,
      );
      cursor += 2;
    } else {
      final startR = _r(cursor);
      final totalRowIdx = cursor + sortedCategories.length;
      final totalRowExcel = _r(totalRowIdx);

      for (var i = 0; i < sortedCategories.length; i++) {
        final entry = sortedCategories[i];
        final row = cursor + i;
        final rowExcel = _r(row);
        final zebra = i.isOdd;
        final txCount = countByCategory[entry.key] ?? 0;
        final share = totalExpense > 0 ? entry.value / totalExpense : 0.0;
        sheet.setRowHeight(row, 21);

        _writeCell(
          sheet,
          0,
          row,
          TextCellValue(entry.key),
          _dataStyle(zebra: zebra, bold: i == 0),
        );
        _writeCell(
          sheet,
          1,
          row,
          IntCellValue(txCount),
          _dataStyle(
            zebra: zebra,
            align: HorizontalAlign.Center,
            numberFormat: _intFormat,
          ),
        );
        _writeCell(
          sheet,
          2,
          row,
          IntCellValue(entry.value),
          _dataStyle(
            zebra: zebra,
            bold: i == 0,
            align: HorizontalAlign.Right,
            fontColor: _expenseInk,
            numberFormat: _idrFormat,
          ),
        );
        _writeCell(
          sheet,
          3,
          row,
          FormulaCellValue(
            'IF(C$totalRowExcel>0,C$rowExcel/C$totalRowExcel,0)',
          ),
          _dataStyle(
            zebra: zebra,
            align: HorizontalAlign.Right,
            numberFormat: _percentFormat,
          ),
        );
        _writeCell(
          sheet,
          4,
          row,
          FormulaCellValue('IF(B$rowExcel>0,C$rowExcel/B$rowExcel,0)'),
          _dataStyle(
            zebra: zebra,
            align: HorizontalAlign.Right,
            fontColor: _inkMuted,
            numberFormat: _idrFormat,
          ),
        );
        _writeCell(
          sheet,
          5,
          row,
          TextCellValue(
            '${_visualBar(share)} ${(share * 100).toStringAsFixed(1)}%',
          ),
          _dataStyle(
            zebra: zebra,
            fontColor: i == 0 ? _expenseInk : _brandPrimary,
          ),
        );
      }

      final endR = _r(totalRowIdx - 1);
      sheet.setRowHeight(totalRowIdx, 25);
      _writeCell(
        sheet,
        0,
        totalRowIdx,
        TextCellValue('TOTAL PENGELUARAN'),
        _totalRowStyle(),
      );
      _writeCell(
        sheet,
        1,
        totalRowIdx,
        FormulaCellValue('SUM(B$startR:B$endR)'),
        _totalRowStyle(
          align: HorizontalAlign.Center,
          numberFormat: _intFormat,
        ),
      );
      _writeCell(
        sheet,
        2,
        totalRowIdx,
        FormulaCellValue('SUM(C$startR:C$endR)'),
        _totalRowStyle(
          align: HorizontalAlign.Right,
          fontColor: _expenseInk,
          numberFormat: _idrFormat,
        ),
      );
      _writeCell(
        sheet,
        3,
        totalRowIdx,
        FormulaCellValue('SUM(D$startR:D$endR)'),
        _totalRowStyle(
          align: HorizontalAlign.Right,
          numberFormat: _percentFormat,
        ),
      );
      _writeCell(
        sheet,
        4,
        totalRowIdx,
        FormulaCellValue(
          'IF(B$totalRowExcel>0,C$totalRowExcel/B$totalRowExcel,0)',
        ),
        _totalRowStyle(align: HorizontalAlign.Right, numberFormat: _idrFormat),
      );
      _writeCell(
        sheet,
        5,
        totalRowIdx,
        TextCellValue('100.0% Tercatat'),
        _totalRowStyle(align: HorizontalAlign.Left),
      );
      cursor = totalRowIdx + 2;
    }

    _writeMergedBanner(
      sheet,
      row: cursor,
      startCol: 0,
      endCol: 5,
      text: 'B. REALISASI BUDGET VS AKTUAL',
      style: _sectionTitleStyle(),
      rowHeight: 24,
    );
    cursor++;

    sheet.setRowHeight(cursor, 25);
    final budgetHeaders = <(String, HorizontalAlign)>[
      ('Kategori Budget', HorizontalAlign.Left),
      ('Batas Bulanan (Rp)', HorizontalAlign.Right),
      ('Terpakai (Rp)', HorizontalAlign.Right),
      ('Sisa / Selisih (Rp)', HorizontalAlign.Right),
      ('Pemakaian (%)', HorizontalAlign.Right),
      ('Status', HorizontalAlign.Center),
    ];
    for (var i = 0; i < budgetHeaders.length; i++) {
      _writeCell(
        sheet,
        i,
        cursor,
        TextCellValue(budgetHeaders[i].$1),
        _tableHeaderStyle(align: budgetHeaders[i].$2),
      );
    }
    cursor++;

    final activeBudgets = categoryBudgets
        .where((b) => b.category != 'GLOBAL' && b.monthlyLimit > 0)
        .toList();

    if (activeBudgets.isEmpty && monthlyBudget <= 0) {
      _writeMergedBanner(
        sheet,
        row: cursor,
        startCol: 0,
        endCol: 5,
        text: 'Belum ada batas budget yang diatur. Atur di tab Rencana > Budget.',
        style: _dataStyle(align: HorizontalAlign.Center, fontColor: _inkMuted),
        rowHeight: 24,
      );
    } else {
      final rows = <(String, int, int, double)>[];
      if (activeBudgets.isNotEmpty) {
        for (final b in activeBudgets) {
          rows.add((
            b.category,
            b.monthlyLimit,
            expenseByCategory[b.category] ?? 0,
            b.alertThreshold,
          ));
        }
      } else {
        rows.add(('Total Budget Bulanan', monthlyBudget, totalExpense, 0.8));
      }

      final startR = _r(cursor);
      for (var i = 0; i < rows.length; i++) {
        final item = rows[i];
        final row = cursor + i;
        final rowExcel = _r(row);
        final zebra = i.isOdd;
        final limit = item.$2;
        final spent = item.$3;
        final ratio = limit > 0 ? spent / limit : 0.0;
        final (statusLabel, statusInk, statusBg) = ratio > 1.0
            ? ('Overbudget', _expenseInk, _expenseBg)
            : ratio >= item.$4
            ? ('Hati-hati', _warningInk, _warningBg)
            : ('Aman', _incomeInk, _incomeBg);
        sheet.setRowHeight(row, 21);

        _writeCell(
          sheet,
          0,
          row,
          TextCellValue(item.$1),
          _dataStyle(zebra: zebra, bold: true),
        );
        _writeCell(
          sheet,
          1,
          row,
          IntCellValue(limit),
          _dataStyle(
            zebra: zebra,
            align: HorizontalAlign.Right,
            numberFormat: _idrFormat,
          ),
        );
        _writeCell(
          sheet,
          2,
          row,
          IntCellValue(spent),
          _dataStyle(
            zebra: zebra,
            align: HorizontalAlign.Right,
            fontColor: _expenseInk,
            numberFormat: _idrFormat,
          ),
        );
        _writeCell(
          sheet,
          3,
          row,
          FormulaCellValue('B$rowExcel-C$rowExcel'),
          _dataStyle(
            zebra: zebra,
            bold: true,
            align: HorizontalAlign.Right,
            fontColor: limit - spent < 0 ? _expenseInk : _incomeInk,
            numberFormat: _signedIdrFormat,
          ),
        );
        _writeCell(
          sheet,
          4,
          row,
          FormulaCellValue('IF(B$rowExcel>0,C$rowExcel/B$rowExcel,0)'),
          _dataStyle(
            zebra: zebra,
            align: HorizontalAlign.Right,
            numberFormat: _percentFormat,
          ),
        );
        _writeCell(
          sheet,
          5,
          row,
          TextCellValue(statusLabel),
          _dataStyle(
            bold: true,
            align: HorizontalAlign.Center,
            fontColor: statusInk,
            bgColor: statusBg,
          ),
        );
      }

      final totalRowIdx = cursor + rows.length;
      final endR = _r(totalRowIdx - 1);
      final totalR = _r(totalRowIdx);
      sheet.setRowHeight(totalRowIdx, 25);

      _writeCell(
        sheet,
        0,
        totalRowIdx,
        TextCellValue('TOTAL BUDGET'),
        _totalRowStyle(),
      );
      _writeCell(
        sheet,
        1,
        totalRowIdx,
        FormulaCellValue('SUM(B$startR:B$endR)'),
        _totalRowStyle(align: HorizontalAlign.Right, numberFormat: _idrFormat),
      );
      _writeCell(
        sheet,
        2,
        totalRowIdx,
        FormulaCellValue('SUM(C$startR:C$endR)'),
        _totalRowStyle(
          align: HorizontalAlign.Right,
          fontColor: _expenseInk,
          numberFormat: _idrFormat,
        ),
      );
      _writeCell(
        sheet,
        3,
        totalRowIdx,
        FormulaCellValue('B$totalR-C$totalR'),
        _totalRowStyle(
          align: HorizontalAlign.Right,
          numberFormat: _signedIdrFormat,
        ),
      );
      _writeCell(
        sheet,
        4,
        totalRowIdx,
        FormulaCellValue('IF(B$totalR>0,C$totalR/B$totalR,0)'),
        _totalRowStyle(
          align: HorizontalAlign.Right,
          numberFormat: _percentFormat,
        ),
      );
      _writeCell(
        sheet,
        5,
        totalRowIdx,
        FormulaCellValue(
          'IF(E$totalR>1,"Overbudget",IF(E$totalR>=0.8,"Hati-hati","Aman"))',
        ),
        _totalRowStyle(align: HorizontalAlign.Center),
      );
    }

    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 19);
    sheet.setColumnWidth(2, 21);
    sheet.setColumnWidth(3, 20);
    sheet.setColumnWidth(4, 19);
    sheet.setColumnWidth(5, 22);
  }

  static void _buildPlanAndObligationsSheet({
    required Sheet sheet,
    required DateTime month,
    required String monthLabel,
    required String subtitleText,
    required List<GoalModel> goals,
    required List<BillModel> bills,
    required List<DebtModel> debts,
    required int totalAllWallets,
  }) {
    _writeMergedBanner(
      sheet,
      row: 0,
      startCol: 0,
      endCol: 7,
      text: 'SAKUPROWANN  |  TARGET TABUNGAN, TAGIHAN & HUTANG/PIUTANG',
      style: _titleBannerStyle(),
      rowHeight: 32,
    );
    _writeMergedBanner(
      sheet,
      row: 1,
      startCol: 0,
      endCol: 7,
      text: subtitleText,
      style: _subtitleStripStyle(),
      rowHeight: 21,
    );
    sheet.setRowHeight(2, 10);

    var cursor = 3;

    _writeMergedBanner(
      sheet,
      row: cursor,
      startCol: 0,
      endCol: 7,
      text: 'A. TARGET TABUNGAN (GOALS)',
      style: _sectionTitleStyle(),
      rowHeight: 24,
    );
    cursor++;

    sheet.setRowHeight(cursor, 24);
    final goalHeaders = <(String, HorizontalAlign)>[
      ('Nama Target', HorizontalAlign.Left),
      ('Terkumpul (Rp)', HorizontalAlign.Right),
      ('Nominal Target (Rp)', HorizontalAlign.Right),
      ('Sisa Target (Rp)', HorizontalAlign.Right),
      ('Progres (%)', HorizontalAlign.Right),
      ('Tenggat', HorizontalAlign.Center),
      ('Visual', HorizontalAlign.Left),
      ('Status', HorizontalAlign.Center),
    ];
    for (var i = 0; i < goalHeaders.length; i++) {
      _writeCell(
        sheet,
        i,
        cursor,
        TextCellValue(goalHeaders[i].$1),
        _tableHeaderStyle(align: goalHeaders[i].$2),
      );
    }
    cursor++;

    if (goals.isEmpty) {
      _writeMergedBanner(
        sheet,
        row: cursor,
        startCol: 0,
        endCol: 7,
        text: 'Belum ada target tabungan yang dibuat.',
        style: _dataStyle(align: HorizontalAlign.Center, fontColor: _inkMuted),
        rowHeight: 23,
      );
      cursor += 2;
    } else {
      final startR = _r(cursor);
      for (var i = 0; i < goals.length; i++) {
        final goal = goals[i];
        final row = cursor + i;
        final rowExcel = _r(row);
        final zebra = i.isOdd;
        sheet.setRowHeight(row, 21);

        final deadlineStr = goal.deadline != null
            ? DateFormat('dd MMM yyyy').format(goal.deadline!)
            : 'Fleksibel';
        final done = goal.reachedTarget;

        _writeCell(
          sheet,
          0,
          row,
          TextCellValue(goal.name),
          _dataStyle(zebra: zebra, bold: true),
        );
        _writeCell(
          sheet,
          1,
          row,
          IntCellValue(goal.currentAmount),
          _dataStyle(
            zebra: zebra,
            align: HorizontalAlign.Right,
            fontColor: _incomeInk,
            numberFormat: _idrFormat,
          ),
        );
        _writeCell(
          sheet,
          2,
          row,
          IntCellValue(goal.targetAmount),
          _dataStyle(
            zebra: zebra,
            align: HorizontalAlign.Right,
            numberFormat: _idrFormat,
          ),
        );
        _writeCell(
          sheet,
          3,
          row,
          FormulaCellValue('MAX(0,C$rowExcel-B$rowExcel)'),
          _dataStyle(
            zebra: zebra,
            align: HorizontalAlign.Right,
            fontColor: _inkMuted,
            numberFormat: _idrFormat,
          ),
        );
        _writeCell(
          sheet,
          4,
          row,
          FormulaCellValue('IF(C$rowExcel>0,B$rowExcel/C$rowExcel,0)'),
          _dataStyle(
            zebra: zebra,
            align: HorizontalAlign.Right,
            numberFormat: _percentFormat,
          ),
        );
        _writeCell(
          sheet,
          5,
          row,
          TextCellValue(deadlineStr),
          _dataStyle(zebra: zebra, align: HorizontalAlign.Center),
        );
        _writeCell(
          sheet,
          6,
          row,
          TextCellValue(_visualBar(goal.progressRatio)),
          _dataStyle(zebra: zebra, fontColor: _brandPrimary),
        );
        _writeCell(
          sheet,
          7,
          row,
          TextCellValue(done ? 'Tercapai' : 'Berjalan'),
          _dataStyle(
            bold: true,
            align: HorizontalAlign.Center,
            fontColor: done ? _incomeInk : _transferInk,
            bgColor: done ? _incomeBg : _transferBg,
          ),
        );
      }

      final totalRowIdx = cursor + goals.length;
      final endR = _r(totalRowIdx - 1);
      final totalR = _r(totalRowIdx);
      sheet.setRowHeight(totalRowIdx, 24);
      _writeCell(
        sheet,
        0,
        totalRowIdx,
        TextCellValue('TOTAL TARGET TABUNGAN'),
        _totalRowStyle(),
      );
      _writeCell(
        sheet,
        1,
        totalRowIdx,
        FormulaCellValue('SUM(B$startR:B$endR)'),
        _totalRowStyle(
          align: HorizontalAlign.Right,
          fontColor: _incomeInk,
          numberFormat: _idrFormat,
        ),
      );
      _writeCell(
        sheet,
        2,
        totalRowIdx,
        FormulaCellValue('SUM(C$startR:C$endR)'),
        _totalRowStyle(align: HorizontalAlign.Right, numberFormat: _idrFormat),
      );
      _writeCell(
        sheet,
        3,
        totalRowIdx,
        FormulaCellValue('SUM(D$startR:D$endR)'),
        _totalRowStyle(align: HorizontalAlign.Right, numberFormat: _idrFormat),
      );
      _writeCell(
        sheet,
        4,
        totalRowIdx,
        FormulaCellValue('IF(C$totalR>0,B$totalR/C$totalR,0)'),
        _totalRowStyle(
          align: HorizontalAlign.Right,
          numberFormat: _percentFormat,
        ),
      );
      _writeMergedBanner(
        sheet,
        row: totalRowIdx,
        startCol: 5,
        endCol: 7,
        text: '${goals.length} Target Aktif',
        style: _totalRowStyle(align: HorizontalAlign.Center),
      );
      cursor = totalRowIdx + 2;
    }

    _writeMergedBanner(
      sheet,
      row: cursor,
      startCol: 0,
      endCol: 7,
      text: 'B. TAGIHAN RUTIN BULANAN ($monthLabel)',
      style: _sectionTitleStyle(),
      rowHeight: 24,
    );
    cursor++;

    sheet.setRowHeight(cursor, 24);
    final billHeaders = <(String, HorizontalAlign)>[
      ('Nama Tagihan', HorizontalAlign.Left),
      ('Kategori', HorizontalAlign.Left),
      ('Jatuh Tempo', HorizontalAlign.Center),
      ('Nominal (Rp)', HorizontalAlign.Right),
      ('Status Bulan Ini', HorizontalAlign.Center),
    ];
    for (var i = 0; i < billHeaders.length; i++) {
      _writeCell(
        sheet,
        i,
        cursor,
        TextCellValue(billHeaders[i].$1),
        _tableHeaderStyle(align: billHeaders[i].$2),
      );
    }
    _writeMergedBanner(
      sheet,
      row: cursor,
      startCol: 5,
      endCol: 7,
      text: 'Keterangan Siklus',
      style: _tableHeaderStyle(align: HorizontalAlign.Left),
    );
    cursor++;

    if (bills.isEmpty) {
      _writeMergedBanner(
        sheet,
        row: cursor,
        startCol: 0,
        endCol: 7,
        text: 'Belum ada tagihan rutin bulanan terdaftar.',
        style: _dataStyle(align: HorizontalAlign.Center, fontColor: _inkMuted),
        rowHeight: 23,
      );
      cursor += 2;
    } else {
      final startR = _r(cursor);
      for (var i = 0; i < bills.length; i++) {
        final bill = bills[i];
        final row = cursor + i;
        final zebra = i.isOdd;
        final paid = bill.isPaidFor(month);
        sheet.setRowHeight(row, 21);

        _writeCell(
          sheet,
          0,
          row,
          TextCellValue(bill.name),
          _dataStyle(zebra: zebra, bold: true),
        );
        _writeCell(
          sheet,
          1,
          row,
          TextCellValue(bill.category),
          _dataStyle(zebra: zebra),
        );
        _writeCell(
          sheet,
          2,
          row,
          TextCellValue('Tgl ${bill.dueDay}'),
          _dataStyle(zebra: zebra, align: HorizontalAlign.Center),
        );
        _writeCell(
          sheet,
          3,
          row,
          IntCellValue(bill.amount),
          _dataStyle(
            zebra: zebra,
            align: HorizontalAlign.Right,
            numberFormat: _idrFormat,
          ),
        );
        _writeCell(
          sheet,
          4,
          row,
          TextCellValue(paid ? 'Lunas' : 'Belum Bayar'),
          _dataStyle(
            bold: true,
            align: HorizontalAlign.Center,
            fontColor: paid ? _incomeInk : _warningInk,
            bgColor: paid ? _incomeBg : _warningBg,
          ),
        );
        _writeMergedBanner(
          sheet,
          row: row,
          startCol: 5,
          endCol: 7,
          text: paid
              ? 'Terbayar untuk siklus $monthLabel'
              : 'Menunggu pembayaran bulan $monthLabel',
          style: _dataStyle(zebra: zebra, fontColor: _inkMuted),
        );
      }

      final totalRowIdx = cursor + bills.length;
      final endR = _r(totalRowIdx - 1);
      sheet.setRowHeight(totalRowIdx, 24);
      _writeMergedBanner(
        sheet,
        row: totalRowIdx,
        startCol: 0,
        endCol: 2,
        text: 'TOTAL KOMITMEN TAGIHAN BULANAN',
        style: _totalRowStyle(align: HorizontalAlign.Right),
      );
      _writeCell(
        sheet,
        3,
        totalRowIdx,
        FormulaCellValue('SUM(D$startR:D$endR)'),
        _totalRowStyle(align: HorizontalAlign.Right, numberFormat: _idrFormat),
      );
      _writeMergedBanner(
        sheet,
        row: totalRowIdx,
        startCol: 4,
        endCol: 7,
        text:
            'Lunas: ${bills.where((b) => b.isPaidFor(month)).length} / ${bills.length} Tagihan',
        style: _totalRowStyle(align: HorizontalAlign.Center),
      );
      cursor = totalRowIdx + 2;
    }

    _writeMergedBanner(
      sheet,
      row: cursor,
      startCol: 0,
      endCol: 7,
      text: 'C. HUTANG & PIUTANG',
      style: _sectionTitleStyle(),
      rowHeight: 24,
    );
    cursor++;

    sheet.setRowHeight(cursor, 24);
    final debtHeaders = <(String, HorizontalAlign)>[
      ('Jenis', HorizontalAlign.Center),
      ('Nama Pihak', HorizontalAlign.Left),
      ('Total Pokok (Rp)', HorizontalAlign.Right),
      ('Terbayar (Rp)', HorizontalAlign.Right),
      ('Sisa (Rp)', HorizontalAlign.Right),
      ('Jatuh Tempo', HorizontalAlign.Center),
      ('Status', HorizontalAlign.Center),
      ('Catatan', HorizontalAlign.Left),
    ];
    for (var i = 0; i < debtHeaders.length; i++) {
      _writeCell(
        sheet,
        i,
        cursor,
        TextCellValue(debtHeaders[i].$1),
        _tableHeaderStyle(align: debtHeaders[i].$2),
      );
    }
    cursor++;

    var openReceivable = 0;
    var openPayable = 0;
    for (final d in debts) {
      if (!d.isSettled) {
        if (d.isReceivable) {
          openReceivable += d.remainingAmount;
        } else {
          openPayable += d.remainingAmount;
        }
      }
    }

    if (debts.isEmpty) {
      _writeMergedBanner(
        sheet,
        row: cursor,
        startCol: 0,
        endCol: 7,
        text: 'Tidak ada catatan hutang maupun piutang.',
        style: _dataStyle(align: HorizontalAlign.Center, fontColor: _inkMuted),
        rowHeight: 23,
      );
      cursor += 2;
    } else {
      final startR = _r(cursor);
      for (var i = 0; i < debts.length; i++) {
        final debt = debts[i];
        final row = cursor + i;
        final rowExcel = _r(row);
        final zebra = i.isOdd;
        sheet.setRowHeight(row, 21);

        final dueText = debt.dueDate != null
            ? DateFormat('dd MMM yyyy').format(debt.dueDate!)
            : '-';

        _writeCell(
          sheet,
          0,
          row,
          TextCellValue(debt.isReceivable ? 'Piutang' : 'Hutang'),
          _dataStyle(
            bold: true,
            align: HorizontalAlign.Center,
            fontColor: debt.isReceivable ? _incomeInk : _expenseInk,
            bgColor: debt.isReceivable ? _incomeBg : _expenseBg,
          ),
        );
        _writeCell(
          sheet,
          1,
          row,
          TextCellValue(debt.personName),
          _dataStyle(zebra: zebra, bold: true),
        );
        _writeCell(
          sheet,
          2,
          row,
          IntCellValue(debt.principalAmount),
          _dataStyle(
            zebra: zebra,
            align: HorizontalAlign.Right,
            numberFormat: _idrFormat,
          ),
        );
        _writeCell(
          sheet,
          3,
          row,
          FormulaCellValue('MAX(0,C$rowExcel-E$rowExcel)'),
          _dataStyle(
            zebra: zebra,
            align: HorizontalAlign.Right,
            fontColor: _incomeInk,
            numberFormat: _idrFormat,
          ),
        );
        _writeCell(
          sheet,
          4,
          row,
          IntCellValue(debt.remainingAmount),
          _dataStyle(
            zebra: zebra,
            bold: !debt.isSettled,
            align: HorizontalAlign.Right,
            fontColor: debt.isSettled ? _inkMuted : _inkPrimary,
            numberFormat: _idrFormat,
          ),
        );
        _writeCell(
          sheet,
          5,
          row,
          TextCellValue(dueText),
          _dataStyle(zebra: zebra, align: HorizontalAlign.Center),
        );
        _writeCell(
          sheet,
          6,
          row,
          TextCellValue(debt.isSettled ? 'Lunas' : 'Berjalan'),
          _dataStyle(
            bold: true,
            align: HorizontalAlign.Center,
            fontColor: debt.isSettled ? _incomeInk : _warningInk,
            bgColor: debt.isSettled ? _incomeBg : _warningBg,
          ),
        );
        _writeCell(
          sheet,
          7,
          row,
          TextCellValue(debt.note.isEmpty ? '-' : debt.note),
          _dataStyle(zebra: zebra, fontColor: _inkMuted, wrap: true),
        );
      }

      final totalRowIdx = cursor + debts.length;
      final endR = _r(totalRowIdx - 1);
      sheet.setRowHeight(totalRowIdx, 24);
      _writeMergedBanner(
        sheet,
        row: totalRowIdx,
        startCol: 0,
        endCol: 1,
        text: 'TOTAL HUTANG & PIUTANG',
        style: _totalRowStyle(align: HorizontalAlign.Right),
      );
      _writeCell(
        sheet,
        2,
        totalRowIdx,
        FormulaCellValue('SUM(C$startR:C$endR)'),
        _totalRowStyle(align: HorizontalAlign.Right, numberFormat: _idrFormat),
      );
      _writeCell(
        sheet,
        3,
        totalRowIdx,
        FormulaCellValue('SUM(D$startR:D$endR)'),
        _totalRowStyle(
          align: HorizontalAlign.Right,
          fontColor: _incomeInk,
          numberFormat: _idrFormat,
        ),
      );
      _writeCell(
        sheet,
        4,
        totalRowIdx,
        FormulaCellValue('SUM(E$startR:E$endR)'),
        _totalRowStyle(align: HorizontalAlign.Right, numberFormat: _idrFormat),
      );
      _writeMergedBanner(
        sheet,
        row: totalRowIdx,
        startCol: 5,
        endCol: 7,
        text: 'Posisi Bersih Piutang - Hutang: ${_formatRpPlain(openReceivable - openPayable)}',
        style: _totalRowStyle(align: HorizontalAlign.Center),
      );
      cursor = totalRowIdx + 2;
    }

    _writeMergedBanner(
      sheet,
      row: cursor,
      startCol: 0,
      endCol: 7,
      text: 'D. REKONSILIASI KEKAYAAN BERSIH RIIL (ASET + PIUTANG - HUTANG)',
      style: _sectionTitleStyle(),
      rowHeight: 24,
    );
    cursor++;

    final recRows = <(String, int, ExcelColor)>[
      ('Total Saldo Seluruh Dompet', totalAllWallets, _inkPrimary),
      ('Ditambah: Sisa Piutang Berjalan', openReceivable, _incomeInk),
      ('Dikurangi: Sisa Hutang Berjalan', -openPayable, _expenseInk),
    ];
    final recStartR = _r(cursor);
    for (var i = 0; i < recRows.length; i++) {
      final row = cursor + i;
      sheet.setRowHeight(row, 21);
      _writeMergedBanner(
        sheet,
        row: row,
        startCol: 0,
        endCol: 3,
        text: recRows[i].$1,
        style: _dataStyle(zebra: i.isOdd),
      );
      _writeCell(
        sheet,
        4,
        row,
        IntCellValue(recRows[i].$2),
        _dataStyle(
          zebra: i.isOdd,
          bold: true,
          align: HorizontalAlign.Right,
          fontColor: recRows[i].$3,
          numberFormat: _signedIdrFormat,
        ),
      );
      _writeMergedBanner(
        sheet,
        row: row,
        startCol: 5,
        endCol: 7,
        text: i == 0
            ? 'Likuiditas aktif seluruh dompet'
            : i == 1
            ? 'Tagihan ke pihak lain belum lunas'
            : 'Kewajiban ke pihak lain belum lunas',
        style: _dataStyle(zebra: i.isOdd, fontColor: _inkMuted),
      );
    }

    final finalNetRow = cursor + recRows.length;
    final recEndR = _r(finalNetRow - 1);
    sheet.setRowHeight(finalNetRow, 26);
    _writeMergedBanner(
      sheet,
      row: finalNetRow,
      startCol: 0,
      endCol: 3,
      text: 'KEKAYAAN BERSIH RIIL (ESTIMASI FINAL)',
      style: _totalRowStyle(align: HorizontalAlign.Left),
    );
    _writeCell(
      sheet,
      4,
      finalNetRow,
      FormulaCellValue('SUM(E$recStartR:E$recEndR)'),
      _totalRowStyle(
        align: HorizontalAlign.Right,
        fontColor: _brandDark,
        numberFormat: _idrFormat,
      ),
    );
    _writeMergedBanner(
      sheet,
      row: finalNetRow,
      startCol: 5,
      endCol: 7,
      text: 'Otomatis terhitung dengan rumus Excel',
      style: _totalRowStyle(align: HorizontalAlign.Center),
    );

    sheet.setColumnWidth(0, 22);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 19);
    sheet.setColumnWidth(3, 19);
    sheet.setColumnWidth(4, 19);
    sheet.setColumnWidth(5, 15);
    sheet.setColumnWidth(6, 15);
    sheet.setColumnWidth(7, 26);
  }

  static void _buildExecutiveSummarySheet({
    required Sheet sheet,
    required DateTime month,
    required String monthLabel,
    required String subtitleText,
    required List<TransactionModel> sortedTx,
    required Map<int, String> walletMap,
    required int totalIncome,
    required int totalExpense,
    required int transferCount,
    required int netWorth,
    required int monthlyBudget,
    required int previousMonthExpense,
    required List<String> insights,
    required int ledgerStartRow,
    required int ledgerEndRow,
    required int walletStartRow,
    required int walletEndRow,
  }) {
    _writeMergedBanner(
      sheet,
      row: 0,
      startCol: 0,
      endCol: 5,
      text: 'SAKUPROWANN  |  LAPORAN KEUANGAN PRIBADI ($monthLabel)',
      style: _titleBannerStyle(),
      rowHeight: 34,
    );
    _writeMergedBanner(
      sheet,
      row: 1,
      startCol: 0,
      endCol: 5,
      text: subtitleText,
      style: _subtitleStripStyle(),
      rowHeight: 22,
    );
    sheet.setRowHeight(2, 10);

    var cursor = 3;
    _writeMergedBanner(
      sheet,
      row: cursor,
      startCol: 0,
      endCol: 5,
      text: '1. RINGKASAN KINERJA KEUANGAN BULANAN (KPI)',
      style: _sectionTitleStyle(),
      rowHeight: 24,
    );
    cursor++;

    sheet.setRowHeight(cursor, 25);
    _writeMergedBanner(
      sheet,
      row: cursor,
      startCol: 0,
      endCol: 1,
      text: 'Indikator Keuangan',
      style: _tableHeaderStyle(align: HorizontalAlign.Left),
    );
    _writeCell(
      sheet,
      2,
      cursor,
      TextCellValue('Nilai'),
      _tableHeaderStyle(align: HorizontalAlign.Right),
    );
    _writeMergedBanner(
      sheet,
      row: cursor,
      startCol: 3,
      endCol: 5,
      text: 'Analisa & Catatan',
      style: _tableHeaderStyle(align: HorizontalAlign.Left),
    );
    cursor++;

    final hasLedger = ledgerStartRow > 0 && ledgerEndRow >= ledgerStartRow;
    final hasWallets = walletStartRow > 0 && walletEndRow >= walletStartRow;

    final incomeRow = cursor;
    final expenseRow = cursor + 1;
    final netCashRow = cursor + 2;
    final savingsRow = cursor + 3;
    final dailyAvgRow = cursor + 4;
    final budgetRow = cursor + 5;
    final remainingBudgetRow = cursor + 6;
    final netWorthRow = cursor + 7;
    final allWalletsRow = cursor + 8;

    final daysInMonth = _daysInMonth(month);
    final netCash = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? netCash / totalIncome : 0.0;
    final savingsNote = totalIncome <= 0
        ? 'Belum ada pemasukan tercatat bulan ini'
        : savingsRate >= 0.30
        ? 'Sangat sehat (di atas 30% pemasukan tersimpan)'
        : savingsRate >= 0.15
        ? 'Sehat (15% - 30% pemasukan tersimpan)'
        : savingsRate >= 0
        ? 'Tipis, pertimbangkan efisiensi pengeluaran'
        : 'Defisit, pengeluaran melebihi pemasukan';

    final expenseDeltaNote = previousMonthExpense <= 0
        ? 'Periode acuan pertama (belum ada data bulan lalu)'
        : totalExpense <= previousMonthExpense
        ? 'Turun ${(((previousMonthExpense - totalExpense) / previousMonthExpense) * 100).toStringAsFixed(1)}% dari bulan lalu'
        : 'Naik ${(((totalExpense - previousMonthExpense) / previousMonthExpense) * 100).toStringAsFixed(1)}% dari bulan lalu';

    void writeKpiRow({
      required int row,
      required String label,
      required CellValue value,
      required String note,
      required NumFormat format,
      bool zebra = false,
      bool bold = false,
      ExcelColor? valueColor,
      ExcelColor? rowBg,
    }) {
      sheet.setRowHeight(row, 22);
      _writeMergedBanner(
        sheet,
        row: row,
        startCol: 0,
        endCol: 1,
        text: label,
        style: _dataStyle(zebra: zebra, bold: bold, bgColor: rowBg),
      );
      _writeCell(
        sheet,
        2,
        row,
        value,
        _dataStyle(
          zebra: zebra,
          bold: true,
          align: HorizontalAlign.Right,
          fontColor: valueColor ?? _inkPrimary,
          bgColor: rowBg,
          numberFormat: format,
        ),
      );
      _writeMergedBanner(
        sheet,
        row: row,
        startCol: 3,
        endCol: 5,
        text: note,
        style: _dataStyle(
          zebra: zebra,
          fontColor: _inkMuted,
          bgColor: rowBg,
        ),
      );
    }

    writeKpiRow(
      row: incomeRow,
      label: 'Total Pemasukan Bulan Ini',
      value: hasLedger
          ? FormulaCellValue(
              "SUM('$_sheetLedger'!H$ledgerStartRow:H$ledgerEndRow)",
            )
          : IntCellValue(totalIncome),
      note:
          '${sortedTx.where((t) => t.kind == TransactionKind.income).length} transaksi pemasukan',
      format: _idrFormat,
      valueColor: _incomeInk,
    );

    writeKpiRow(
      row: expenseRow,
      label: 'Total Pengeluaran Bulan Ini',
      value: hasLedger
          ? FormulaCellValue(
              "SUM('$_sheetLedger'!I$ledgerStartRow:I$ledgerEndRow)",
            )
          : IntCellValue(totalExpense),
      note: expenseDeltaNote,
      format: _idrFormat,
      zebra: true,
      valueColor: _expenseInk,
    );

    writeKpiRow(
      row: netCashRow,
      label: 'Arus Kas Bersih (Surplus / Defisit)',
      value: FormulaCellValue('C${_r(incomeRow)}-C${_r(expenseRow)}'),
      note: netCash >= 0
          ? 'Surplus bersih bulan $monthLabel (transfer $transferCount kali netral)'
          : 'Defisit bulan $monthLabel, periksa pos belanja terbesar',
      format: _signedIdrFormat,
      bold: true,
      valueColor: netCash >= 0 ? _incomeInk : _expenseInk,
      rowBg: netCash >= 0 ? _incomeBg : _expenseBg,
    );

    writeKpiRow(
      row: savingsRow,
      label: 'Rasio Tabungan (Savings Rate)',
      value: FormulaCellValue(
        'IF(C${_r(incomeRow)}>0,(C${_r(incomeRow)}-C${_r(expenseRow)})/C${_r(incomeRow)},0)',
      ),
      note: savingsNote,
      format: _percentFormat,
      zebra: true,
      valueColor: savingsRate >= 0.15 ? _incomeInk : _warningInk,
    );

    writeKpiRow(
      row: dailyAvgRow,
      label: 'Rata-rata Pengeluaran Harian',
      value: FormulaCellValue('C${_r(expenseRow)}/$daysInMonth'),
      note: 'Dihitung merata untuk $daysInMonth hari di bulan $monthLabel',
      format: _idrFormat,
    );

    writeKpiRow(
      row: budgetRow,
      label: 'Target Budget Bulanan',
      value: IntCellValue(monthlyBudget),
      note: monthlyBudget > 0
          ? 'Batas belanja bulanan aktif di SakuProWann'
          : 'Belum ditentukan',
      format: _idrFormat,
      zebra: true,
    );

    writeKpiRow(
      row: remainingBudgetRow,
      label: 'Sisa Budget Bulanan',
      value: monthlyBudget > 0
          ? FormulaCellValue('C${_r(budgetRow)}-C${_r(expenseRow)}')
          : const IntCellValue(0),
      note: monthlyBudget <= 0
          ? 'Atur budget di tab Rencana untuk pemantauan otomatis'
          : monthlyBudget - totalExpense >= 0
          ? 'Masih dalam batas aman budget'
          : 'Melebihi batas budget bulanan',
      format: _signedIdrFormat,
      valueColor: monthlyBudget - totalExpense >= 0 ? _incomeInk : _expenseInk,
    );

    writeKpiRow(
      row: netWorthRow,
      label: 'Saldo Bersih Aktif (Net Worth)',
      value: hasWallets
          ? FormulaCellValue(
              "SUMIF('$_sheetWallets'!D$walletStartRow:D$walletEndRow,\"Ya\",'$_sheetWallets'!E$walletStartRow:E$walletEndRow)",
            )
          : IntCellValue(netWorth),
      note: 'Total dompet aktif yang masuk perhitungan saldo bersih',
      format: _idrFormat,
      bold: true,
      valueColor: _brandDark,
      rowBg: _goldSoft,
    );

    writeKpiRow(
      row: allWalletsRow,
      label: 'Total Seluruh Dompet & Simpanan',
      value: hasWallets
          ? FormulaCellValue(
              "SUM('$_sheetWallets'!E$walletStartRow:E$walletEndRow)",
            )
          : IntCellValue(netWorth),
      note: 'Termasuk dompet terpisah / dana darurat',
      format: _idrFormat,
      zebra: true,
      valueColor: _brandDark,
    );

    cursor = allWalletsRow + 2;

    _writeMergedBanner(
      sheet,
      row: cursor,
      startCol: 0,
      endCol: 5,
      text: '2. INSIGHT OTOMATIS & CATATAN EKSEKUTIF',
      style: _sectionTitleStyle(),
      rowHeight: 24,
    );
    cursor++;

    final effectiveInsights = insights.isNotEmpty
        ? insights
        : <String>[
            'Gunakan sheet Buku Transaksi untuk filter dan audit detail per transaksi.',
            'Sheet Analisa Kategori & Budget merangkum pos pengeluaran terbesar beserta persentasenya.',
            'Semua angka total di workbook ini menggunakan rumus Excel dinamis yang otomatis menghitung ulang saat diedit.',
          ];

    for (var i = 0; i < effectiveInsights.length; i++) {
      final row = cursor + i;
      sheet.setRowHeight(row, 23);
      _writeCell(
        sheet,
        0,
        row,
        TextCellValue('#${i + 1}'),
        _dataStyle(
          zebra: i.isOdd,
          bold: true,
          align: HorizontalAlign.Center,
          fontColor: _brandPrimary,
        ),
      );
      _writeMergedBanner(
        sheet,
        row: row,
        startCol: 1,
        endCol: 5,
        text: effectiveInsights[i],
        style: _dataStyle(zebra: i.isOdd, wrap: true),
      );
    }
    cursor += effectiveInsights.length + 1;

    _writeMergedBanner(
      sheet,
      row: cursor,
      startCol: 0,
      endCol: 5,
      text: '3. TOP 5 PENGELUARAN TERBESAR BULAN INI',
      style: _sectionTitleStyle(),
      rowHeight: 24,
    );
    cursor++;

    sheet.setRowHeight(cursor, 24);
    final topHeaders = <(String, HorizontalAlign)>[
      ('Peringkat', HorizontalAlign.Center),
      ('Tanggal', HorizontalAlign.Center),
      ('Kategori', HorizontalAlign.Left),
      ('Keterangan', HorizontalAlign.Left),
      ('Dompet', HorizontalAlign.Left),
      ('Nominal (Rp)', HorizontalAlign.Right),
    ];
    for (var i = 0; i < topHeaders.length; i++) {
      _writeCell(
        sheet,
        i,
        cursor,
        TextCellValue(topHeaders[i].$1),
        _tableHeaderStyle(align: topHeaders[i].$2),
      );
    }
    cursor++;

    final topExpenses = sortedTx
        .where((tx) => tx.kind == TransactionKind.expense)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final topFive = topExpenses.take(5).toList();

    if (topFive.isEmpty) {
      _writeMergedBanner(
        sheet,
        row: cursor,
        startCol: 0,
        endCol: 5,
        text: 'Belum ada transaksi pengeluaran di periode $monthLabel.',
        style: _dataStyle(align: HorizontalAlign.Center, fontColor: _inkMuted),
        rowHeight: 23,
      );
    } else {
      for (var i = 0; i < topFive.length; i++) {
        final tx = topFive[i];
        final row = cursor + i;
        final zebra = i.isOdd;
        sheet.setRowHeight(row, 21);

        _writeCell(
          sheet,
          0,
          row,
          IntCellValue(i + 1),
          _dataStyle(
            zebra: zebra,
            bold: true,
            align: HorizontalAlign.Center,
            fontColor: i == 0 ? _expenseInk : _inkPrimary,
            numberFormat: _intFormat,
          ),
        );
        _writeCell(
          sheet,
          1,
          row,
          TextCellValue(DateFormat('dd MMM yyyy').format(tx.transactionDate)),
          _dataStyle(zebra: zebra, align: HorizontalAlign.Center),
        );
        _writeCell(
          sheet,
          2,
          row,
          TextCellValue(tx.category),
          _dataStyle(zebra: zebra),
        );
        _writeCell(
          sheet,
          3,
          row,
          TextCellValue(tx.displayTitle),
          _dataStyle(zebra: zebra, bold: i == 0),
        );
        _writeCell(
          sheet,
          4,
          row,
          TextCellValue(walletMap[tx.walletId] ?? 'Dompet'),
          _dataStyle(zebra: zebra, fontColor: _inkMuted),
        );
        _writeCell(
          sheet,
          5,
          row,
          IntCellValue(tx.amount),
          _dataStyle(
            zebra: zebra,
            bold: true,
            align: HorizontalAlign.Right,
            fontColor: _expenseInk,
            numberFormat: _idrFormat,
          ),
        );
      }
    }

    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 22);
    sheet.setColumnWidth(3, 28);
    sheet.setColumnWidth(4, 18);
    sheet.setColumnWidth(5, 20);
  }

  static String _formatRpPlain(int amount) {
    final abs = NumberFormat('#,##0', 'id_ID').format(amount.abs());
    return amount < 0 ? '-Rp $abs' : 'Rp $abs';
  }

  static Future<void> shareMonthlyExcel({
    required DateTime month,
    required List<TransactionModel> monthTransactions,
    required List<WalletModel> wallets,
    required int netWorth,
    int monthlyBudget = 0,
    List<BudgetModel> categoryBudgets = const <BudgetModel>[],
    List<GoalModel> goals = const <GoalModel>[],
    List<BillModel> bills = const <BillModel>[],
    List<DebtModel> debts = const <DebtModel>[],
    int previousMonthExpense = 0,
    List<String> insights = const <String>[],
  }) async {
    final bytes = buildMonthlyExcelBytes(
      month: month,
      monthTransactions: monthTransactions,
      wallets: wallets,
      netWorth: netWorth,
      monthlyBudget: monthlyBudget,
      categoryBudgets: categoryBudgets,
      goals: goals,
      bills: bills,
      debts: debts,
      previousMonthExpense: previousMonthExpense,
      insights: insights,
    );
    final ym = '${month.year}${month.month.toString().padLeft(2, '0')}';
    final fileName = 'SakuProWann_Laporan_$ym.xlsx';
    final xFile = await createShareableTempFile(
      bytes: bytes,
      fileName: fileName,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    await Share.shareXFiles(
      <XFile>[xFile],
      subject: 'Laporan Keuangan SakuProWann $ym',
      text: 'Laporan keuangan pribadi lengkap 5 sheet SakuProWann ($ym)',
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
        'Data bukan berkas backup SakuProWann yang sah.',
      );
    }
    return map;
  }

  static Future<void> shareBackupJsonFile(Map<String, Object?> snapshot) async {
    final jsonString = encodeBackupJson(snapshot);
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fileName = 'SakuProWann_Backup_$stamp.json';
    final xFile = await createShareableTempFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'application/json',
    );
    await Share.shareXFiles(
      <XFile>[xFile],
      subject: 'Backup Data SakuProWann',
      text: 'Cadangan data lokal SakuProWann ($stamp)',
    );
  }
}

import 'dart:math' show Point;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saku_pro/db/database_helper.dart';
import 'package:saku_pro/main.dart';
import 'package:saku_pro/models/roadmap_models.dart';
import 'package:saku_pro/models/transaction_item.dart';
import 'package:saku_pro/services/export_backup_service.dart';
import 'package:saku_pro/services/finance_controller.dart';
import 'package:saku_pro/services/quick_input_parser.dart';
import 'package:saku_pro/services/receipt_ocr_service.dart';
import 'package:saku_pro/services/whatsapp_helper.dart';

void main() {
  group('QuickInputParser & ReceiptOcrService offline parsers', () {
    final wallets = buildDefaultWallets(DateTime(2026, 11, 25))
        .asMap()
        .entries
        .map((e) => e.value.copyWith(id: e.key + 1))
        .toList();

    test('detects expense, income, and transfer phrases accurately', () {
      final kopi = QuickInputParser.parse('kopi 22rb gopay', wallets);
      expect(kopi.kind, TransactionKind.expense);
      expect(kopi.amount, 22000);
      expect(kopi.category, 'Ngopi');
      expect(kopi.wallet?.name, 'GoPay');

      final bensin = QuickInputParser.parse('bensin 50k cash', wallets);
      expect(bensin.kind, TransactionKind.expense);
      expect(bensin.amount, 50000);
      expect(bensin.category, 'Transportasi');
      expect(bensin.wallet?.name, 'Cash');

      final makan = QuickInputParser.parse('makan siang 35000 dana', wallets);
      expect(makan.kind, TransactionKind.expense);
      expect(makan.amount, 35000);
      expect(makan.category, 'Makan & Minum');
      expect(makan.wallet?.name, 'DANA');

      final gaji = QuickInputParser.parse('gaji 5jt bca', wallets);
      expect(gaji.kind, TransactionKind.income);
      expect(gaji.amount, 5000000);
      expect(gaji.category, 'Gaji');
      expect(gaji.wallet?.name, 'BCA');
    });

    test('extracts merchant, total, and category from OCR receipt text', () {
      const sampleIndomaret = '''
        SELAMAT DATANG
        PT. INDOMARCO PRISMATAMA
        JL. JEND SUDIRMAN NO 12
        NPWP 01.337.994.6-092.000
        25/11/2026 14:22 KASIR: RINA
        ROTI TAWAR         16.500
        SUSU UHT 1L        21.000
        DETERJEN CAIR      27.000
        -------------------------
        HARGA JUAL         64.500
        DISKON             -4.500
        TOTAL              60.000
        TUNAI             100.000
        KEMBALI            40.000
        CALL CENTER 1500280
      ''';
      final parsed = ReceiptOcrService.parseReceiptText(sampleIndomaret);
      expect(parsed.merchantName, 'Indomaret');
      expect(parsed.totalAmount, 60000);
      expect(parsed.suggestedCategory, 'Belanja');

      const sampleCafeSubtotalVsTotal = '''
        KOPI KENANGAN
        ES KOPI KENANGAN MANTAN    24.000
        CROISSANT BUTTER           21.000
        Subtotal                   45.000
        PB1 (10%)                   4.500
        Service (5%)                2.250
        Rounding                      250
        Total                      52.000
        QRIS                       52.000
      ''';
      final parsedCafe = ReceiptOcrService.parseReceiptText(
        sampleCafeSubtotalVsTotal,
      );
      expect(parsedCafe.merchantName, 'Kopi Kenangan');
      expect(parsedCafe.totalAmount, 52000);
      expect(parsedCafe.suggestedCategory, 'Ngopi');

      const sampleSmudgedCashMath = '''
        PT SUMBER ALFARIA TRIJAYA TBK
        TELP 021-1500959
        TOTAL ITEM 3
        TUNAI 50. 000
        KEMBALI 12. 5OO
      ''';
      final parsedAlfa = ReceiptOcrService.parseReceiptText(
        sampleSmudgedCashMath,
      );
      expect(parsedAlfa.merchantName, 'Alfamart');
      expect(parsedAlfa.totalAmount, 37500);
    });

    test('reconstructs two-column MLKit bounding boxes into accurate visual rows', () {
      TextLine makeLine(String text, double left, double top, double right) {
        final rect = Rect.fromLTRB(left, top, right, top + 24);
        return TextLine(
          text: text,
          elements: const <TextElement>[],
          boundingBox: rect,
          recognizedLanguages: const <String>['id'],
          cornerPoints: <Point<int>>[
            Point<int>(left.toInt(), top.toInt()),
            Point<int>(right.toInt(), top.toInt()),
            Point<int>(right.toInt(), (top + 24).toInt()),
            Point<int>(left.toInt(), (top + 24).toInt()),
          ],
          confidence: 0.99,
          angle: 0,
        );
      }

      // Simulates MLKit returning all left-column labels in block 1 and all
      // right-column prices in block 2 (the classic thermal receipt failure).
      final leftBlock = TextBlock(
        text: 'PT INDOMARCO PRISMATAMA\nHARGA JUAL\nDISKON\nTOTAL\nTUNAI\nKEMBALI',
        lines: <TextLine>[
          makeLine('PT INDOMARCO PRISMATAMA', 40, 20, 420),
          makeLine('HARGA JUAL', 40, 200, 220),
          makeLine('DISKON', 40, 235, 180),
          makeLine('TOTAL', 40, 270, 160),
          makeLine('TUNAI', 40, 305, 160),
          makeLine('KEMBALI', 40, 340, 180),
        ],
        boundingBox: const Rect.fromLTRB(40, 20, 420, 364),
        recognizedLanguages: const <String>['id'],
        cornerPoints: const <Point<int>>[],
      );

      final rightBlock = TextBlock(
        text: '45.500\n-3.000\n42.500\n50.000\n7.500',
        lines: <TextLine>[
          makeLine('45.500', 500, 202, 620),
          makeLine('-3.000', 500, 236, 620),
          makeLine('42.500', 500, 272, 620),
          makeLine('50.000', 500, 306, 620),
          makeLine('7.500', 500, 341, 620),
        ],
        boundingBox: const Rect.fromLTRB(500, 202, 620, 365),
        recognizedLanguages: const <String>['id'],
        cornerPoints: const <Point<int>>[],
      );

      final recognized = RecognizedText(
        text: '${leftBlock.text}\n${rightBlock.text}',
        blocks: <TextBlock>[leftBlock, rightBlock],
      );

      final result = ReceiptOcrService.parseRecognizedText(recognized);
      expect(result.merchantName, 'Indomaret');
      expect(result.totalAmount, 42500);
      expect(result.reconstructedLines, contains('TOTAL  42.500'));
    });

    test('parses Bank Jago, SeaBank, and DANA digital transfer receipts without grabbing phone or account numbers', () {
      const bankJagoToDana = '''
Jago
Transaksi Berhasil
26 Nov 2026, 19:10 WIB
-Rp50.000
Penerima
Budi Santoso
DANA
0812-3456-7890
Dari Kantong
Kantong Utama
1029 3847 5612
Biaya Admin Rp0
ID Transaksi JAGO202611260001234
''';
      final jagoRes = ReceiptOcrService.parseReceiptText(bankJagoToDana);
      expect(jagoRes.totalAmount, 50000);
      expect(jagoRes.merchantName, 'Budi Santoso');

      const bankJagoWithPlus62AndFee = '''
Bank Jago
Transfer Berhasil
Penerima
Kopi Kenangan
GoPay +62 857 1234 5678
Nominal Transfer Rp75.000
Biaya Admin Rp2.500
Total Transaksi Rp77.500
No Referensi 908877665544
''';
      final jagoRes2 = ReceiptOcrService.parseReceiptText(
        bankJagoWithPlus62AndFee,
      );
      expect(jagoRes2.totalAmount, 77500);
      expect(jagoRes2.merchantName, 'Kopi Kenangan');

      const danaReceiptWithDroppedZero = '''
DANA
Pembayaran Berhasil
- Rp 125.000
Dikirim ke
Warung Sate Madura
812-3456-7890
6281234567890
Biaya Admin Rp2.500
''';
      final danaRes = ReceiptOcrService.parseReceiptText(
        danaReceiptWithDroppedZero,
      );
      expect(danaRes.totalAmount, 125000);
      expect(danaRes.merchantName, 'Warung Sate Madura');
      expect(danaRes.detectedWalletName, 'DANA');
      expect(danaRes.suggestedCategory, 'Makan & Minum');
      expect(danaRes.receiptDetailText, contains('Sumber: DANA'));
    });

    test('extracts itemized store rows, e-wallet transfer notes, wallet source, and smart categories', () {
      const storeReceipt = '''
TOKO BERKAH JAYA
27/11/2026 14:20
Es Kopi Susu Gula Aren    24.000
Caramel Macchiato 2x      56.000
Croissant Butter          22.000
SUBTOTAL                 102.000
TOTAL                    102.000
QRIS                     102.000
''';
      final storeRes = ReceiptOcrService.parseReceiptText(storeReceipt);
      expect(storeRes.totalAmount, 102000);
      expect(storeRes.items.length, 3);
      expect(storeRes.items.first.name, 'Es Kopi Susu Gula Aren');
      expect(storeRes.items.first.price, 24000);
      expect(storeRes.paymentMethod, 'QRIS');
      expect(storeRes.suggestedCategory, 'Ngopi');
      expect(storeRes.receiptDate, DateTime(2026, 11, 27, 14, 20));
      expect(storeRes.receiptDetailText, contains('Es Kopi Susu Gula Aren'));
      expect(storeRes.receiptDetailText, contains('Sumber: QRIS'));

      const ewalletRentReceipt = '''
Bank Jago
Transfer Berhasil
27 Nov 2026, 08:15 WIB
-Rp1.500.000
Penerima
Ibu Ratna
BCA 1234567890
Catatan: Bayar kos bulan November
Biaya Admin Rp2.500
Metode BI-FAST
''';
      final rentRes = ReceiptOcrService.parseReceiptText(ewalletRentReceipt);
      expect(rentRes.totalAmount, 1500000);
      expect(rentRes.detectedWalletName, 'Bank Jago');
      expect(rentRes.transferNote, 'Bayar kos bulan November');
      expect(rentRes.adminFee, 2500);
      expect(rentRes.receiptDate, DateTime(2026, 11, 27, 8, 15));
      expect(rentRes.suggestedKind, TransactionKind.expense);
      expect(rentRes.suggestedCategory, 'Tagihan & Utilitas');
      expect(rentRes.receiptDetailText, contains('Catatan resi: Bayar kos bulan November'));

      expect(ReceiptOcrService.classifyNoteCategory('Indomaret'), 'Belanja');
      expect(
        ReceiptOcrService.classifyNoteCategory('Bayar kos bulanan'),
        'Tagihan & Utilitas',
      );
      expect(
        ReceiptOcrService.classifyNoteCategory(
          'Gaji bulanan',
          kind: TransactionKind.income,
        ),
        'Gaji',
      );

      const incomingReceipt = '''
SeaBank
Transfer Masuk Berhasil
+Rp2.500.000
Dari
PT Karya Digital
Catatan: Pembayaran proyek desain freelance
''';
      final incomeRes = ReceiptOcrService.parseReceiptText(incomingReceipt);
      expect(incomeRes.totalAmount, 2500000);
      expect(incomeRes.detectedWalletName, 'SeaBank');
      expect(incomeRes.suggestedKind, TransactionKind.income);
      expect(incomeRes.suggestedCategory, 'Bisnis & Freelance');
    });
  });

  group('FinanceController Stage 1, 2 & 3 business logic', () {
    test('Safe-to-Spend, Goals, Bills, Debts, Analytics, Excel, and JSON Backup/Restore work end-to-end', () async {
      final controller = FinanceController(
        customStore: InMemorySakuStore(),
        clock: () => DateTime(2026, 11, 25, 10),
      );
      await controller.initialize();

      final bca = controller.wallets.firstWhere((w) => w.name == 'BCA');

      // Previous month transaction for MoM comparison.
      await controller.addTransaction(
        TransactionModel(
          kind: TransactionKind.expense,
          amount: 1000000,
          category: 'Belanja',
          note: 'Belanja Oktober',
          walletId: bca.id!,
          transactionDate: DateTime(2026, 10, 15, 10),
          createdAt: DateTime(2026, 10, 15, 10),
        ),
      );

      // Current month income & expenses.
      await controller.addTransaction(
        TransactionModel(
          kind: TransactionKind.income,
          amount: 6000000,
          category: 'Gaji',
          note: 'Gaji November',
          walletId: bca.id!,
          transactionDate: DateTime(2026, 11, 1, 9),
          createdAt: DateTime(2026, 11, 1, 9),
        ),
      );
      await controller.addTransaction(
        TransactionModel(
          kind: TransactionKind.expense,
          amount: 800000,
          category: 'Makan & Minum',
          note: 'Makan bulan ini',
          walletId: bca.id!,
          transactionDate: DateTime(2026, 11, 10, 12),
          createdAt: DateTime(2026, 11, 10, 12),
          receiptDetail:
              'Metode: QRIS\nRincian item:\n- Ayam Bakar · Rp 45.000\n- Es Teh Manis · Rp 8.000',
        ),
      );

      final report = controller.buildMonthlyReport(DateTime(2026, 11));
      expect(report.totalIncome, 6000000);
      expect(report.totalExpense, 800000);
      expect(report.previousMonthExpense, 1000000);
      expect(report.expenseDeltaPercent, closeTo(-20.0, 0.01));
      expect(report.categorySlices.first.category, 'Makan & Minum');
      expect(report.insights.length, greaterThanOrEqualTo(3));

      // Excel workbook bytes check (valid ZIP/XLSX signature PK = 0x50, 0x4B).
      final xlsxBytes = ExportBackupService.buildMonthlyExcelBytes(
        month: DateTime(2026, 11),
        monthTransactions: report.transactions,
        wallets: controller.wallets,
        netWorth: controller.netWorth,
      );
      expect(xlsxBytes.length, greaterThan(500));
      expect(xlsxBytes[0], 0x50);
      expect(xlsxBytes[1], 0x4B);

      // Add Stage 2 entities before JSON backup.
      await controller.addGoal(name: 'Dana Darurat', targetAmount: 10000000);
      await controller.addBill(
        name: 'Internet',
        amount: 300000,
        category: 'Tagihan & Utilitas',
        dueDay: 20,
      );
      await controller.addDebt(
        personName: 'Raka',
        phone: '08123456789',
        kind: DebtKind.receivable,
        principalAmount: 400000,
      );
      expect(
        WhatsAppHelper.buildReminderUri(controller.debts.first).path,
        '/628123456789',
      );

      // Backup to JSON and restore into a brand new controller.
      final snapshot = await controller.createBackupSnapshot();
      final backupJson = ExportBackupService.encodeBackupJson(snapshot);

      final freshController = FinanceController(
        customStore: InMemorySakuStore(),
        clock: () => DateTime(2026, 11, 25, 10),
      );
      await freshController.initialize();
      expect(freshController.transactions, isEmpty);

      await freshController.restoreFromBackupJson(backupJson);
      expect(freshController.transactions.length, 3);
      expect(
        freshController.transactions
            .firstWhere((t) => t.note == 'Makan bulan ini')
            .receiptDetail,
        contains('Ayam Bakar'),
      );
      expect(freshController.goals.length, 1);
      expect(freshController.bills.length, 1);
      expect(freshController.debts.length, 1);
      expect(freshController.netWorth, controller.netWorth);

      // Backward compatibility check for v2 transaction rows without receipt columns.
      final legacyTx = TransactionModel.fromMap(<String, Object?>{
        'id': 99,
        'type': 'expense',
        'amount': 25000,
        'category': 'Ngopi',
        'note': 'Kopi lama',
        'wallet_id': 1,
        'transaction_date': DateTime(2026, 11, 1).toIso8601String(),
        'created_at': DateTime(2026, 11, 1).toIso8601String(),
      });
      expect(legacyTx.receiptDetail, isEmpty);
      expect(legacyTx.receiptImagePath, isEmpty);
      expect(legacyTx.hasReceiptInfo, isFalse);
    });
  });

  testWidgets('SakuPro UI drives Quick NLP, Plan tabs, Analytics, and PIN Lock', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = FinanceController(
      customStore: InMemorySakuStore(),
      clock: () => DateTime(2026, 11, 25, 12),
    );
    await controller.initialize();

    await tester.pumpWidget(SakuProApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Catat Transaksi Cepat'));
    await tester.pumpAndSettle();
    expect(find.text('Scan Struk'), findsAtLeastNWidgets(1));

    await tester.enterText(find.byType(TextField).first, 'kopi 22rb gopay');
    await tester.pumpAndSettle();
    final saveButton = find.textContaining('Simpan Pengeluaran');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(controller.monthlyExpense, 22000);

    // Navigate to Analitik tab and verify insights + Excel export button.
    await tester.tap(find.text('Analitik'));
    await tester.pumpAndSettle();
    expect(find.text('Insight Otomatis'), findsOneWidget);
    expect(find.text('Export Excel (.xlsx)'), findsOneWidget);

    // Enable 4-digit PIN lock and verify lock/unlock cycle.
    await controller.enableAppLock(pin: '2580', useBiometric: false);
    controller.lockSessionNow();
    await tester.pumpAndSettle();

    expect(find.text('SakuProWann Terkunci'), findsOneWidget);

    await tester.tap(find.text('1'));
    await tester.tap(find.text('1'));
    await tester.tap(find.text('1'));
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('PIN salah, silakan coba kembali.'), findsOneWidget);

    await tester.tap(find.text('2'));
    await tester.tap(find.text('5'));
    await tester.tap(find.text('8'));
    await tester.tap(find.text('0'));
    await tester.pumpAndSettle();

    expect(find.text('SakuProWann Terkunci'), findsNothing);
    expect(find.text('Insight Otomatis'), findsOneWidget);
  });

  testWidgets('Tapping receipt transaction opens TransactionDetailSheet cleanly at 360dp and 1.3x text scale', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final controller = FinanceController(
      customStore: InMemorySakuStore(),
      clock: () => DateTime(2026, 11, 27, 13, 15),
    );
    await controller.initialize();
    final gopay = controller.wallets.firstWhere((w) => w.name == 'GoPay');

    await controller.addTransaction(
      TransactionModel(
        kind: TransactionKind.expense,
        amount: 60000,
        category: 'Belanja',
        note: 'Indomaret',
        walletId: gopay.id!,
        transactionDate: DateTime(2026, 11, 27, 13, 10),
        createdAt: DateTime(2026, 11, 27, 13, 10),
        receiptDetail:
            'Metode: QRIS\nRincian item:\n- Roti Tawar · Rp 16.500\n- Susu UHT 1L · Rp 21.500\n- Kopi Botol · Rp 22.000',
      ),
    );

    await tester.pumpWidget(SakuProApp(controller: controller));
    await tester.pumpAndSettle();

    final tileFinder = find.text('Indomaret');
    await tester.scrollUntilVisible(
      tileFinder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(tileFinder);
    await tester.pumpAndSettle();

    expect(find.text('Rincian'), findsOneWidget);
    await tester.tap(tileFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Rincian Struk & Resi'), findsOneWidget);
    expect(find.text('Roti Tawar'), findsOneWidget);
    expect(find.text('Susu UHT 1L'), findsOneWidget);
    expect(find.text('Salin'), findsOneWidget);
    expect(find.text('Ubah'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('v1.7.0: duplicate detection, wallet mutation, and Analytics category drill-down work cleanly', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = FinanceController(
      customStore: InMemorySakuStore(),
      clock: () => DateTime(2026, 11, 27, 14, 0),
    );
    await controller.initialize();
    final gopay = controller.wallets.firstWhere((w) => w.name == 'GoPay');
    final bca = controller.wallets.firstWhere((w) => w.name == 'BCA');

    await controller.addTransaction(
      TransactionModel(
        kind: TransactionKind.expense,
        amount: 60000,
        category: 'Belanja',
        note: 'Indomaret',
        walletId: gopay.id!,
        transactionDate: DateTime(2026, 11, 27, 13, 30),
        createdAt: DateTime(2026, 11, 27, 13, 30),
      ),
    );
    await controller.addTransaction(
      TransactionModel(
        kind: TransactionKind.expense,
        amount: 35000,
        category: 'Makan & Minum',
        note: 'Ayam Geprek',
        walletId: bca.id!,
        transactionDate: DateTime(2026, 11, 26, 12, 0),
        createdAt: DateTime(2026, 11, 26, 12, 0),
      ),
    );

    // Duplicate detector catches same-day / matching merchant+amount, ignores distinct entries.
    final dup = controller.findPotentialDuplicate(
      kind: TransactionKind.expense,
      amount: 60000,
      date: DateTime(2026, 11, 27, 14, 0),
      note: 'Indomaret',
    );
    expect(dup, isNotNull);
    expect(dup!.note, 'Indomaret');
    expect(
      controller.findPotentialDuplicate(
        kind: TransactionKind.expense,
        amount: 99000,
        date: DateTime(2026, 11, 27, 14, 0),
        note: 'Indomaret',
      ),
      isNull,
    );

    await tester.pumpWidget(SakuProApp(controller: controller));
    await tester.pumpAndSettle();

    // 1. Open Dompet tab and tap GoPay mutation icon.
    await tester.tap(find.text('Dompet'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lihat mutasi GoPay'));
    await tester.pumpAndSettle();

    expect(find.text('Mutasi GoPay (1)'), findsOneWidget);
    expect(find.text('Hari Ini'), findsOneWidget);
    expect(find.text('Indomaret'), findsOneWidget);
    expect(find.text('Ayam Geprek'), findsNothing);
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();

    // 2. Open Analitik tab and drill down into Belanja category slice.
    await tester.tap(find.text('Analitik'));
    await tester.pumpAndSettle();
    final belanjaSlice = find.text('Belanja');
    await tester.scrollUntilVisible(
      belanjaSlice,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(belanjaSlice);
    await tester.pumpAndSettle();

    expect(find.text('Belanja · Nov 2026 (1)'), findsOneWidget);
    expect(find.text('Indomaret'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

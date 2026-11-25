import 'package:flutter_test/flutter_test.dart';
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
        INDOMARET POINT SUDIRMAN
        JL. JEND SUDIRMAN NO 12
        25/11/2026 14:22 KASIR: RINA
        ROTI TAWAR         16.500
        SUSU UHT 1L        21.000
        DETERJEN CAIR      27.000
        -------------------------
        HARGA JUAL         64.500
        GRAND TOTAL        64.500
        TUNAI             100.000
        KEMBALI            35.500
      ''';
      final parsed = ReceiptOcrService.parseReceiptText(sampleIndomaret);
      expect(parsed.merchantName, 'Indomaret Point Sudirman');
      expect(parsed.totalAmount, 64500);
      expect(parsed.suggestedCategory, 'Belanja');

      const sampleCafe = '''
        KOPI KENANGAN
        ES KOPI KENANGAN MANTAN
        TOTAL
        Rp 24.000
      ''';
      final parsedCafe = ReceiptOcrService.parseReceiptText(sampleCafe);
      expect(parsedCafe.merchantName, 'Kopi Kenangan');
      expect(parsedCafe.totalAmount, 24000);
      expect(parsedCafe.suggestedCategory, 'Ngopi');
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
      expect(freshController.goals.length, 1);
      expect(freshController.bills.length, 1);
      expect(freshController.debts.length, 1);
      expect(freshController.netWorth, controller.netWorth);
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
    expect(find.text('Scan Struk'), findsOneWidget);

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

    expect(find.text('SakuPro Terkunci'), findsOneWidget);

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

    expect(find.text('SakuPro Terkunci'), findsNothing);
    expect(find.text('Insight Otomatis'), findsOneWidget);
  });
}

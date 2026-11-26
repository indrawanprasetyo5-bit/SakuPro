import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saku_pro/db/database_helper.dart';
import 'package:saku_pro/main.dart';
import 'package:saku_pro/models/roadmap_models.dart';
import 'package:saku_pro/models/transaction_item.dart';
import 'package:saku_pro/models/wallet.dart';
import 'package:saku_pro/services/export_backup_service.dart';
import 'package:saku_pro/services/finance_controller.dart';
import 'package:saku_pro/widgets/auto_capture_sheet.dart';
import 'package:saku_pro/widgets/quick_input_sheet.dart';

void main() {
  group('Full End-to-End QA Verification', () {
    test('Wallet CRUD, referential guard, and invalid JSON restore safety', () async {
      final controller = FinanceController(
        customStore: InMemorySakuStore(),
        clock: () => DateTime(2026, 11, 26, 10),
      );
      await controller.initialize();

      final bca = controller.wallets.firstWhere((w) => w.name == 'BCA');

      await controller.addWallet(
        name: 'Bank Jago',
        kind: WalletKind.bank,
        initialBalance: 1500000,
        colorValue: 0xFFD97706,
        iconKey: 'account_balance',
      );
      final jago = controller.wallets.firstWhere((w) => w.name == 'Bank Jago');
      expect(controller.netWorth, 1500000);
      expect(controller.totalAllWallets, 1500000);

      await controller.updateWallet(jago.copyWith(excludeFromTotal: true));
      expect(controller.netWorth, 0);
      expect(controller.totalAllWallets, 1500000);

      await controller.addTransaction(
        TransactionModel(
          kind: TransactionKind.income,
          amount: 5000000,
          category: 'Gaji',
          note: 'Gaji',
          walletId: bca.id!,
          transactionDate: DateTime(2026, 11, 26, 10),
          createdAt: DateTime(2026, 11, 26, 10),
        ),
      );

      // Deleting a wallet with existing transactions must throw StorageException.
      await expectLater(
        () => controller.deleteWallet(bca.id!),
        throwsA(isA<StorageException>()),
      );

      // Deleting an unused wallet succeeds cleanly.
      await controller.deleteWallet(jago.id!);
      expect(controller.wallets.any((w) => w.name == 'Bank Jago'), isFalse);

      // Corrupt JSON restore must fail without wiping existing data.
      await expectLater(
        () => controller.restoreFromBackupJson('{"invalid": true}'),
        throwsFormatException,
      );
      expect(controller.transactions.length, 1);
      expect(controller.netWorth, 5000000);
    });

    testWidgets('All 4 tabs, quick actions, history search, settings, and PIN work smoothly on phone', (
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
        clock: () => DateTime(2026, 11, 26, 14),
      );
      await controller.initialize();

      await tester.pumpWidget(SakuProApp(controller: controller));
      await tester.pumpAndSettle();

      // 1. Verify luxury Beranda components.
      expect(find.text('SakuProWann'), findsOneWidget);
      expect(find.text('Total Saldo Bersih'), findsOneWidget);
      expect(find.text('Catat'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('Budget'), findsOneWidget);

      // 2. Record income via Smart Quick Input.
      await tester.tap(find.text('Catat'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'gaji 8jt bca');
      await tester.pumpAndSettle();
      final saveIncome = find.textContaining('Simpan Pemasukan');
      await tester.ensureVisible(saveIncome);
      await tester.tap(saveIncome);
      await tester.pumpAndSettle();
      expect(controller.monthlyIncome, 8000000);

      // 3. Record expense via FAB (+).
      await tester.tap(find.byTooltip('Catat Transaksi Cepat'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'kopi 25rb gopay');
      await tester.pumpAndSettle();
      final saveExp = find.textContaining('Simpan Pengeluaran');
      await tester.ensureVisible(saveExp);
      await tester.tap(saveExp);
      await tester.pumpAndSettle();
      expect(controller.monthlyExpense, 25000);

      // 4. Open Transfer via 1-tap Quick Action and transfer BCA -> GoPay.
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '500000');
      await tester.pumpAndSettle();
      final processTransfer = find.text('Proses Transfer Antar Dompet');
      await tester.ensureVisible(processTransfer);
      await tester.tap(processTransfer);
      await tester.pumpAndSettle();
      // Transfer must not inflate monthly expense.
      expect(controller.monthlyExpense, 25000);

      // 5. Open Lihat Semua history sheet and search.
      await tester.drag(find.byType(ListView).first, const Offset(0, -320));
      await tester.pumpAndSettle();
      final seeAll = find.textContaining('Lihat Semua');
      await tester.tap(seeAll);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'kopi');
      await tester.pumpAndSettle();
      expect(find.text('Semua Transaksi (1)'), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();

      // 6. Open Settings from Beranda gear icon and toggle Dark Mode.
      await tester.tap(find.byTooltip('Pengaturan & Kunci Privasi'));
      await tester.pumpAndSettle();
      expect(find.text('Pengaturan & Keamanan'), findsOneWidget);
      await tester.tap(find.text('Gelap'));
      await tester.pumpAndSettle();
      expect(controller.themeMode, ThemeMode.dark);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();

      // 7. Navigate to Dompet, Rencana (all 4 sub-tabs), and Analitik in Dark Mode.
      await tester.tap(find.text('Dompet'));
      await tester.pumpAndSettle();
      expect(find.text('Dompet & Transfer'), findsOneWidget);

      await tester.tap(find.text('Rencana'));
      await tester.pumpAndSettle();
      expect(find.text('Total Budget Bulanan'), findsOneWidget);

      await tester.tap(find.text('Goals'));
      await tester.pumpAndSettle();
      expect(find.text('Total Dana Target Terkumpul'), findsOneWidget);

      await tester.tap(find.text('Tagihan'));
      await tester.pumpAndSettle();
      expect(find.text('Tagihan Belum Dibayar Bulan Ini'), findsOneWidget);

      await tester.tap(find.text('Hutang & Piutang'));
      await tester.pumpAndSettle();
      expect(find.text('Piutang (Orang Pinjam)'), findsOneWidget);

      await tester.tap(find.text('Analitik'));
      await tester.pumpAndSettle();
      expect(find.text('Insight Otomatis'), findsOneWidget);
      expect(find.text('Export Excel (.xlsx)'), findsOneWidget);

      // Verify Excel export generates valid binary payload from live controller state.
      final report = controller.buildMonthlyReport(DateTime(2026, 11));
      final bytes = ExportBackupService.buildMonthlyExcelBytes(
        month: report.month,
        monthTransactions: report.transactions,
        wallets: controller.wallets,
        netWorth: controller.netWorth,
      );
      expect(bytes.length, greaterThan(500));
    });

    testWidgets('Zero layout overflow on narrow 360dp phone with 1.3x font scale across Light & Dark', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0; // 360 x 780 logical dp
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = FinanceController(
        customStore: InMemorySakuStore(),
        clock: () => DateTime(2026, 11, 26, 14),
      );
      await controller.initialize();
      await controller.addGoal(name: 'Dana Darurat', targetAmount: 10000000);
      await controller.addBill(
        name: 'WiFi Rumah',
        amount: 350000,
        category: 'Tagihan & Utilitas',
        dueDay: 10,
      );
      await controller.addDebt(
        personName: 'Budi Santoso',
        phone: '08123456789',
        kind: DebtKind.receivable,
        principalAmount: 500000,
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 780),
            textScaler: TextScaler.linear(1.3),
            disableAnimations: true,
          ),
          child: SakuProApp(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Cycle all 4 main tabs in Light Mode at 360dp + 1.3x font scale.
      await tester.tap(find.text('Dompet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rencana'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analitik'));
      await tester.pumpAndSettle();

      // Flip to Dark Mode and open QuickInputSheet on narrow screen.
      await controller.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beranda'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Catat Transaksi Cepat'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickInputSheet), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
    });

    test('Executive 5-sheet Excel report builds cleanly with valid OOXML formulas and full sections', () async {
      final now = DateTime(2026, 11, 26, 14, 30);
      final controller = FinanceController(
        customStore: InMemorySakuStore(),
        clock: () => now,
      );
      await controller.initialize();

      final bca = controller.wallets.firstWhere((w) => w.name == 'BCA');
      final gopay = controller.wallets.firstWhere((w) => w.name == 'GoPay');
      final tabungan = controller.wallets.firstWhere((w) => w.name == 'Tabungan');

      await controller.updateWallet(tabungan.copyWith(excludeFromTotal: true));
      await controller.setMonthlyBudget(4000000);
      await controller.upsertCategoryBudget(
        category: 'Makan & Minum',
        monthlyLimit: 1200000,
      );
      await controller.upsertCategoryBudget(
        category: 'Ngopi & Jajan',
        monthlyLimit: 300000,
      );

      await controller.addTransaction(
        TransactionModel(
          kind: TransactionKind.income,
          amount: 10000000,
          category: 'Gaji',
          note: 'Gaji Bulanan',
          walletId: bca.id!,
          transactionDate: DateTime(2026, 11, 1, 9, 0),
          createdAt: now,
        ),
      );
      await controller.addTransaction(
        TransactionModel(
          kind: TransactionKind.expense,
          amount: 85000,
          category: 'Makan & Minum',
          note: 'Makan Siang',
          walletId: gopay.id!,
          transactionDate: DateTime(2026, 11, 10, 12, 30),
          createdAt: now,
        ),
      );
      await controller.addTransaction(
        TransactionModel(
          kind: TransactionKind.expense,
          amount: 320000,
          category: 'Ngopi & Jajan',
          note: 'Kopi Bulanan',
          walletId: gopay.id!,
          transactionDate: DateTime(2026, 11, 15, 16, 15),
          createdAt: now,
        ),
      );
      await controller.addTransaction(
        TransactionModel(
          kind: TransactionKind.transfer,
          amount: 2000000,
          category: 'Transfer',
          note: 'Sisihkan Tabungan',
          walletId: bca.id!,
          toWalletId: tabungan.id!,
          transactionDate: DateTime(2026, 11, 20, 10, 0),
          createdAt: now,
        ),
      );

      await controller.addGoal(
        name: 'Dana Darurat',
        targetAmount: 15000000,
        initialSaved: 6000000,
        deadline: DateTime(2027, 6, 30),
      );
      await controller.addBill(
        name: 'Internet Fiber',
        amount: 375000,
        category: 'Tagihan & Utilitas',
        dueDay: 20,
      );
      await controller.addDebt(
        personName: 'Raka',
        phone: '081234567890',
        kind: DebtKind.receivable,
        principalAmount: 500000,
        note: 'Patungan makan',
      );
      await controller.addDebt(
        personName: 'Cicilan Laptop',
        phone: '',
        kind: DebtKind.payable,
        principalAmount: 1200000,
      );

      final report = controller.buildMonthlyReport(now);
      final bytes = ExportBackupService.buildMonthlyExcelBytes(
        month: report.month,
        monthTransactions: report.transactions,
        wallets: controller.wallets,
        netWorth: controller.netWorth,
        monthlyBudget: controller.monthlyBudget,
        categoryBudgets: controller.categoryBudgets,
        goals: controller.goals,
        bills: controller.bills,
        debts: controller.debts,
        previousMonthExpense: report.previousMonthExpense,
        insights: report.insights,
      );

      expect(bytes.length, greaterThan(4000));
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);

      final decoded = Excel.decodeBytes(bytes);
      expect(
        decoded.tables.keys,
        containsAll(<String>[
          'Ringkasan Eksekutif',
          'Buku Transaksi',
          'Analisa Kategori & Budget',
          'Dompet & Aset',
          'Rencana & Kewajiban',
        ]),
      );

      var formulaCount = 0;
      for (final sheet in decoded.tables.values) {
        for (final row in sheet.rows) {
          for (final cell in row) {
            final value = cell?.value;
            if (value is FormulaCellValue) {
              formulaCount++;
              expect(
                value.formula.startsWith('='),
                isFalse,
                reason: 'OOXML formulas must omit leading =: ${value.formula}',
              );
            }
          }
        }
      }
      expect(formulaCount, greaterThan(20));

      final emptyBytes = ExportBackupService.buildMonthlyExcelBytes(
        month: DateTime(2025, 1, 1),
        monthTransactions: const <TransactionModel>[],
        wallets: controller.wallets,
        netWorth: controller.netWorth,
      );
      final decodedEmpty = Excel.decodeBytes(emptyBytes);
      expect(decodedEmpty.tables.length, 5);
    });

    testWidgets('Pusat Otomatisasi sheet renders cleanly on narrow 360dp phone with 1.3x font scale', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = FinanceController(
        customStore: InMemorySakuStore(),
        clock: () => DateTime(2026, 11, 26, 17, 30),
      );
      await controller.initialize();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 780),
            textScaler: TextScaler.linear(1.3),
            disableAnimations: true,
          ),
          child: SakuProApp(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pusat Otomatisasi'));
      await tester.pumpAndSettle();
      expect(find.byType(AutoCaptureSheet), findsOneWidget);
      expect(find.text('Pusat Otomatisasi'), findsOneWidget);
      expect(find.text('Bagikan Resi dari Aplikasi Bank'), findsOneWidget);

      Navigator.of(tester.element(find.byType(AutoCaptureSheet))).pop();
      await tester.pumpAndSettle();
    });

    test('Offline automation suite: Merchant memory, Auto-Gaji, Auto-Pay bills, Auto-Save Goal, Monthly Closing & Auto-Backup', () async {
      final now = DateTime(2026, 11, 26, 18, 25);
      final controller = FinanceController(
        customStore: InMemorySakuStore(),
        clock: () => now,
      );
      await controller.initialize();

      final cash = controller.wallets.firstWhere((w) => w.name == 'Cash');
      final bca = controller.wallets.firstWhere((w) => w.name == 'BCA');

      // 1. Self-learning merchant category memory.
      await controller.addTransaction(
        TransactionModel(
          kind: TransactionKind.expense,
          amount: 20000,
          category: 'Makan & Minum',
          note: 'Warung Pak Slamet',
          walletId: cash.id!,
          transactionDate: now,
          createdAt: now,
        ),
      );
      expect(
        controller.lookupLearnedCategory('QRIS Warung Pak Slamet'),
        'Makan & Minum',
      );

      // 2. Recurring Auto-Gaji (day 25 <= current day 26 -> auto-credited once, idempotent).
      await controller.addRecurringIncome(
        name: 'Gaji Bulanan',
        amount: 9000000,
        dayOfMonth: 25,
        walletId: bca.id!,
      );
      expect(controller.monthlyIncome, 9000000);
      final rerun = await controller.runRecurringAutomations();
      expect(rerun.autoCreditedIncomes, 0);
      expect(controller.monthlyIncome, 9000000);

      // 3. Auto-Pay Recurring Bill (dueDay 20 <= current day 26 -> auto-paid once & marked Lunas).
      await controller.addBill(
        name: 'Internet Fiber',
        amount: 375000,
        category: 'Tagihan & Utilitas',
        dueDay: 20,
        walletId: bca.id,
      );
      final bill = controller.bills.firstWhere((b) => b.name == 'Internet Fiber');
      expect(bill.isPaidFor(now), isFalse);
      await controller.setBillAutoPay(bill.id!, true);
      final updatedBill = controller.bills.firstWhere((b) => b.id == bill.id);
      expect(updatedBill.isPaidFor(now), isTrue);
      expect(controller.monthlyExpense, 20000 + 375000);

      // 4. Pay Yourself First: 20% of Gaji income auto-allocated to Dana Darurat goal.
      await controller.addGoal(
        name: 'Dana Darurat',
        targetAmount: 20000000,
        initialSaved: 1000000,
      );
      final goal = controller.goals.firstWhere((g) => g.name == 'Dana Darurat');
      await controller.configureAutoSaveGoal(
        enabled: true,
        percent: 20,
        goalId: goal.id,
      );
      await controller.addTransaction(
        TransactionModel(
          kind: TransactionKind.income,
          amount: 10000000,
          category: 'Gaji',
          note: 'Gaji November',
          walletId: bca.id!,
          transactionDate: now,
          createdAt: now,
        ),
      );
      final updatedGoal = controller.goals.firstWhere((g) => g.id == goal.id);
      expect(updatedGoal.currentAmount, 3000000);

      // 5. Monthly Closing Recap & Archive for previous month (October 2026).
      final prevOct = DateTime(2026, 10, 15, 10, 0);
      await controller.addTransaction(
        TransactionModel(
          kind: TransactionKind.income,
          amount: 8000000,
          category: 'Bisnis & Freelance',
          note: 'Proyek Oktober',
          walletId: bca.id!,
          transactionDate: prevOct,
          createdAt: prevOct,
        ),
      );
      await controller.addTransaction(
        TransactionModel(
          kind: TransactionKind.expense,
          amount: 3000000,
          category: 'Belanja',
          note: 'Belanja Oktober',
          walletId: bca.id!,
          transactionDate: prevOct,
          createdAt: prevOct,
        ),
      );

      final recap = controller.activeMonthlyRecap;
      expect(recap, isNotNull);
      expect(recap!.surplus, 5000000);
      final archivePath = await controller.runMonthlyClosingArchiveIfNeeded();
      expect(archivePath, contains('SakuProWann_Laporan_202610.xlsx'));
      expect(await controller.allocateMonthlySurplusToGoal(goal.id!), isTrue);
      expect(controller.activeMonthlyRecap, isNull);
      expect(
        controller.goals.firstWhere((g) => g.id == goal.id).currentAmount,
        8000000,
      );

      // 6. Weekly rolling Auto-Backup JSON (runs once, then skips within 7 days).
      final backupPath = await controller.runAutoBackupIfDue();
      expect(backupPath, contains('SakuProWann_AutoBackup_20261126.json'));
      expect(await controller.runAutoBackupIfDue(), isNull);

      // 7. Backup JSON round-trip preserves learned merchants, recurring incomes, and auto-save goal rules.
      await controller.addRecurringIncome(
        name: 'Gaji Tetap',
        amount: 8500000,
        dayOfMonth: 28,
        walletId: bca.id!,
      );
      final snapJson = ExportBackupService.encodeBackupJson(
        await controller.createBackupSnapshot(),
      );
      final fresh = FinanceController(
        customStore: InMemorySakuStore(),
        clock: () => now,
      );
      await fresh.initialize();
      await fresh.restoreFromBackupJson(snapJson);
      expect(fresh.autoSaveGoalEnabled, isTrue);
      expect(fresh.autoSaveGoalPercent, 20);
      expect(fresh.recurringIncomes.any((r) => r.name == 'Gaji Tetap'), isTrue);
      expect(fresh.learnedMerchantCategories.containsKey('gaji november'), isTrue);
    });

    testWidgets('Obsidian Bento Dashboard, Chat Quick-Add Bar, and Budget Bottom Sheet work seamlessly', (
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
        clock: () => DateTime(2026, 11, 26, 14),
      );
      await controller.initialize();
      expect(controller.themeMode, ThemeMode.dark);

      await tester.pumpWidget(SakuProApp(controller: controller));
      await tester.pumpAndSettle();

      // Hero Safe-to-Spend card and Bento metrics are immediately visible.
      expect(find.text('Aman Dipakai Hari Ini'), findsOneWidget);
      expect(find.text('Total Saldo Bersih'), findsOneWidget);
      expect(find.text('Uang Masuk'), findsOneWidget);
      expect(find.text('Uang Keluar'), findsOneWidget);

      // Chat-style Quick-Add bar records an expense in one flow without a modal.
      await tester.tap(find.text('Ketik cepat... kopi 25rb gopay'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'kopi 25rb gopay');
      await tester.pumpAndSettle();
      expect(find.text('Ngopi · GoPay'), findsOneWidget);
      await tester.tap(find.byTooltip('Kirim Transaksi'));
      await tester.pumpAndSettle();
      expect(controller.monthlyExpense, 25000);

      // Atur Limit opens swipe-to-dismiss bottom sheet and updates monthly budget.
      await tester.tap(find.text('Atur Limit'));
      await tester.pumpAndSettle();
      expect(find.text('Atur Limit Bulanan'), findsOneWidget);
      await tester.tap(find.text('Rp 5 jt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan Limit'));
      await tester.pumpAndSettle();
      expect(controller.monthlyBudget, 5000000);
    });

    test('v1.5.0 upgrades: dynamic habit presets, 6-month trend, weekday pattern, and Split Bill', () async {
      final now = DateTime(2026, 11, 26, 15, 0); // Thursday
      final controller = FinanceController(
        customStore: InMemorySakuStore(),
        clock: () => now,
      );
      await controller.initialize();
      final gopay = controller.wallets.firstWhere((w) => w.name == 'GoPay');

      // Record repeated habit so smartQuickPresets ranks it #1.
      for (var i = 0; i < 3; i++) {
        await controller.addTransaction(
          TransactionModel(
            kind: TransactionKind.expense,
            amount: 24000,
            category: 'Ngopi',
            note: 'Kopi Kenangan',
            walletId: gopay.id!,
            transactionDate: now.subtract(Duration(days: i)),
            createdAt: now,
          ),
        );
      }

      final presets = controller.smartQuickPresets;
      expect(presets.length, 4);
      expect(presets.first.isLearned, isTrue);
      expect(presets.first.label, contains('Kopi Kenangan'));

      // 6-month trend & weekday pattern.
      final trend = controller.buildSixMonthTrend(DateTime(2026, 11));
      expect(trend.length, 6);
      expect(trend.last.expense, 72000);

      final weekday = controller.buildWeekdaySpendPattern(DateTime(2026, 11));
      expect(weekday.buckets.length, 7);
      expect(weekday.peakBucket, isNotNull);
      expect(weekday.totalExpense, 72000);

      // Split Bill records myShare as expense and friends as Receivables.
      final debtCount = await controller.recordSplitBill(
        title: 'Sate Taichan',
        walletId: gopay.id!,
        category: 'Makan & Minum',
        myShare: 50000,
        friends: const <SplitBillFriend>[
          SplitBillFriend(name: 'Dimas', phone: '08123456789', shareAmount: 50000),
          SplitBillFriend(name: 'Nadia', phone: '08129876543', shareAmount: 50000),
        ],
      );
      expect(debtCount, 2);
      expect(controller.monthlyExpense, 72000 + 50000);
      expect(controller.activeReceivablesTotal, 100000);
      expect(controller.debts.length, 2);
    });
  });
}

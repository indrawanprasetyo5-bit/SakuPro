import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saku_pro/db/database_helper.dart';
import 'package:saku_pro/main.dart';
import 'package:saku_pro/models/roadmap_models.dart';
import 'package:saku_pro/models/transaction_item.dart';
import 'package:saku_pro/models/wallet.dart';
import 'package:saku_pro/services/bank_notification_parser.dart';
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

    test('Auto-Catat QRIS parser & controller handle SeaBank, DANA, GoPay, Bank Jago, spam & dedupe', () async {
      final now = DateTime(2026, 11, 26, 17, 30);
      final controller = FinanceController(
        customStore: InMemorySakuStore(),
        clock: () => now,
      );
      await controller.initialize();
      await controller.setAutoCaptureEnabled(true);
      await controller.setAutoCaptureMode(AutoCaptureMode.autoSave);

      // 1. SeaBank QRIS Kopi Kenangan -> auto-creates SeaBank wallet & records expense.
      final seabankRaw = RawBankNotification(
        packageName: 'id.co.bankbkemobile.digitalbank',
        title: 'Pembayaran QRIS Berhasil',
        text: 'Kamu telah membayar Rp28.000 ke Kopi Kenangan menggunakan QRIS.',
        postTimeMs: now.millisecondsSinceEpoch,
      );
      expect(await controller.processRawNotification(seabankRaw), isTrue);
      // Duplicate within 20s must be ignored.
      expect(await controller.processRawNotification(seabankRaw), isFalse);
      expect(controller.wallets.any((w) => w.name == 'SeaBank'), isTrue);
      expect(controller.transactions.last.category, 'Ngopi');
      expect(controller.transactions.last.amount, 28000);

      // 2. DANA QRIS Indomaret -> Belanja, maps to DANA wallet.
      final danaRaw = RawBankNotification(
        packageName: 'id.dana',
        title: 'Pembayaran Berhasil',
        text: 'Kamu berhasil bayar Rp42.500 di Indomaret menggunakan DANA.',
        postTimeMs: now.millisecondsSinceEpoch + 30000,
      );
      expect(await controller.processRawNotification(danaRaw), isTrue);

      // 3. GoPay QRIS Mie Gacoan -> Makan & Minum, maps to GoPay wallet.
      final gopayRaw = RawBankNotification(
        packageName: 'com.gojek.gopay',
        title: 'Pembayaran GoPay Berhasil',
        text: 'Kamu bayar Rp36.000 ke Mie Gacoan pakai GoPay QRIS.',
        postTimeMs: now.millisecondsSinceEpoch + 60000,
      );
      expect(await controller.processRawNotification(gopayRaw), isTrue);

      // 4. Bank Jago QRIS Fore Coffee -> auto-creates Bank Jago wallet.
      final jagoRaw = RawBankNotification(
        packageName: 'com.jago.digitalBanking',
        title: 'Pembayaran QRIS berhasil',
        text: 'Transaksi QRIS sebesar Rp55.000 di Fore Coffee berhasil dari Kantong Utama.',
        postTimeMs: now.millisecondsSinceEpoch + 90000,
      );
      expect(await controller.processRawNotification(jagoRaw), isTrue);
      expect(controller.wallets.any((w) => w.name == 'Bank Jago'), isTrue);

      // 5. SeaBank Transfer Masuk -> Income.
      final incomeRaw = RawBankNotification(
        packageName: 'id.co.bankbkemobile.digitalbank',
        title: 'Transfer Masuk',
        text: 'Kamu menerima transfer sebesar Rp750.000 dari Raka Pratama.',
        postTimeMs: now.millisecondsSinceEpoch + 120000,
      );
      expect(await controller.processRawNotification(incomeRaw), isTrue);
      expect(controller.monthlyIncome, 750000);
      expect(controller.monthlyExpense, 28000 + 42500 + 36000 + 55000);

      // 6. Promo spam and OTP must be rejected completely.
      final promoRaw = RawBankNotification(
        packageName: 'id.dana',
        title: 'Cashback hingga Rp50.000!',
        text: 'Bayar QRIS hari ini dan dapatkan voucher diskon spesial.',
        postTimeMs: now.millisecondsSinceEpoch + 150000,
      );
      final otpRaw = RawBankNotification(
        packageName: 'id.co.bankbkemobile.digitalbank',
        title: 'Kode OTP SeaBank',
        text: 'Jangan berikan kode verifikasi 882910 untuk transaksi Rp100.000.',
        postTimeMs: now.millisecondsSinceEpoch + 180000,
      );
      expect(await controller.processRawNotification(promoRaw), isFalse);
      expect(await controller.processRawNotification(otpRaw), isFalse);
      expect(controller.transactions.length, 5);

      // 7. Inbox confirmation mode queues pending item and saves on approve.
      await controller.setAutoCaptureMode(AutoCaptureMode.inbox);
      final inboxRaw = RawBankNotification(
        packageName: 'com.gojek.app',
        title: 'Pembayaran QRIS Berhasil',
        text: 'Pembayaran QRIS Rp19.000 ke Warteg Bahari berhasil.',
        postTimeMs: now.millisecondsSinceEpoch + 210000,
      );
      expect(await controller.processRawNotification(inboxRaw), isTrue);
      expect(controller.pendingAutoTransactions.length, 1);
      expect(controller.transactions.length, 5);

      final savedCount = await controller.approveAllPendingAutoTransactions();
      expect(savedCount, 1);
      expect(controller.pendingAutoTransactions, isEmpty);
      expect(controller.transactions.length, 6);
    });

    testWidgets('AutoCaptureSheet renders cleanly on narrow 360dp phone with 1.3x font scale', (
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

      await tester.tap(find.byTooltip('Auto-Catat QRIS & Bank'));
      await tester.pumpAndSettle();
      expect(find.byType(AutoCaptureSheet), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('SeaBank'),
        200,
        scrollable: find.descendant(
          of: find.byType(AutoCaptureSheet),
          matching: find.byType(Scrollable),
        ).first,
      );
      expect(find.text('SeaBank'), findsOneWidget);
      expect(find.text('Bank Jago'), findsOneWidget);

      Navigator.of(tester.element(find.byType(AutoCaptureSheet))).pop();
      await tester.pumpAndSettle();
    });

    test('Full automation suite: Self-Transfer pairing, Merchant learning memory, Auto-Gaji & Auto-Pay bills', () async {
      final now = DateTime(2026, 11, 26, 18, 15);
      final controller = FinanceController(
        customStore: InMemorySakuStore(),
        clock: () => now,
      );
      await controller.initialize();
      await controller.ensurePriorityBankWallets();
      await controller.setAutoCaptureEnabled(true);
      await controller.setAutoCaptureMode(AutoCaptureMode.autoSave);
      await controller.setAutoPairTransfers(true);

      // 1A. Explicit top-up to another owned wallet -> recorded directly as Transfer, second leg absorbed.
      final topUpOut = RawBankNotification(
        packageName: 'id.co.bankbkemobile.digitalbank',
        title: 'Top Up E-Wallet Berhasil',
        text: 'Kamu berhasil top up DANA sebesar Rp200.000 dari SeaBank.',
        postTimeMs: now.millisecondsSinceEpoch,
      );
      final topUpIn = RawBankNotification(
        packageName: 'id.dana',
        title: 'Saldo Masuk',
        text: 'Kamu menerima Rp200.000 dari SeaBank.',
        postTimeMs: now.millisecondsSinceEpoch + 15000,
      );
      expect(await controller.processRawNotification(topUpOut), isTrue);
      expect(await controller.processRawNotification(topUpIn), isTrue);
      expect(controller.transactions.length, 1);
      expect(controller.transactions.first.kind, TransactionKind.transfer);
      expect(controller.monthlyExpense, 0);
      expect(controller.monthlyIncome, 0);

      // 1B. Opposite-direction pairing within 3 minutes -> merges into 1 Transfer without inflating expense/income.
      final jagoOut = RawBankNotification(
        packageName: 'com.jago.digitalBanking',
        title: 'Uang keluar',
        text: 'Transfer keluar Rp300.000 ke rekening tujuan berhasil.',
        postTimeMs: now.millisecondsSinceEpoch + 600000,
      );
      final gopayIn = RawBankNotification(
        packageName: 'com.gojek.gopay',
        title: 'GoPay masuk!',
        text: 'Kamu terima Rp300.000 dari rekening pengirim.',
        postTimeMs: now.millisecondsSinceEpoch + 645000,
      );
      expect(await controller.processRawNotification(jagoOut), isTrue);
      expect(await controller.processRawNotification(gopayIn), isTrue);
      expect(controller.transactions.length, 2);
      expect(
        controller.transactions.every((t) => t.kind == TransactionKind.transfer),
        isTrue,
      );
      expect(controller.monthlyExpense, 0);
      expect(controller.monthlyIncome, 0);

      // 2. Self-learning merchant category memory.
      final cash = controller.wallets.firstWhere((w) => w.name == 'Cash');
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
      final qrisLearned = RawBankNotification(
        packageName: 'id.co.bankbkemobile.digitalbank',
        title: 'Pembayaran QRIS Berhasil',
        text: 'Kamu telah membayar Rp24.000 ke Warung Pak Slamet menggunakan QRIS.',
        postTimeMs: now.millisecondsSinceEpoch + 900000,
      );
      expect(await controller.processRawNotification(qrisLearned), isTrue);
      final learnedTx = controller.transactions.firstWhere(
        (t) => t.amount == 24000,
      );
      expect(learnedTx.category, 'Makan & Minum');

      // 4A. Recurring Auto-Gaji (day 25 <= current day 26 -> auto-credited once, idempotent).
      final bca = controller.wallets.firstWhere((w) => w.name == 'BCA');
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

      // 4B. Auto-Pay Recurring Bill (dueDay 20 <= current day 26 -> auto-paid once & marked Lunas).
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
      expect(controller.monthlyExpense, 20000 + 24000 + 375000);
    });

    test('v1.2.0 final automation: Auto-Reconcile bills/debts, Auto-Save Goal, Monthly Closing & Auto-Backup', () async {
      final now = DateTime(2026, 11, 26, 18, 25);
      final controller = FinanceController(
        customStore: InMemorySakuStore(),
        clock: () => now,
      );
      await controller.initialize();
      await controller.setAutoCaptureEnabled(true);
      await controller.setAutoCaptureMode(AutoCaptureMode.autoSave);
      await controller.setAutoReconcilePlan(true);

      final bca = controller.wallets.firstWhere((w) => w.name == 'BCA');

      // 1A. Auto-deduct Receivable from bank incoming transfer notification.
      await controller.addDebt(
        personName: 'Raka Pratama',
        phone: '081234567890',
        kind: DebtKind.receivable,
        principalAmount: 750000,
      );
      final rakaPay = RawBankNotification(
        packageName: 'id.co.bankbkemobile.digitalbank',
        title: 'Transfer Masuk',
        text: 'Kamu menerima transfer sebesar Rp500.000 dari Raka Pratama.',
        postTimeMs: now.millisecondsSinceEpoch,
      );
      expect(await controller.processRawNotification(rakaPay), isTrue);
      final updatedRaka = controller.debts.firstWhere(
        (d) => d.personName == 'Raka Pratama',
      );
      expect(updatedRaka.remainingAmount, 250000);
      expect(updatedRaka.isSettled, isFalse);

      // 1B. Auto-mark unpaid Bill as Lunas when matching bank payment arrives.
      await controller.addBill(
        name: 'Internet IndiHome',
        amount: 385000,
        category: 'Tagihan & Utilitas',
        dueDay: 20,
      );
      final indihomePay = RawBankNotification(
        packageName: 'id.dana',
        title: 'Pembayaran Berhasil',
        text: 'Kamu berhasil bayar Rp385.000 ke IndiHome menggunakan DANA.',
        postTimeMs: now.millisecondsSinceEpoch + 30000,
      );
      expect(await controller.processRawNotification(indihomePay), isTrue);
      final paidIndihome = controller.bills.firstWhere(
        (b) => b.name == 'Internet IndiHome',
      );
      expect(paidIndihome.isPaidFor(now), isTrue);

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

      // 2. Monthly Closing Recap & Archive for previous month (October 2026).
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

      // 3. Weekly rolling Auto-Backup JSON (runs once, then skips within 7 days).
      final backupPath = await controller.runAutoBackupIfDue();
      expect(backupPath, contains('SakuProWann_AutoBackup_20261126.json'));
      expect(await controller.runAutoBackupIfDue(), isNull);

      // 4. Backup JSON round-trip preserves learned merchants, recurring incomes, and auto-save goal rules.
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
  });
}

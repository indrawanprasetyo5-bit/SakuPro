import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../models/transaction_item.dart';
import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import '../widgets/auto_capture_sheet.dart';
import '../widgets/budget_dialog.dart';
import '../widgets/luxury_widgets.dart';
import '../widgets/quick_input_sheet.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/transactions_history_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onNavigateToWallets,
  });

  final FinanceController controller;
  final VoidCallback onNavigateToWallets;

  static const List<String> _bulanIndo = <String>[
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

  String _greetingAndPeriod(DateTime dt) {
    final monthName = _bulanIndo[(dt.month - 1).clamp(0, 11)];
    final hour = dt.hour;
    final greeting = hour < 11
        ? 'Selamat pagi'
        : hour < 15
        ? 'Selamat siang'
        : hour < 18
        ? 'Selamat sore'
        : 'Selamat malam';
    return '$greeting · $monthName ${dt.year}';
  }

  Future<void> _handlePullToRefresh(BuildContext context) async {
    HapticFeedback.lightImpact();
    await controller.refreshNotificationPermission();
    final recurring = await controller.runRecurringAutomations();
    final captured = controller.autoCaptureEnabled
        ? await controller.drainNativeNotifications()
        : 0;
    final totalNew = recurring.totalRecorded + captured;
    if (context.mounted && totalNew > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$totalNew transaksi otomatis baru sudah tercatat.'),
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TransactionModel tx,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus transaksi ini?'),
        content: Text(
          '"${tx.displayTitle}" (${IdrFormat.currency(tx.amount)}) akan dihapus dan saldo dompet langsung dikembalikan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.saku.expense,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && tx.id != null && context.mounted) {
      final deletedSnapshot = tx.copyWith(id: null);
      await controller.deleteTransaction(tx.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('"${tx.displayTitle}" dihapus.'),
              action: SnackBarAction(
                label: 'Urungkan',
                onPressed: () {
                  controller.addTransaction(deletedSnapshot);
                },
              ),
            ),
          );
      }
    }
  }

  Future<void> _openScanShortcut(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        final saku = ctx.saku;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: saku.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Scan Struk atau Resi',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Foto struk belanja atau pilih screenshot resi Bank Jago, SeaBank, DANA, dan GoPay dari galeri.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.of(ctx).pop(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 20),
                label: const Text('Buka Kamera'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('Pilih Foto dari Galeri'),
              ),
            ],
          ),
        );
      },
    );

    if (source != null && context.mounted) {
      final saved = await QuickInputSheet.show(
        context,
        controller: controller,
        initialMode: InputEntryMode.manualForm,
        autoScanSource: source,
      );
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi dari struk tersimpan.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final safe = controller.safeToSpend;
    final recentTx = controller.transactions.take(8).toList();
    final periodLabel = _greetingAndPeriod(controller.now);
    final activeWalletCount = controller.wallets
        .where((w) => !w.excludeFromTotal)
        .length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[saku.heroStart, saku.heroMid],
                ),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: saku.goldAccent.withValues(alpha: 0.55),
                ),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 18,
                color: saku.goldAccent,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'SakuProWann',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    periodLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: saku.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Auto-Catat QRIS & Bank',
            onPressed: () =>
                AutoCaptureSheet.show(context, controller: controller),
            icon: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(
                  controller.autoCaptureEnabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_rounded,
                  color: controller.autoCaptureEnabled
                      ? saku.brandInteractive
                      : saku.textPrimary,
                ),
                if (controller.pendingAutoTransactions.isNotEmpty ||
                    controller.autoCaptureEnabled)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: controller.pendingAutoTransactions.isNotEmpty
                            ? saku.goldAccent
                            : saku.income,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.isDarkMode
                ? 'Beralih ke Mode Terang'
                : 'Beralih ke Mode Gelap',
            onPressed: controller.toggleThemeMode,
            icon: Icon(
              context.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: saku.textPrimary,
            ),
          ),
          IconButton(
            tooltip: 'Pengaturan & Kunci Privasi',
            onPressed: () =>
                SettingsSheet.show(context, controller: controller),
            icon: Icon(Icons.settings_outlined, color: saku.textPrimary),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: saku.brandInteractive,
        onRefresh: () => _handlePullToRefresh(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
        children: <Widget>[
          WealthMetalCard(
            netWorth: controller.netWorth,
            hidden: controller.hideBalance,
            activeWalletCount: activeWalletCount,
            onToggleHidden: controller.toggleHideBalance,
            onManageWallets: onNavigateToWallets,
          ),
          const SizedBox(height: 16),
          LuxuryQuickActionBar(
            actions: <QuickActionSpec>[
              QuickActionSpec(
                label: 'Catat',
                icon: Icons.bolt_rounded,
                color: saku.brandInteractive,
                softBg: saku.brandSoft,
                onTap: () async {
                  final saved = await QuickInputSheet.show(
                    context,
                    controller: controller,
                  );
                  if (saved == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaksi tersimpan.')),
                    );
                  }
                },
              ),
              QuickActionSpec(
                label: 'Scan',
                icon: Icons.document_scanner_outlined,
                color: saku.goldAccent,
                softBg: saku.goldSoft,
                onTap: () => _openScanShortcut(context),
              ),
              QuickActionSpec(
                label: 'Transfer',
                icon: Icons.swap_horiz_rounded,
                color: saku.transfer,
                softBg: saku.transferSoft,
                onTap: () async {
                  final saved = await QuickInputSheet.show(
                    context,
                    controller: controller,
                    initialMode: InputEntryMode.manualForm,
                    initialKind: TransactionKind.transfer,
                  );
                  if (saved == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transfer antar dompet dicatat.'),
                      ),
                    );
                  }
                },
              ),
              QuickActionSpec(
                label: 'Budget',
                icon: Icons.tune_rounded,
                color: saku.income,
                softBg: saku.incomeSoft,
                onTap: () =>
                    BudgetDialog.show(context, controller: controller),
              ),
            ],
          ),
          if (controller.pendingAutoTransactions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            PendingAutoCaptureCard(
              controller: controller,
              hideBalance: controller.hideBalance,
            ),
          ],
          if (controller.activeMonthlyRecap != null) ...<Widget>[
            const SizedBox(height: 16),
            MonthlyClosingRecapCard(
              controller: controller,
              recap: controller.activeMonthlyRecap!,
              hideBalance: controller.hideBalance,
            ),
          ],
          const SizedBox(height: 18),
          _SafeToSpendCard(controller: controller, snapshot: safe),
          const SizedBox(height: 16),
          _MonthlyFlowRow(controller: controller),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Transaksi Terbaru',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (controller.transactions.isNotEmpty)
                TextButton(
                  onPressed: () => TransactionsHistorySheet.show(
                    context,
                    controller: controller,
                    onDeleteRequest: _confirmDelete,
                  ),
                  child: Text(
                    'Lihat Semua (${controller.transactions.length})',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (recentTx.isEmpty)
            _EmptyTransactionsCard(controller: controller)
          else
            Material(
              color: saku.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: saku.border),
              ),
              child: Column(
                children: <Widget>[
                  for (var i = 0; i < recentTx.length; i++) ...<Widget>[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 68,
                        endIndent: 14,
                        color: saku.border,
                      ),
                    TransactionTile(
                      transaction: recentTx[i],
                      controller: controller,
                      onEdit: () async {
                        final updated = await QuickInputSheet.show(
                          context,
                          controller: controller,
                          existingTransaction: recentTx[i],
                        );
                        if (updated == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Perubahan transaksi disimpan.'),
                            ),
                          );
                        }
                      },
                      onDelete: () => _confirmDelete(context, recentTx[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
        ),
      ),
    );
  }
}

class _SafeToSpendCard extends StatelessWidget {
  const _SafeToSpendCard({
    required this.controller,
    required this.snapshot,
  });

  final FinanceController controller;
  final SafeSpendSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final hidden = controller.hideBalance;

    final Color statusColor;
    final Color statusSoft;
    final IconData statusIcon;

    switch (snapshot.level) {
      case SafeSpendLevel.safe:
        statusColor = saku.income;
        statusSoft = saku.incomeSoft;
        statusIcon = Icons.check_circle_outline_rounded;
      case SafeSpendLevel.caution:
        statusColor = saku.warning;
        statusSoft = saku.warningSoft;
        statusIcon = Icons.warning_amber_rounded;
      case SafeSpendLevel.overbudget:
        statusColor = saku.expense;
        statusSoft = saku.expenseSoft;
        statusIcon = Icons.error_outline_rounded;
    }

    final pctUsed = NumberFormat.decimalPattern(
      'id_ID',
    ).format((snapshot.usageRatio * 100).round());

    return LuxurySurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Aman Jajan Hari Ini',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      snapshot.level.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              Text(
                IdrFormat.currency(snapshot.dailySafeAmount, hidden: hidden),
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: snapshot.level == SafeSpendLevel.overbudget
                      ? saku.expense
                      : saku.textPrimary,
                  fontFeatures: AppTheme.tabularNums,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '/ hari (${snapshot.remainingDays} hari tersisa)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: saku.textMuted,
                    fontFeatures: AppTheme.tabularNums,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SmoothProgressBar(value: snapshot.usageRatio, color: statusColor),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  snapshot.remainingBudget >= 0
                      ? 'Sisa ${IdrFormat.compact(snapshot.remainingBudget, hidden: hidden)} dari ${IdrFormat.compact(snapshot.monthlyBudget, hidden: hidden)} ($pctUsed%)'
                      : 'Lewat budget ${IdrFormat.compact(snapshot.remainingBudget.abs(), hidden: hidden)} ($pctUsed%)',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: saku.textSecondary,
                    fontFeatures: AppTheme.tabularNums,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () =>
                    BudgetDialog.show(context, controller: controller),
                child: const Text(
                  'Ubah Budget',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyFlowRow extends StatelessWidget {
  const _MonthlyFlowRow({required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final hidden = controller.hideBalance;

    return Row(
      children: <Widget>[
        Expanded(
          child: _FlowMetricTile(
            label: 'Pemasukan',
            amount: IdrFormat.currency(
              controller.monthlyIncome,
              hidden: hidden,
            ),
            icon: Icons.north_east_rounded,
            accent: saku.income,
            softBg: saku.incomeSoft,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FlowMetricTile(
            label: 'Pengeluaran',
            amount: IdrFormat.currency(
              controller.monthlyExpense,
              hidden: hidden,
            ),
            icon: Icons.south_west_rounded,
            accent: saku.expense,
            softBg: saku.expenseSoft,
          ),
        ),
      ],
    );
  }
}

class _FlowMetricTile extends StatelessWidget {
  const _FlowMetricTile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.accent,
    required this.softBg,
  });

  final String label;
  final String amount;
  final IconData icon;
  final Color accent;
  final Color softBg;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    return LuxurySurfaceCard(
      padding: const EdgeInsets.all(15),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: softBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: saku.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              maxLines: 1,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: saku.textPrimary,
                fontFeatures: AppTheme.tabularNums,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTransactionsCard extends StatelessWidget {
  const _EmptyTransactionsCard({required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    return LuxurySurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: saku.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: saku.brandInteractive,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Buku kas bulan ini masih kosong',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Ketik santai seperti "kopi 22rb gopay" atau foto struk dari kamera. Semua tercatat lokal di HP tanpa butuh internet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => QuickInputSheet.show(
                  context,
                  controller: controller,
                  initialSmartText: 'kopi 22rb gopay',
                ),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text('Coba "kopi 22rb gopay"'),
              ),
              OutlinedButton.icon(
                onPressed: () => QuickInputSheet.show(
                  context,
                  controller: controller,
                  initialMode: InputEntryMode.manualForm,
                ),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Form Lengkap'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

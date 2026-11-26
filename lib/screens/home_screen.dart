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
import '../widgets/split_bill_sheet.dart';
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
        ? 'Pagi'
        : hour < 15
        ? 'Siang'
        : hour < 18
        ? 'Sore'
        : 'Malam';
    return '$greeting · $monthName ${dt.year}';
  }

  Future<void> _handlePullToRefresh(BuildContext context) async {
    HapticFeedback.lightImpact();
    await controller.refreshPostNotificationPermission();
    final recurring = await controller.runRecurringAutomations();
    if (context.mounted && recurring.totalRecorded > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${recurring.totalRecorded} transaksi rutin otomatis tercatat.',
          ),
        ),
      );
    }
  }

  Future<void> _quickDelete(
    BuildContext context,
    TransactionModel tx,
  ) async {
    if (tx.id == null) {
      return;
    }
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

  Future<void> _confirmDelete(
    BuildContext context,
    TransactionModel tx,
  ) async {
    final confirmed = await showSakuBottomSheet<bool>(
      context: context,
      builder: (ctx) {
        final saku = ctx.saku;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SakuSheetHandle(),
              const SizedBox(height: 16),
              Text(
                'Hapus transaksi ini?',
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                '"${tx.displayTitle}" (${IdrFormat.currency(tx.amount)}) bakal dihapus dan saldo dompet langsung balik seperti semula.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: saku.expense,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Hapus'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
    final source = await showSakuBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SakuSheetHandle(),
              const SizedBox(height: 16),
              Text(
                'Scan Struk atau Resi',
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Foto struk belanja atau pilih screenshot resi Bank Jago, SeaBank, DANA, dan GoPay dari galeri.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.of(ctx).pop(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 20),
                label: const Text('Buka Kamera'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('Pilih dari Galeri'),
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
          const SnackBar(content: Text('Struk berhasil dicatat.')),
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
                color: saku.surface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: saku.borderStrong, width: 1),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 18,
                color: saku.brandInteractive,
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
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    periodLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
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
            tooltip: 'Split Bill / Patungan',
            onPressed: () async {
              final count = await SplitBillSheet.show(
                context,
                controller: controller,
              );
              if (count != null && count > 0 && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Patungan tercatat · $count piutang teman siap ditagih di tab Rencana.',
                    ),
                  ),
                );
              }
            },
            icon: Icon(
              Icons.groups_outlined,
              color: saku.textPrimary,
            ),
          ),
          IconButton(
            tooltip: 'Pusat Otomatisasi',
            onPressed: () =>
                AutoCaptureSheet.show(context, controller: controller),
            icon: Icon(
              Icons.event_repeat_rounded,
              color: saku.textPrimary,
            ),
          ),
          IconButton(
            tooltip: context.isDarkMode
                ? 'Pindah ke Mode Terang'
                : 'Pindah ke Mode Gelap',
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
        backgroundColor: saku.surface,
        onRefresh: () => _handlePullToRefresh(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: <Widget>[
            _SafeToSpendHeroCard(controller: controller, snapshot: safe),
            const SizedBox(height: 10),
            WealthMetalCard(
              netWorth: controller.netWorth,
              hidden: controller.hideBalance,
              activeWalletCount: activeWalletCount,
              onToggleHidden: controller.toggleHideBalance,
              onManageWallets: onNavigateToWallets,
            ),
            const SizedBox(height: 10),
            _MonthlyFlowBentoRow(controller: controller),
            const SizedBox(height: 10),
            LuxuryQuickActionBar(
              actions: <QuickActionSpec>[
                QuickActionSpec(
                  label: 'Catat',
                  icon: Icons.edit_note_rounded,
                  color: saku.brandInteractive,
                  softBg: saku.brandSoft,
                  onTap: () async {
                    final saved = await QuickInputSheet.show(
                      context,
                      controller: controller,
                    );
                    if (saved == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transaksi masuk buku kas.'),
                        ),
                      );
                    }
                  },
                ),
                QuickActionSpec(
                  label: 'Scan',
                  icon: Icons.document_scanner_outlined,
                  color: saku.warning,
                  softBg: saku.warningSoft,
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
            if (controller.activeMonthlyRecap != null) ...<Widget>[
              const SizedBox(height: 14),
              MonthlyClosingRecapCard(
                controller: controller,
                recap: controller.activeMonthlyRecap!,
                hideBalance: controller.hideBalance,
              ),
            ],
            const SizedBox(height: 16),
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
                      style: const TextStyle(
                        fontSize: 13,
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
                  borderRadius: BorderRadius.circular(SakuRadius.lg),
                  side: BorderSide(color: saku.border, width: 1),
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
                                content: Text('Perubahan disimpan.'),
                              ),
                            );
                          }
                        },
                        onDelete: () => _confirmDelete(context, recentTx[i]),
                        onQuickDelete: () => _quickDelete(context, recentTx[i]),
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

class _SafeToSpendHeroCard extends StatelessWidget {
  const _SafeToSpendHeroCard({
    required this.controller,
    required this.snapshot,
  });

  final FinanceController controller;
  final SafeSpendSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final isDark = context.isDarkMode;
    final hidden = controller.hideBalance;

    final Color statusColor;
    final Color statusSoft;
    final String statusLabel;

    switch (snapshot.level) {
      case SafeSpendLevel.safe:
        statusColor = saku.income;
        statusSoft = saku.incomeSoft;
        statusLabel = 'Aman';
      case SafeSpendLevel.caution:
        statusColor = saku.warning;
        statusSoft = saku.warningSoft;
        statusLabel = 'Hati-hati';
      case SafeSpendLevel.overbudget:
        statusColor = saku.expense;
        statusSoft = saku.expenseSoft;
        statusLabel = 'Lewat Limit';
    }

    final pctUsed = NumberFormat.decimalPattern(
      'id_ID',
    ).format((snapshot.usageRatio * 100).round());

    final borderTint = snapshot.level == SafeSpendLevel.overbudget
        ? saku.expense.withValues(alpha: 0.42)
        : snapshot.level == SafeSpendLevel.caution
        ? saku.warning.withValues(alpha: 0.36)
        : saku.borderStrong;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[saku.heroStart, saku.heroMid, saku.heroEnd],
              )
            : null,
        color: isDark ? null : saku.surface,
        borderRadius: BorderRadius.circular(SakuRadius.xl),
        border: Border.all(color: borderTint, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Aman Dipakai Hari Ini',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: saku.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusSoft,
                  borderRadius: BorderRadius.circular(SakuRadius.pill),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                AnimatedCurrencyText(
                  amount: snapshot.dailySafeAmount,
                  hidden: hidden,
                  style: TextStyle(
                    fontSize: 33,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                    height: 1.08,
                    color: snapshot.level == SafeSpendLevel.overbudget
                        ? saku.expense
                        : saku.textPrimary,
                    fontFeatures: AppTheme.tabularNums,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '/ hari',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: saku.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${snapshot.remainingDays} hari lagi · $pctUsed% limit terpakai',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: saku.textMuted,
              fontFeatures: AppTheme.tabularNums,
            ),
          ),
          const SizedBox(height: 12),
          SmoothProgressBar(
            value: snapshot.usageRatio,
            color: statusColor,
            height: 7,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  snapshot.remainingBudget >= 0
                      ? 'Sisa ${IdrFormat.compact(snapshot.remainingBudget, hidden: hidden)} dari ${IdrFormat.compact(snapshot.monthlyBudget, hidden: hidden)}'
                      : 'Lewat limit ${IdrFormat.compact(snapshot.remainingBudget.abs(), hidden: hidden)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: saku.textSecondary,
                    fontFeatures: AppTheme.tabularNums,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TactilePressScale(
                child: Material(
                  color: saku.surfaceElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SakuRadius.pill),
                    side: BorderSide(color: saku.border, width: 1),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(SakuRadius.pill),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      BudgetDialog.show(context, controller: controller);
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 38),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Atur Limit',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: saku.brandInteractive,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyFlowBentoRow extends StatelessWidget {
  const _MonthlyFlowBentoRow({required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final hidden = controller.hideBalance;

    return Row(
      children: <Widget>[
        Expanded(
          child: _FlowMetricTile(
            label: 'Uang Masuk',
            amount: controller.monthlyIncome,
            hidden: hidden,
            icon: Icons.north_east_rounded,
            accent: saku.income,
            softBg: saku.incomeSoft,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FlowMetricTile(
            label: 'Uang Keluar',
            amount: controller.monthlyExpense,
            hidden: hidden,
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
    required this.hidden,
    required this.icon,
    required this.accent,
    required this.softBg,
  });

  final String label;
  final int amount;
  final bool hidden;
  final IconData icon;
  final Color accent;
  final Color softBg;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    return LuxurySurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: SakuRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: softBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: saku.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedCurrencyText(
              amount: amount,
              hidden: hidden,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.35,
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: saku.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: saku.brandInteractive,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Belum ada transaksi bulan ini',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Ketik cepat di bar bawah kayak kirim chat, misal: kopi 25rb gopay. Semua catatan aman tersimpan offline di HP kamu.',
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
                  initialSmartText: 'kopi 25rb gopay',
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Coba "kopi 25rb gopay"'),
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

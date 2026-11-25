import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../models/transaction_item.dart';
import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import '../widgets/budget_dialog.dart';
import '../widgets/quick_input_sheet.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/transaction_tile.dart';

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

  String _monthYearLabel(DateTime dt) {
    final monthName = _bulanIndo[(dt.month - 1).clamp(0, 11)];
    return '$monthName ${dt.year}';
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TransactionModel tx,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: Text(
          'Transaksi "${tx.displayTitle}" sebesar ${IdrFormat.currency(tx.amount)} akan dihapus dan saldo dompet dikembalikan otomatis.',
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
      await controller.deleteTransaction(tx.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi dihapus dan saldo diperbarui.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final safe = controller.safeToSpend;
    final recentTx = controller.transactions.take(15).toList();
    final periodLabel = _monthYearLabel(controller.now);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'SakuPro',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  periodLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: saku.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: <Widget>[
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
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 108),
        children: <Widget>[
          _NetWorthCard(
            controller: controller,
            onManageWallets: onNavigateToWallets,
          ),
          const SizedBox(height: 16),
          _SafeToSpendCard(
            controller: controller,
            snapshot: safe,
          ),
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
              TextButton.icon(
                onPressed: () async {
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
                icon: const Icon(Icons.bolt_rounded, size: 17),
                label: const Text('Catat Cepat'),
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
                borderRadius: BorderRadius.circular(16),
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
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({
    required this.controller,
    required this.onManageWallets,
  });

  final FinanceController controller;
  final VoidCallback onManageWallets;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final hidden = controller.hideBalance;
    final activeWalletCount = controller.wallets
        .where((w) => !w.excludeFromTotal)
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Tonal gradient elevates primary net worth card as the sole screen focal point.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[saku.heroStart, saku.heroEnd],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.22),
            offset: const Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Total Saldo Bersih',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: saku.heroMutedText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: controller.toggleHideBalance,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 40,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hidden ? 'Tampilkan' : 'Sembunyikan',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              IdrFormat.currency(controller.netWorth, hidden: hidden),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: Colors.white,
                fontFeatures: AppTheme.tabularNums,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.layers_outlined,
                  size: 16,
                  color: saku.heroMutedText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$activeWalletCount dompet terhubung',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: saku.heroMutedText,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onManageWallets,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      'Kelola Dompet',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

    final clampedProgress = snapshot.usageRatio.clamp(0.0, 1.0);
    final pctUsed = NumberFormat.decimalPattern(
      'id_ID',
    ).format((snapshot.usageRatio * 100).round());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: saku.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: saku.border),
      ),
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
                  borderRadius: BorderRadius.circular(6),
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
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
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
                    color: saku.textMuted,
                    fontFeatures: AppTheme.tabularNums,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clampedProgress,
              minHeight: 8,
              backgroundColor: saku.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  snapshot.remainingBudget >= 0
                      ? 'Sisa budget ${IdrFormat.compact(snapshot.remainingBudget, hidden: hidden)} dari ${IdrFormat.compact(snapshot.monthlyBudget, hidden: hidden)} ($pctUsed%)'
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
            label: 'Pemasukan Bulan Ini',
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
            label: 'Pengeluaran Bulan Ini',
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: saku.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: saku.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: softBg,
                  borderRadius: BorderRadius.circular(8),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: saku.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: saku.textPrimary,
              fontFeatures: AppTheme.tabularNums,
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: saku.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: saku.border),
      ),
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
                  borderRadius: BorderRadius.circular(10),
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
                  'Belum ada transaksi tercatat',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Gunakan tombol (+) untuk mengetik kalimat singkat seperti "kopi 22rb gopay" atau "gaji 5jt bca". Kategori, tipe, nominal, dan dompet terdeteksi otomatis secara offline.',
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

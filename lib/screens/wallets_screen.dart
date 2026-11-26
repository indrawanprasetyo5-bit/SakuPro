import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/transaction_item.dart';
import '../models/wallet.dart';
import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import '../widgets/luxury_widgets.dart';
import '../widgets/quick_input_sheet.dart';
import '../widgets/wallet_form_sheet.dart';

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key, required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final wallets = controller.wallets;
    final hidden = controller.hideBalance;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Dompet & Transfer'),
        actions: <Widget>[
          IconButton(
            tooltip: hidden ? 'Tampilkan saldo' : 'Sembunyikan saldo',
            onPressed: controller.toggleHideBalance,
            icon: Icon(
              hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: saku.textPrimary,
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
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
        children: <Widget>[
          LuxurySurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: saku.brandInteractive,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total Seluruh Dompet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: saku.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    IdrFormat.currency(
                      controller.totalAllWallets,
                      hidden: hidden,
                    ),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      color: saku.textPrimary,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                ),
                if (controller.totalAllWallets !=
                    controller.netWorth) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Saldo bersih aktif: ${IdrFormat.currency(controller.netWorth, hidden: hidden)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: saku.textSecondary,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: wallets.length >= 2
                          ? () async {
                              final done = await QuickInputSheet.show(
                                context,
                                controller: controller,
                                initialMode: InputEntryMode.manualForm,
                                initialKind: TransactionKind.transfer,
                              );
                              if (done == true && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Transfer antar dompet berhasil dicatat.',
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 19),
                      label: const Text('Transfer Dompet'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final added = await WalletFormSheet.show(
                          context,
                          controller: controller,
                        );
                        if (added == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Dompet baru berhasil ditambahkan.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 19),
                      label: const Text('Dompet Baru'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              Text(
                'Daftar Dompet (${wallets.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Ketuk dompet untuk edit',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final wallet in wallets) ...<Widget>[
            _WalletCard(
              wallet: wallet,
              hideBalance: hidden,
              onEdit: () async {
                final changed = await WalletFormSheet.show(
                  context,
                  controller: controller,
                  existingWallet: wallet,
                );
                if (changed == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data dompet diperbarui.')),
                  );
                }
              },
              onQuickRecord: () async {
                final saved = await QuickInputSheet.show(
                  context,
                  controller: controller,
                  initialMode: InputEntryMode.manualForm,
                  initialSourceWalletId: wallet.id,
                );
                if (saved == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Transaksi pada dompet ${wallet.name} tersimpan.',
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 11),
          ],
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.wallet,
    required this.hideBalance,
    required this.onEdit,
    required this.onQuickRecord,
  });

  final WalletModel wallet;
  final bool hideBalance;
  final VoidCallback onEdit;
  final VoidCallback onQuickRecord;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: saku.cardShadow,
                  offset: const Offset(0, 3),
                  blurRadius: 12,
                ),
              ],
      ),
      child: Material(
        color: saku.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: saku.border),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onEdit();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        wallet.color.withValues(alpha: 0.22),
                        wallet.color.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: wallet.color.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(wallet.icon, color: wallet.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              wallet.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (wallet.excludeFromTotal) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: saku.surfaceMuted,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'Terpisah',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: saku.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        wallet.kind.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: saku.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      IdrFormat.currency(wallet.balance, hidden: hideBalance),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: wallet.balance < 0
                            ? saku.expense
                            : saku.textPrimary,
                        fontFeatures: AppTheme.tabularNums,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Edit saldo',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: saku.brandInteractive,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Catat transaksi di ${wallet.name}',
                  onPressed: onQuickRecord,
                  icon: Icon(
                    Icons.add_circle_outline_rounded,
                    color: saku.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

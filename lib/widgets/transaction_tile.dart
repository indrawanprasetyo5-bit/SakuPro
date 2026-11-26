import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../models/category_meta.dart';
import '../models/transaction_item.dart';
import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import 'wallet_brand_avatar.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionModel transaction;
  final FinanceController controller;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final meta = CategoryCatalog.resolve(
      transaction.kind,
      transaction.category,
    );
    final fromWallet = controller.walletById(transaction.walletId);
    final toWallet = controller.walletById(transaction.toWalletId);

    final String walletLabel;
    if (transaction.kind == TransactionKind.transfer) {
      walletLabel =
          '${fromWallet?.name ?? 'Dompet'} -> ${toWallet?.name ?? 'Dompet'}';
    } else {
      walletLabel = '${fromWallet?.name ?? 'Dompet'} · ${transaction.category}';
    }

    final Color amountColor;
    final String amountText;
    switch (transaction.kind) {
      case TransactionKind.expense:
        amountColor = saku.expense;
        amountText = IdrFormat.currency(
          -transaction.amount,
          hidden: controller.hideBalance,
        );
      case TransactionKind.income:
        amountColor = saku.income;
        amountText = IdrFormat.currency(
          transaction.amount,
          hidden: controller.hideBalance,
          signed: true,
        );
      case TransactionKind.transfer:
        amountColor = saku.transfer;
        amountText = IdrFormat.currency(
          transaction.amount,
          hidden: controller.hideBalance,
        );
    }

    final dateStr = DateFormat('dd MMM').format(transaction.transactionDate);

    return Material(
      color: saku.surface,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(meta.icon, size: 20, color: meta.color),
                  ),
                  if (fromWallet != null)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: saku.surface, width: 1.5),
                        ),
                        child: WalletBrandAvatar.fromWallet(
                          fromWallet,
                          size: 19,
                          borderRadius: 5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      transaction.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$walletLabel · $dateStr',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: saku.textMuted,
                        fontFeatures: AppTheme.tabularNums,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    amountText,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: amountColor,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                  if (transaction.kind == TransactionKind.transfer)
                    Text(
                      'Transfer',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: saku.transfer,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 2),
              PopupMenuButton<String>(
                tooltip: 'Opsi transaksi',
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 19,
                  color: saku.textMuted,
                ),
                onSelected: (val) {
                  if (val == 'edit') {
                    onEdit();
                  } else if (val == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (ctx) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Edit Transaksi'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.delete_outline_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Hapus Transaksi'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

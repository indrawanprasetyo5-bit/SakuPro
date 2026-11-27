import 'dart:async';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../models/category_meta.dart';
import '../models/transaction_item.dart';
import '../services/finance_controller.dart';
import '../services/receipt_archive.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import 'luxury_widgets.dart';
import 'wallet_brand_avatar.dart';

class TransactionDetailSheet extends StatelessWidget {
  const TransactionDetailSheet({
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

  static Future<void> show(
    BuildContext context, {
    required TransactionModel transaction,
    required FinanceController controller,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return showSakuBottomSheet<void>(
      context: context,
      builder: (ctx) => TransactionDetailSheet(
        transaction: transaction,
        controller: controller,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }

  static Future<void> confirmDelete(
    BuildContext context, {
    required FinanceController controller,
    required TransactionModel transaction,
  }) async {
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
                '"${transaction.displayTitle}" (${IdrFormat.currency(transaction.amount)}) bakal dihapus dan saldo dompet langsung balik seperti semula.',
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

    if (confirmed == true && transaction.id != null && context.mounted) {
      final deletedSnapshot = transaction.copyWith(id: null);
      await controller.deleteTransaction(
        transaction.id!,
        deleteReceiptFile: false,
      );
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        final snackController = messenger.showSnackBar(
          SnackBar(
            content: Text('"${transaction.displayTitle}" dihapus.'),
            action: SnackBarAction(
              label: 'Urungkan',
              onPressed: () {
                controller.addTransaction(deletedSnapshot);
              },
            ),
          ),
        );
        if (transaction.hasReceiptImage) {
          unawaited(
            snackController.closed.then((reason) {
              if (reason != SnackBarClosedReason.action) {
                return ReceiptArchive.deleteIfOwned(
                  transaction.receiptImagePath,
                );
              }
              return Future<void>.value();
            }),
          );
        }
      }
    }
  }

  void _openFullImage(BuildContext context, String imagePath) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => _ReceiptImageViewerPage(
          imagePath: imagePath,
          title: transaction.displayTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final meta = CategoryCatalog.resolve(
      transaction.kind,
      transaction.category,
    );
    final fromWallet = controller.walletById(transaction.walletId);
    final toWallet = controller.walletById(transaction.toWalletId);

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

    final walletLabel =
        transaction.kind == TransactionKind.transfer && toWallet != null
        ? '${fromWallet?.name ?? 'Dompet'} -> ${toWallet.name}'
        : (fromWallet?.name ?? 'Dompet');
    final dateLabel = DateFormat(
      'dd MMM yyyy · HH:mm',
    ).format(transaction.transactionDate);
    final hasValidImage =
        transaction.hasReceiptImage &&
        ReceiptArchive.existsSync(transaction.receiptImagePath);
    final detailLines = transaction.hasReceiptDetail
        ? transaction.receiptDetail
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList()
        : const <String>[];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SakuSheetHandle(),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: meta.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(meta.icon, size: 22, color: meta.color),
                    ),
                    if (fromWallet != null)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: saku.surface,
                              width: 1.5,
                            ),
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
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${transaction.category} · $walletLabel',
                        style: TextStyle(
                          fontSize: 13,
                          color: saku.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Tutup',
                  icon: Icon(Icons.close_rounded, color: saku.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: saku.surfaceElevated,
                borderRadius: BorderRadius.circular(SakuRadius.md),
                border: Border.all(color: saku.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: amountColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          transaction.kind.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: amountColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dateLabel,
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: saku.textMuted,
                            fontFeatures: AppTheme.tabularNums,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      amountText,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: amountColor,
                        fontFeatures: AppTheme.tabularNums,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (detailLines.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: saku.surfaceElevated,
                  borderRadius: BorderRadius.circular(SakuRadius.md),
                  border: Border.all(color: saku.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 16,
                          color: saku.brandInteractive,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Rincian Struk & Resi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: saku.textPrimary,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 32),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: transaction.receiptDetail),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Rincian transaksi disalin ke clipboard.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text(
                            'Salin',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: saku.border),
                    const SizedBox(height: 10),
                    for (var i = 0; i < detailLines.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(height: 7),
                      _DetailLineRow(line: detailLines[i]),
                    ],
                  ],
                ),
              ),
            ],
            if (hasValidImage) ...<Widget>[
              const SizedBox(height: 14),
              Material(
                color: saku.surfaceElevated,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SakuRadius.md),
                  side: BorderSide(color: saku.border, width: 1),
                ),
                child: InkWell(
                  onTap: () =>
                      _openFullImage(context, transaction.receiptImagePath),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        height: 170,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            ReceiptArchive.buildImage(
                              transaction.receiptImagePath,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.zoom_in_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Lihat Foto Struk',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: saku.expense,
                      side: BorderSide(
                        color: saku.expense.withValues(alpha: 0.35),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDelete();
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Hapus'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onEdit();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Ubah'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLineRow extends StatelessWidget {
  const _DetailLineRow({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;

    if (line.startsWith('- ')) {
      final body = line.substring(2).trim();
      final sepIdx = body.lastIndexOf(' · ');
      if (sepIdx > 0) {
        final itemName = body.substring(0, sepIdx).trim();
        final itemPrice = body.substring(sepIdx + 3).trim();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: saku.brandInteractive,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                itemName,
                style: TextStyle(
                  fontSize: 13,
                  color: saku.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              itemPrice,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: saku.textPrimary,
                fontFeatures: AppTheme.tabularNums,
              ),
            ),
          ],
        );
      }
    }

    final colonIdx = line.indexOf(': ');
    if (colonIdx > 1 && colonIdx < 24 && !line.startsWith('-')) {
      final label = line.substring(0, colonIdx).trim();
      final value = line.substring(colonIdx + 2).trim();
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: saku.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: saku.textPrimary,
                fontFeatures: AppTheme.tabularNums,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      line,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: line.endsWith(':') ? FontWeight.w700 : FontWeight.w400,
        color: line.endsWith(':') ? saku.textSecondary : saku.textPrimary,
        height: 1.4,
      ),
    );
  }
}

class _ReceiptImageViewerPage extends StatelessWidget {
  const _ReceiptImageViewerPage({
    required this.imagePath,
    required this.title,
  });

  final String imagePath;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.5,
          child: ReceiptArchive.buildImage(
            imagePath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

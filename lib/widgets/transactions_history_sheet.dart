import 'package:material_ui/material_ui.dart';

import '../models/transaction_item.dart';
import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import 'quick_input_sheet.dart';
import 'transaction_detail_sheet.dart';
import 'transaction_tile.dart';

class TransactionsHistorySheet extends StatefulWidget {
  const TransactionsHistorySheet({
    super.key,
    required this.controller,
    required this.onDeleteRequest,
  });

  final FinanceController controller;
  final Future<void> Function(BuildContext ctx, TransactionModel tx)
  onDeleteRequest;

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    required Future<void> Function(BuildContext ctx, TransactionModel tx)
    onDeleteRequest,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => TransactionsHistorySheet(
        controller: controller,
        onDeleteRequest: onDeleteRequest,
      ),
    );
  }

  @override
  State<TransactionsHistorySheet> createState() =>
      _TransactionsHistorySheetState();
}

class _TransactionsHistorySheetState extends State<TransactionsHistorySheet> {
  final TextEditingController _searchController = TextEditingController();
  TransactionKind? _kindFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionModel> _filtered() {
    final q = _searchController.text.trim().toLowerCase();
    return widget.controller.transactions.where((tx) {
      if (_kindFilter != null && tx.kind != _kindFilter) {
        return false;
      }
      if (q.isEmpty) {
        return true;
      }
      final walletName =
          widget.controller.walletById(tx.walletId)?.name.toLowerCase() ?? '';
      return tx.displayTitle.toLowerCase().contains(q) ||
          tx.category.toLowerCase().contains(q) ||
          tx.receiptDetail.toLowerCase().contains(q) ||
          walletName.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final items = _filtered();

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.86,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: saku.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Semua Transaksi (${items.length})',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Tutup',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: saku.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Cari catatan, item struk, kategori, dompet...',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: saku.textMuted,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Hapus pencarian',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.clear_rounded),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: const Text('Semua'),
                                selected: _kindFilter == null,
                                onSelected: (_) =>
                                    setState(() => _kindFilter = null),
                              ),
                            ),
                            for (final kind in TransactionKind.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(kind.label),
                                  selected: _kindFilter == kind,
                                  onSelected: (_) =>
                                      setState(() => _kindFilter = kind),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: saku.border),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Tidak ada transaksi yang cocok dengan filter.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: saku.border),
                          itemBuilder: (context, index) {
                            final tx = items[index];
                            return TransactionTile(
                              transaction: tx,
                              controller: widget.controller,
                              onTap: () {
                                TransactionDetailSheet.show(
                                  context,
                                  transaction: tx,
                                  controller: widget.controller,
                                  onEdit: () async {
                                    await QuickInputSheet.show(
                                      context,
                                      controller: widget.controller,
                                      existingTransaction: tx,
                                    );
                                  },
                                  onDelete: () =>
                                      widget.onDeleteRequest(context, tx),
                                );
                              },
                              onEdit: () async {
                                await QuickInputSheet.show(
                                  context,
                                  controller: widget.controller,
                                  existingTransaction: tx,
                                );
                              },
                              onDelete: () =>
                                  widget.onDeleteRequest(context, tx),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

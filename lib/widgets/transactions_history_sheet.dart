import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../models/category_meta.dart';
import '../models/transaction_item.dart';
import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import 'quick_input_sheet.dart';
import 'transaction_detail_sheet.dart';
import 'transaction_tile.dart';
import 'wallet_brand_avatar.dart';

class TransactionsHistorySheet extends StatefulWidget {
  const TransactionsHistorySheet({
    super.key,
    required this.controller,
    this.onDeleteRequest,
    this.initialKind,
    this.initialWalletId,
    this.initialCategory,
    this.initialMonth,
    this.titleOverride,
  });

  final FinanceController controller;
  final Future<void> Function(BuildContext ctx, TransactionModel tx)?
  onDeleteRequest;
  final TransactionKind? initialKind;
  final int? initialWalletId;
  final String? initialCategory;
  final DateTime? initialMonth;
  final String? titleOverride;

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    Future<void> Function(BuildContext ctx, TransactionModel tx)?
    onDeleteRequest,
    TransactionKind? initialKind,
    int? initialWalletId,
    String? initialCategory,
    DateTime? initialMonth,
    String? titleOverride,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: SakuMotion.sheetStyle,
      builder: (ctx) => TransactionsHistorySheet(
        controller: controller,
        onDeleteRequest: onDeleteRequest,
        initialKind: initialKind,
        initialWalletId: initialWalletId,
        initialCategory: initialCategory,
        initialMonth: initialMonth,
        titleOverride: titleOverride,
      ),
    );
  }

  @override
  State<TransactionsHistorySheet> createState() =>
      _TransactionsHistorySheetState();
}

class _DateTxGroup {
  const _DateTxGroup({
    required this.dateKey,
    required this.label,
    required this.items,
    required this.netAmount,
  });

  final DateTime dateKey;
  final String label;
  final List<TransactionModel> items;
  final int netAmount;
}

class _TransactionsHistorySheetState extends State<TransactionsHistorySheet> {
  static const List<String> _shortMonths = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  final TextEditingController _searchController = TextEditingController();
  TransactionKind? _kindFilter;
  int? _walletFilterId;
  String? _categoryFilter;
  DateTime? _monthFilter;

  @override
  void initState() {
    super.initState();
    _kindFilter = widget.initialKind;
    _walletFilterId = widget.initialWalletId;
    _categoryFilter = widget.initialCategory;
    _monthFilter = widget.initialMonth;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _kindFilter != null ||
      _walletFilterId != null ||
      _categoryFilter != null ||
      _monthFilter != null ||
      _searchController.text.trim().isNotEmpty;

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _kindFilter = null;
      _walletFilterId = null;
      _categoryFilter = null;
      _monthFilter = null;
    });
  }

  List<String> _availableCategories() {
    final seen = <String>{};
    final list = <String>[];
    for (final tx in widget.controller.transactions) {
      if (_kindFilter != null && tx.kind != _kindFilter) {
        continue;
      }
      if (seen.add(tx.category)) {
        list.add(tx.category);
      }
    }
    if (_categoryFilter != null && seen.add(_categoryFilter!)) {
      list.insert(0, _categoryFilter!);
    }
    return list;
  }

  List<TransactionModel> _filtered() {
    final q = _searchController.text.trim().toLowerCase();
    return widget.controller.transactions.where((tx) {
      if (_kindFilter != null && tx.kind != _kindFilter) {
        return false;
      }
      if (_walletFilterId != null &&
          tx.walletId != _walletFilterId &&
          tx.toWalletId != _walletFilterId) {
        return false;
      }
      if (_categoryFilter != null && tx.category != _categoryFilter) {
        return false;
      }
      if (_monthFilter != null &&
          (tx.transactionDate.year != _monthFilter!.year ||
              tx.transactionDate.month != _monthFilter!.month)) {
        return false;
      }
      if (q.isEmpty) {
        return true;
      }
      final fromName =
          widget.controller.walletById(tx.walletId)?.name.toLowerCase() ?? '';
      final toName =
          widget.controller.walletById(tx.toWalletId)?.name.toLowerCase() ?? '';
      return tx.displayTitle.toLowerCase().contains(q) ||
          tx.category.toLowerCase().contains(q) ||
          tx.receiptDetail.toLowerCase().contains(q) ||
          fromName.contains(q) ||
          toName.contains(q);
    }).toList();
  }

  List<_DateTxGroup> _groupByDate(List<TransactionModel> items) {
    final now = widget.controller.now;
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final map = <DateTime, List<TransactionModel>>{};
    for (final tx in items) {
      final day = DateTime(
        tx.transactionDate.year,
        tx.transactionDate.month,
        tx.transactionDate.day,
      );
      (map[day] ??= <TransactionModel>[]).add(tx);
    }

    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return sortedKeys.map((day) {
      final dayItems = map[day]!;
      var net = 0;
      for (final tx in dayItems) {
        if (tx.kind == TransactionKind.income) {
          net += tx.amount;
        } else if (tx.kind == TransactionKind.expense) {
          net -= tx.amount;
        }
      }
      final String label;
      if (day == today) {
        label = 'Hari Ini';
      } else if (day == yesterday) {
        label = 'Kemarin';
      } else {
        label = DateFormat('dd MMM yyyy').format(day);
      }
      return _DateTxGroup(
        dateKey: day,
        label: label,
        items: dayItems,
        netAmount: net,
      );
    }).toList();
  }

  String _formatMonthChip(DateTime dt) {
    return '${_shortMonths[(dt.month - 1).clamp(0, 11)]} ${dt.year}';
  }

  Future<void> _handleDelete(BuildContext ctx, TransactionModel tx) async {
    if (widget.onDeleteRequest != null) {
      await widget.onDeleteRequest!(ctx, tx);
    } else {
      await TransactionDetailSheet.confirmDelete(
        ctx,
        controller: widget.controller,
        transaction: tx,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final items = _filtered();
        final groups = _groupByDate(items);
        final categories = _availableCategories();
        final wallets = widget.controller.wallets;
        final hidden = widget.controller.hideBalance;

        var totalExpense = 0;
        var totalIncome = 0;
        for (final tx in items) {
          if (tx.kind == TransactionKind.expense) {
            totalExpense += tx.amount;
          } else if (tx.kind == TransactionKind.income) {
            totalIncome += tx.amount;
          }
        }

        final heading = widget.titleOverride != null
            ? '${widget.titleOverride} (${items.length})'
            : 'Semua Transaksi (${items.length})';

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          builder: (ctx, scrollController) {
            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
                  child: Column(
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
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              heading,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (_hasActiveFilters)
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              onPressed: _resetFilters,
                              child: Text(
                                'Reset',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: saku.brandInteractive,
                                ),
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
                          hintText:
                              'Cari catatan, item struk, kategori, dompet...',
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
                            if (_monthFilter != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InputChip(
                                  avatar: Icon(
                                    Icons.calendar_month_outlined,
                                    size: 15,
                                    color: saku.brandInteractive,
                                  ),
                                  label: Text(_formatMonthChip(_monthFilter!)),
                                  selected: true,
                                  onDeleted: () =>
                                      setState(() => _monthFilter = null),
                                ),
                              ),
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
                      if (wallets.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: const Text('Semua Dompet'),
                                  visualDensity: VisualDensity.compact,
                                  selected: _walletFilterId == null,
                                  onSelected: (_) =>
                                      setState(() => _walletFilterId = null),
                                ),
                              ),
                              for (final w in wallets)
                                if (w.id != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      avatar: WalletBrandAvatar.fromWallet(
                                        w,
                                        size: 18,
                                        borderRadius: 5,
                                      ),
                                      label: Text(w.name),
                                      visualDensity: VisualDensity.compact,
                                      selected: _walletFilterId == w.id,
                                      onSelected: (_) => setState(() {
                                        _walletFilterId =
                                            _walletFilterId == w.id
                                            ? null
                                            : w.id;
                                      }),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ],
                      if (categories.length > 1 ||
                          _categoryFilter != null) ...<Widget>[
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: const Text('Semua Kategori'),
                                  visualDensity: VisualDensity.compact,
                                  selected: _categoryFilter == null,
                                  onSelected: (_) =>
                                      setState(() => _categoryFilter = null),
                                ),
                              ),
                              for (final cat in categories)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    avatar: Icon(
                                      CategoryCatalog.resolve(
                                        _kindFilter ?? TransactionKind.expense,
                                        cat,
                                      ).icon,
                                      size: 14,
                                    ),
                                    label: Text(cat),
                                    visualDensity: VisualDensity.compact,
                                    selected: _categoryFilter == cat,
                                    onSelected: (_) => setState(() {
                                      _categoryFilter = _categoryFilter == cat
                                          ? null
                                          : cat;
                                    }),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (items.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: saku.surfaceElevated,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: saku.border, width: 1),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Total Keluar',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: saku.textMuted,
                                      ),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        IdrFormat.currency(
                                          totalExpense,
                                          hidden: hidden,
                                        ),
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: saku.expense,
                                          fontFeatures: AppTheme.tabularNums,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 26,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                color: saku.border,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Text(
                                      'Total Masuk',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: saku.textMuted,
                                      ),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        IdrFormat.currency(
                                          totalIncome,
                                          hidden: hidden,
                                        ),
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: saku.income,
                                          fontFeatures: AppTheme.tabularNums,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Divider(height: 1, color: saku.border),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  'Tidak ada transaksi yang cocok dengan filter.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (_hasActiveFilters) ...<Widget>[
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: _resetFilters,
                                    child: const Text('Reset Semua Filter'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          itemCount: groups.length,
                          itemBuilder: (context, groupIndex) {
                            final group = groups[groupIndex];
                            final netLabel = group.netAmount == 0
                                ? '${group.items.length} transaksi'
                                : IdrFormat.currency(
                                    group.netAmount,
                                    hidden: hidden,
                                    signed: true,
                                  );
                            final netColor = group.netAmount > 0
                                ? saku.income
                                : group.netAmount < 0
                                ? saku.expense
                                : saku.textMuted;

                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: groupIndex < groups.length - 1 ? 14 : 0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      0,
                                      4,
                                      6,
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            group.label,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: saku.textSecondary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          netLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: netColor,
                                            fontFeatures: AppTheme.tabularNums,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Material(
                                    color: saku.surface,
                                    clipBehavior: Clip.antiAlias,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        SakuRadius.md,
                                      ),
                                      side: BorderSide(
                                        color: saku.border,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: <Widget>[
                                        for (
                                          var i = 0;
                                          i < group.items.length;
                                          i++
                                        ) ...<Widget>[
                                          if (i > 0)
                                            Divider(
                                              height: 1,
                                              indent: 68,
                                              endIndent: 14,
                                              color: saku.border,
                                            ),
                                          TransactionTile(
                                            transaction: group.items[i],
                                            controller: widget.controller,
                                            onTap: () {
                                              final tx = group.items[i];
                                              TransactionDetailSheet.show(
                                                context,
                                                transaction: tx,
                                                controller: widget.controller,
                                                onEdit: () async {
                                                  await QuickInputSheet.show(
                                                    context,
                                                    controller:
                                                        widget.controller,
                                                    existingTransaction: tx,
                                                  );
                                                },
                                                onDelete: () =>
                                                    _handleDelete(context, tx),
                                              );
                                            },
                                            onEdit: () async {
                                              await QuickInputSheet.show(
                                                context,
                                                controller: widget.controller,
                                                existingTransaction:
                                                    group.items[i],
                                              );
                                            },
                                            onDelete: () => _handleDelete(
                                              context,
                                              group.items[i],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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

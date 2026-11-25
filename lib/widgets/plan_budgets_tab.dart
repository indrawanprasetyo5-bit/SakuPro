import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/category_meta.dart';
import '../models/roadmap_models.dart';
import '../models/transaction_item.dart';
import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import 'budget_dialog.dart';

class PlanBudgetsTab extends StatelessWidget {
  const PlanBudgetsTab({super.key, required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final hidden = controller.hideBalance;
    final catBudgets = controller.categoryBudgets;
    final totalBudget = controller.monthlyBudget;
    final totalSpent = controller.monthlyExpense;
    final totalRatio = totalBudget <= 0 ? 0.0 : totalSpent / totalBudget;
    final catSum = controller.totalCategoryBudgetsSum;

    final budgetedNames = catBudgets.map((b) => b.category).toSet();
    final unbudgetedExpenses = controller.monthlyExpenseByCategory.entries
        .where((e) => !budgetedNames.contains(e.key) && e.value > 0)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
      children: <Widget>[
        _GlobalBudgetSummaryCard(
          controller: controller,
          totalBudget: totalBudget,
          totalSpent: totalSpent,
          ratio: totalRatio,
          categorySum: catSum,
        ),
        const SizedBox(height: 22),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            Text(
              'Budget per Kategori (${catBudgets.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FilledButton.tonalIcon(
              onPressed: () => _CategoryBudgetSheet.show(
                context,
                controller: controller,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Atur Kategori'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (catBudgets.isEmpty)
          _EmptyCategoryBudgetCard(controller: controller)
        else
          for (final item in catBudgets) ...<Widget>[
            _CategoryBudgetTile(
              budget: item,
              spent: controller.spentForCategory(item.category),
              hideBalance: hidden,
              onEdit: () => _CategoryBudgetSheet.show(
                context,
                controller: controller,
                initialCategory: item.category,
                initialLimit: item.monthlyLimit,
                existingId: item.id,
              ),
            ),
            const SizedBox(height: 10),
          ],
        if (unbudgetedExpenses.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            'Pengeluaran Bulan Ini Tanpa Batas Kategori',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: saku.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: saku.border),
            ),
            child: Column(
              children: <Widget>[
                for (var i = 0; i < unbudgetedExpenses.length; i++) ...<Widget>[
                  if (i > 0) Divider(height: 16, color: saku.border),
                  Row(
                    children: <Widget>[
                      Icon(
                        CategoryCatalog.resolve(
                          TransactionKind.expense,
                          unbudgetedExpenses[i].key,
                        ).icon,
                        size: 18,
                        color: saku.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          unbudgetedExpenses[i].key,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        IdrFormat.currency(
                          unbudgetedExpenses[i].value,
                          hidden: hidden,
                        ),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: saku.textPrimary,
                          fontFeatures: AppTheme.tabularNums,
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => _CategoryBudgetSheet.show(
                          context,
                          controller: controller,
                          initialCategory: unbudgetedExpenses[i].key,
                        ),
                        child: const Text('Batas'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BudgetVisualState {
  const _BudgetVisualState({
    required this.label,
    required this.color,
    required this.softColor,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color softColor;
  final IconData icon;

  static _BudgetVisualState resolve(SakuColors saku, double ratio) {
    if (ratio > 1.0) {
      return _BudgetVisualState(
        label: 'Overbudget',
        color: saku.expense,
        softColor: saku.expenseSoft,
        icon: Icons.error_outline_rounded,
      );
    }
    if (ratio >= 0.8) {
      return _BudgetVisualState(
        label: 'Hampir Penuh',
        color: saku.warning,
        softColor: saku.warningSoft,
        icon: Icons.warning_amber_rounded,
      );
    }
    return _BudgetVisualState(
      label: 'Aman',
      color: saku.income,
      softColor: saku.incomeSoft,
      icon: Icons.check_circle_outline_rounded,
    );
  }
}

class _GlobalBudgetSummaryCard extends StatelessWidget {
  const _GlobalBudgetSummaryCard({
    required this.controller,
    required this.totalBudget,
    required this.totalSpent,
    required this.ratio,
    required this.categorySum,
  });

  final FinanceController controller;
  final int totalBudget;
  final int totalSpent;
  final double ratio;
  final int categorySum;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final hidden = controller.hideBalance;
    final visual = _BudgetVisualState.resolve(saku, ratio);
    final pct = (ratio * 100).round();
    final safe = controller.safeToSpend;

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
                  'Total Budget Bulanan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: visual.softColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(visual.icon, size: 14, color: visual.color),
                    const SizedBox(width: 4),
                    Text(
                      '${visual.label} · $pct%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: visual.color,
                        fontFeatures: AppTheme.tabularNums,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              Text(
                IdrFormat.currency(totalSpent, hidden: hidden),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: saku.textPrimary,
                  fontFeatures: AppTheme.tabularNums,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'dari batas ${IdrFormat.currency(totalBudget, hidden: hidden)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: saku.textMuted,
                    fontFeatures: AppTheme.tabularNums,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: saku.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(visual.color),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Terhubung otomatis ke Aman Jajan Hari Ini di Beranda: ${IdrFormat.currency(safe.dailySafeAmount, hidden: hidden)} / hari.',
            style: TextStyle(
              fontSize: 12.5,
              color: saku.textSecondary,
              fontFeatures: AppTheme.tabularNums,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () =>
                    BudgetDialog.show(context, controller: controller),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Ubah Total Budget'),
              ),
              if (categorySum > 0 && categorySum != totalBudget)
                TextButton.icon(
                  onPressed: () async {
                    await controller.setMonthlyBudget(categorySum);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Total budget disamakan dengan jumlah kategori.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: Text(
                    'Samakan ke Kategori (${IdrFormat.compact(categorySum, hidden: hidden)})',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetTile extends StatelessWidget {
  const _CategoryBudgetTile({
    required this.budget,
    required this.spent,
    required this.hideBalance,
    required this.onEdit,
  });

  final BudgetModel budget;
  final int spent;
  final bool hideBalance;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final meta = CategoryCatalog.resolve(
      TransactionKind.expense,
      budget.category,
    );
    final ratio = budget.monthlyLimit <= 0 ? 0.0 : spent / budget.monthlyLimit;
    final visual = _BudgetVisualState.resolve(saku, ratio);
    final pct = (ratio * 100).round();
    final diff = budget.monthlyLimit - spent;

    return Material(
      color: saku.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: saku.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(meta.icon, size: 19, color: meta.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          budget.category,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          diff >= 0
                              ? 'Sisa ${IdrFormat.currency(diff, hidden: hideBalance)}'
                              : 'Lewat ${IdrFormat.currency(diff.abs(), hidden: hideBalance)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: diff >= 0 ? saku.textMuted : saku.expense,
                            fontFeatures: AppTheme.tabularNums,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: visual.softColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$pct% · ${visual.label}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: visual.color,
                        fontFeatures: AppTheme.tabularNums,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: saku.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation<Color>(visual.color),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Terpakai ${IdrFormat.currency(spent, hidden: hideBalance)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: saku.textSecondary,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                  Text(
                    'Batas ${IdrFormat.currency(budget.monthlyLimit, hidden: hideBalance)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: saku.textPrimary,
                      fontFeatures: AppTheme.tabularNums,
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

class _EmptyCategoryBudgetCard extends StatelessWidget {
  const _EmptyCategoryBudgetCard({required this.controller});

  final FinanceController controller;

  static const List<String> _starterCategories = <String>[
    'Makan & Minum',
    'Ngopi',
    'Transportasi',
    'Belanja',
    'Tagihan & Utilitas',
    'Hiburan',
  ];

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
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
          Text(
            'Belum ada batas budget per kategori',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Pilih kategori di bawah untuk menetapkan plafon bulanan dan memantau progres pemakaian secara langsung.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _starterCategories.map((cat) {
              return ActionChip(
                label: Text(cat),
                onPressed: () => _CategoryBudgetSheet.show(
                  context,
                  controller: controller,
                  initialCategory: cat,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetSheet extends StatefulWidget {
  const _CategoryBudgetSheet({
    required this.controller,
    this.initialCategory,
    this.initialLimit,
    this.existingId,
  });

  final FinanceController controller;
  final String? initialCategory;
  final int? initialLimit;
  final int? existingId;

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    String? initialCategory,
    int? initialLimit,
    int? existingId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _CategoryBudgetSheet(
        controller: controller,
        initialCategory: initialCategory,
        initialLimit: initialLimit,
        existingId: existingId,
      ),
    );
  }

  @override
  State<_CategoryBudgetSheet> createState() => _CategoryBudgetSheetState();
}

class _CategoryBudgetSheetState extends State<_CategoryBudgetSheet> {
  static const List<int> _presets = <int>[250000, 500000, 1000000, 1500000];

  late String _category;
  late final TextEditingController _limitController;

  @override
  void initState() {
    super.initState();
    _category =
        widget.initialCategory ??
        CategoryCatalog.expenseCategories.first.name;
    _limitController = TextEditingController(
      text: widget.initialLimit != null ? widget.initialLimit.toString() : '',
    );
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  int _parsedLimit() {
    final digits = _limitController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  Future<void> _save() async {
    final limit = _parsedLimit();
    if (limit <= 0) {
      return;
    }
    await widget.controller.upsertCategoryBudget(
      category: _category,
      monthlyLimit: limit,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    if (widget.existingId == null) {
      return;
    }
    await widget.controller.deleteCategoryBudget(widget.existingId!);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final limitVal = _parsedLimit();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.existingId != null
                        ? 'Edit Budget Kategori'
                        : 'Atur Budget Kategori',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (widget.existingId != null)
                  IconButton(
                    tooltip: 'Hapus batas kategori',
                    onPressed: _delete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: saku.expense,
                    ),
                  ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: saku.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Pilih Kategori', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CategoryCatalog.expenseCategories.map((cat) {
                final selected = cat.name == _category;
                return ChoiceChip(
                  avatar: Icon(cat.icon, size: 16, color: cat.color),
                  label: Text(cat.name),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = cat.name),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Batas Bulanan (Rp)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (limitVal > 0)
                  Text(
                    IdrFormat.currency(limitVal),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: saku.brandInteractive,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _limitController,
              autofocus: widget.initialLimit == null,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFeatures: AppTheme.tabularNums,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                hintText: '500000',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((val) {
                return ActionChip(
                  label: Text(
                    IdrFormat.compact(val),
                    style: TextStyle(
                      fontSize: 12,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _limitController.text = val.toString();
                      _limitController.selection = TextSelection.collapsed(
                        offset: _limitController.text.length,
                      );
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: limitVal > 0 ? _save : null,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text('Simpan Budget Kategori'),
            ),
          ],
        ),
      ),
    );
  }
}

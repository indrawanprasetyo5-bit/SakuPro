import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../models/roadmap_models.dart';
import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';

class PlanGoalsTab extends StatelessWidget {
  const PlanGoalsTab({super.key, required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final goals = controller.goals;
    final hidden = controller.hideBalance;

    var totalSaved = 0;
    var totalTarget = 0;
    for (final g in goals) {
      totalSaved += g.currentAmount;
      totalTarget += g.targetAmount;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
      children: <Widget>[
        _GoalsHeaderCard(
          goalCount: goals.length,
          totalSaved: totalSaved,
          totalTarget: totalTarget,
          hideBalance: hidden,
          onAddGoal: () => _GoalFormSheet.show(context, controller: controller),
        ),
        const SizedBox(height: 20),
        if (goals.isEmpty)
          _EmptyGoalsCard(controller: controller)
        else
          for (final goal in goals) ...<Widget>[
            _GoalItemCard(
              goal: goal,
              hideBalance: hidden,
              onAddSavings: () => _GoalContributionSheet.show(
                context,
                controller: controller,
                goal: goal,
              ),
              onEdit: () => _GoalFormSheet.show(
                context,
                controller: controller,
                existingGoal: goal,
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _GoalsHeaderCard extends StatelessWidget {
  const _GoalsHeaderCard({
    required this.goalCount,
    required this.totalSaved,
    required this.totalTarget,
    required this.hideBalance,
    required this.onAddGoal,
  });

  final int goalCount;
  final int totalSaved;
  final int totalTarget;
  final bool hideBalance;
  final VoidCallback onAddGoal;

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Total Dana Target Terkumpul',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: saku.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    IdrFormat.currency(totalSaved, hidden: hideBalance),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: saku.textPrimary,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: onAddGoal,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Target Baru'),
              ),
            ],
          ),
          if (goalCount > 0) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '$goalCount target aktif · akumulasi target ${IdrFormat.currency(totalTarget, hidden: hideBalance)}',
              style: TextStyle(
                fontSize: 12.5,
                color: saku.textSecondary,
                fontFeatures: AppTheme.tabularNums,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalItemCard extends StatelessWidget {
  const _GoalItemCard({
    required this.goal,
    required this.hideBalance,
    required this.onAddSavings,
    required this.onEdit,
  });

  final GoalModel goal;
  final bool hideBalance;
  final VoidCallback onAddSavings;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final pct = (goal.progressRatio * 100).clamp(0, 999).round();
    final completed = goal.reachedTarget;

    return Material(
      color: saku.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: saku.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: goal.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(goal.icon, size: 22, color: goal.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          goal.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          goal.deadline != null
                              ? 'Target waktu: ${DateFormat('dd MMM yyyy').format(goal.deadline!)}'
                              : 'Tanpa tenggat waktu',
                          style: TextStyle(
                            fontSize: 12,
                            color: saku.textMuted,
                            fontFeatures: AppTheme.tabularNums,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: completed ? saku.incomeSoft : saku.surfaceMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      completed ? 'Tercapai · $pct%' : '$pct%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: completed ? saku.income : saku.textPrimary,
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
                  value: goal.progressRatio.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: saku.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completed ? saku.income : goal.color,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${IdrFormat.currency(goal.currentAmount, hidden: hideBalance)} / ${IdrFormat.currency(goal.targetAmount, hidden: hideBalance)}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: saku.textPrimary,
                          fontFeatures: AppTheme.tabularNums,
                        ),
                      ),
                      if (!completed)
                        Text(
                          'Kurang ${IdrFormat.currency(goal.remainingAmount, hidden: hideBalance)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: saku.textMuted,
                            fontFeatures: AppTheme.tabularNums,
                          ),
                        ),
                    ],
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onAddSavings,
                    icon: const Icon(Icons.savings_outlined, size: 17),
                    label: const Text('Tambah Tabungan'),
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

class _EmptyGoalsCard extends StatelessWidget {
  const _EmptyGoalsCard({required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: saku.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: saku.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Mulai target tabungan pertamamu',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Buat target seperti Dana Darurat, Laptop Baru, atau Liburan. Setiap setoran dapat langsung memotong saldo dompet terpilih secara otomatis.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ActionChip(
                avatar: const Icon(Icons.verified_user_outlined, size: 16),
                label: const Text('Dana Darurat'),
                onPressed: () => _GoalFormSheet.show(
                  context,
                  controller: controller,
                  presetName: 'Dana Darurat',
                  presetIcon: 'shield',
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.laptop_mac_rounded, size: 16),
                label: const Text('Laptop Baru'),
                onPressed: () => _GoalFormSheet.show(
                  context,
                  controller: controller,
                  presetName: 'Laptop Baru',
                  presetIcon: 'laptop',
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.flight_takeoff_rounded, size: 16),
                label: const Text('Liburan'),
                onPressed: () => _GoalFormSheet.show(
                  context,
                  controller: controller,
                  presetName: 'Liburan',
                  presetIcon: 'flight',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalFormSheet extends StatefulWidget {
  const _GoalFormSheet({
    required this.controller,
    this.existingGoal,
    this.presetName,
    this.presetIcon,
  });

  final FinanceController controller;
  final GoalModel? existingGoal;
  final String? presetName;
  final String? presetIcon;

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    GoalModel? existingGoal,
    String? presetName,
    String? presetIcon,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _GoalFormSheet(
        controller: controller,
        existingGoal: existingGoal,
        presetName: presetName,
        presetIcon: presetIcon,
      ),
    );
  }

  @override
  State<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<_GoalFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late String _iconKey;
  late int _colorValue;
  DateTime? _deadline;
  String? _error;

  bool get _isEditing => widget.existingGoal != null;

  @override
  void initState() {
    super.initState();
    final g = widget.existingGoal;
    _nameController = TextEditingController(
      text: g?.name ?? widget.presetName ?? '',
    );
    _targetController = TextEditingController(
      text: g != null ? g.targetAmount.toString() : '',
    );
    _iconKey = g?.iconKey ?? widget.presetIcon ?? 'savings';
    _colorValue = g?.colorValue ?? GoalIconCatalog.colors.first;
    _deadline = g?.deadline;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  int _parsedTarget() {
    final digits = _targetController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  Future<void> _pickDeadline() async {
    final now = widget.controller.now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 90)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final target = _parsedTarget();
    if (name.isEmpty) {
      setState(() => _error = 'Nama target wajib diisi.');
      return;
    }
    if (target <= 0) {
      setState(() => _error = 'Nominal target harus lebih dari Rp 0.');
      return;
    }

    if (_isEditing) {
      final updated = widget.existingGoal!.copyWith(
        name: name,
        targetAmount: target,
        iconKey: _iconKey,
        colorValue: _colorValue,
        deadline: _deadline,
        clearDeadline: _deadline == null,
      );
      await widget.controller.updateGoal(updated);
    } else {
      await widget.controller.addGoal(
        name: name,
        targetAmount: target,
        deadline: _deadline,
        colorValue: _colorValue,
        iconKey: _iconKey,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final id = widget.existingGoal?.id;
    if (id == null) {
      return;
    }
    await widget.controller.deleteGoal(id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final targetVal = _parsedTarget();

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
                    _isEditing ? 'Edit Target Tabungan' : 'Target Tabungan Baru',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    tooltip: 'Hapus target',
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
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                labelText: 'Nama Target Impian',
                hintText: 'Mis. Dana Darurat, Laptop Baru, Liburan',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Nominal Target (Rp)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (targetVal > 0)
                  Text(
                    IdrFormat.currency(targetVal),
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
              controller: _targetController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFeatures: AppTheme.tabularNums,
              ),
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                hintText: '10000000',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDeadline,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      _deadline != null
                          ? 'Tenggat: ${DateFormat('dd MMM yyyy').format(_deadline!)}'
                          : 'Pilih Deadline (Opsional)',
                    ),
                  ),
                ),
                if (_deadline != null) ...<Widget>[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Hapus deadline',
                    onPressed: () => setState(() => _deadline = null),
                    icon: const Icon(Icons.clear_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text('Ikon & Warna', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GoalIconCatalog.icons.entries.map((entry) {
                final selected = _iconKey == entry.key;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _iconKey = entry.key),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected ? saku.brandSoft : saku.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? saku.brandInteractive : saku.border,
                      ),
                    ),
                    child: Icon(
                      entry.value,
                      size: 20,
                      color: selected
                          ? saku.brandInteractive
                          : saku.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: GoalIconCatalog.colors.map((hex) {
                final selected = _colorValue == hex;
                return InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _colorValue = hex),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? saku.textPrimary : Colors.transparent,
                        width: 2.2,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: saku.expense,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(_isEditing ? 'Simpan Perubahan' : 'Buat Target'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalContributionSheet extends StatefulWidget {
  const _GoalContributionSheet({
    required this.controller,
    required this.goal,
  });

  final FinanceController controller;
  final GoalModel goal;

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    required GoalModel goal,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) =>
          _GoalContributionSheet(controller: controller, goal: goal),
    );
  }

  @override
  State<_GoalContributionSheet> createState() => _GoalContributionSheetState();
}

class _GoalContributionSheetState extends State<_GoalContributionSheet> {
  static const List<int> _increments = <int>[50000, 100000, 250000, 500000];

  final TextEditingController _amountController = TextEditingController();
  int? _walletId;

  @override
  void initState() {
    super.initState();
    if (widget.controller.wallets.isNotEmpty) {
      _walletId = widget.controller.wallets.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int _parsed() {
    final digits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  Future<void> _submit() async {
    final amount = _parsed();
    final goalId = widget.goal.id;
    if (amount <= 0 || _walletId == null || goalId == null) {
      return;
    }
    await widget.controller.contributeToGoal(
      goalId: goalId,
      amount: amount,
      walletId: _walletId!,
    );
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Setoran ${IdrFormat.currency(amount)} ke "${widget.goal.name}" berhasil dicatat.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final amount = _parsed();
    final remaining = widget.goal.remainingAmount;

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
                    'Tambah Tabungan · ${widget.goal.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: saku.textSecondary),
                ),
              ],
            ),
            Text(
              'Memotong saldo dari dompet terpilih dan mencatatnya di riwayat transaksi.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFeatures: AppTheme.tabularNums,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                labelText: 'Nominal Setoran',
                hintText: '100000',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final inc in _increments)
                  ActionChip(
                    label: Text(
                      '+${IdrFormat.compact(inc).replaceFirst('Rp ', '')}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFeatures: AppTheme.tabularNums,
                      ),
                    ),
                    onPressed: () {
                      final next = _parsed() + inc;
                      setState(() {
                        _amountController.text = next.toString();
                        _amountController.selection = TextSelection.collapsed(
                          offset: _amountController.text.length,
                        );
                      });
                    },
                  ),
                if (remaining > 0)
                  ActionChip(
                    label: Text(
                      'Lunasi Sisa (${IdrFormat.compact(remaining)})',
                      style: TextStyle(
                        fontSize: 12,
                        fontFeatures: AppTheme.tabularNums,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _amountController.text = remaining.toString();
                        _amountController.selection = TextSelection.collapsed(
                          offset: _amountController.text.length,
                        );
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Potong dari Dompet',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.controller.wallets.map((w) {
                final selected = w.id == _walletId;
                return ChoiceChip(
                  label: Text(
                    '${w.name} (${IdrFormat.compact(w.balance, hidden: widget.controller.hideBalance)})',
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() => _walletId = w.id),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: amount > 0 && _walletId != null ? _submit : null,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(
                amount > 0
                    ? 'Simpan Setoran (${IdrFormat.currency(amount)})'
                    : 'Masukkan Nominal Setoran',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

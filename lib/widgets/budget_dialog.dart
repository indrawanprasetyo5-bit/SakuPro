import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import 'luxury_widgets.dart';

class BudgetDialog extends StatefulWidget {
  const BudgetDialog({super.key, required this.controller});

  final FinanceController controller;

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
  }) {
    return showSakuBottomSheet<void>(
      context: context,
      builder: (ctx) => BudgetDialog(controller: controller),
    );
  }

  @override
  State<BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<BudgetDialog> {
  static const List<int> _presets = <int>[
    1500000,
    3000000,
    5000000,
    7500000,
    10000000,
  ];

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.controller.monthlyBudget.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _parsed() {
    final digits = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  Future<void> _submit() async {
    final val = _parsed();
    if (val <= 0) {
      return;
    }
    HapticFeedback.lightImpact();
    await widget.controller.setMonthlyBudget(val);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final currentVal = _parsed();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SakuSheetHandle(),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Atur Limit Bulanan',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dipakai buat hitung jatah Aman Dipakai Hari Ini secara otomatis.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: saku.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: saku.textPrimary,
                fontFeatures: AppTheme.tabularNums,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                labelText: 'Batas pengeluaran sebulan',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Terbaca ${IdrFormat.currency(currentVal)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: saku.brandInteractive,
                fontFeatures: AppTheme.tabularNums,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((preset) {
                final selected = currentVal == preset;
                return TactilePressScale(
                  child: ChoiceChip(
                    selected: selected,
                    label: Text(
                      IdrFormat.compact(preset),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? saku.brandInteractive
                            : saku.textPrimary,
                        fontFeatures: AppTheme.tabularNums,
                      ),
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _controller.text = preset.toString();
                        _controller.selection = TextSelection.collapsed(
                          offset: _controller.text.length,
                        );
                      });
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: currentVal > 0 ? _submit : null,
                    child: const Text('Simpan Limit'),
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

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';

class BudgetDialog extends StatefulWidget {
  const BudgetDialog({super.key, required this.controller});

  final FinanceController controller;

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
  }) {
    return showDialog<void>(
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
    await widget.controller.setMonthlyBudget(val);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final currentVal = _parsed();

    return AlertDialog(
      title: const Text('Atur Budget Bulanan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Digunakan untuk menghitung batas Aman Jajan Hari Ini secara otomatis.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
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
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                labelText: 'Plafon Pengeluaran Bulanan',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Terbaca: ${IdrFormat.currency(currentVal)}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: saku.brandInteractive,
                fontFeatures: AppTheme.tabularNums,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((preset) {
                return ActionChip(
                  label: Text(
                    IdrFormat.compact(preset),
                    style: TextStyle(
                      fontSize: 12,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _controller.text = preset.toString();
                      _controller.selection = TextSelection.collapsed(
                        offset: _controller.text.length,
                      );
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: currentVal > 0 ? _submit : null,
          child: const Text('Simpan Budget'),
        ),
      ],
    );
  }
}

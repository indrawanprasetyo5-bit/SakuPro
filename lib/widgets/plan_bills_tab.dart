import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/category_meta.dart';
import '../models/roadmap_models.dart';
import '../models/transaction_item.dart';
import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';

class PlanBillsTab extends StatelessWidget {
  const PlanBillsTab({super.key, required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final bills = controller.bills;
    final now = controller.now;
    final hidden = controller.hideBalance;

    final paidCount = bills.where((b) => b.isPaidFor(now)).length;
    final unpaidTotal = controller.unpaidBillsTotal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
      children: <Widget>[
        _BillsSummaryCard(
          totalCount: bills.length,
          paidCount: paidCount,
          unpaidTotal: unpaidTotal,
          hideBalance: hidden,
          onAddBill: () => _BillFormSheet.show(context, controller: controller),
        ),
        const SizedBox(height: 20),
        if (bills.isEmpty)
          _EmptyBillsCard(controller: controller)
        else
          for (final bill in bills) ...<Widget>[
            _BillItemCard(
              bill: bill,
              isPaid: bill.isPaidFor(now),
              currentDay: now.day,
              hideBalance: hidden,
              defaultWalletName: controller
                  .walletById(bill.walletId ?? controller.wallets.firstOrNull?.id)
                  ?.name,
              onPayNow: () => _PayBillSheet.show(
                context,
                controller: controller,
                bill: bill,
              ),
              onMarkUnpaid: bill.id != null
                  ? () => controller.markBillUnpaid(bill.id!)
                  : null,
              onEdit: () => _BillFormSheet.show(
                context,
                controller: controller,
                existingBill: bill,
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _BillsSummaryCard extends StatelessWidget {
  const _BillsSummaryCard({
    required this.totalCount,
    required this.paidCount,
    required this.unpaidTotal,
    required this.hideBalance,
    required this.onAddBill,
  });

  final int totalCount;
  final int paidCount;
  final int unpaidTotal;
  final bool hideBalance;
  final VoidCallback onAddBill;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final unpaidCount = totalCount - paidCount;

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
                    'Tagihan Belum Dibayar Bulan Ini',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: saku.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    IdrFormat.currency(unpaidTotal, hidden: hideBalance),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: unpaidTotal > 0 ? saku.textPrimary : saku.income,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: onAddBill,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Tagihan Baru'),
              ),
            ],
          ),
          if (totalCount > 0) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '$paidCount lunas · $unpaidCount belum dibayar bulan ini',
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

class _BillItemCard extends StatelessWidget {
  const _BillItemCard({
    required this.bill,
    required this.isPaid,
    required this.currentDay,
    required this.hideBalance,
    required this.defaultWalletName,
    required this.onPayNow,
    required this.onMarkUnpaid,
    required this.onEdit,
  });

  final BillModel bill;
  final bool isPaid;
  final int currentDay;
  final bool hideBalance;
  final String? defaultWalletName;
  final VoidCallback onPayNow;
  final VoidCallback? onMarkUnpaid;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final meta = CategoryCatalog.resolve(
      TransactionKind.expense,
      bill.category,
    );
    final isDueSoon = !isPaid && bill.dueDay <= currentDay + 3;

    final statusColor = isPaid
        ? saku.income
        : (isDueSoon ? saku.expense : saku.warning);
    final statusSoft = isPaid
        ? saku.incomeSoft
        : (isDueSoon ? saku.expenseSoft : saku.warningSoft);
    final statusText = isPaid
        ? 'Lunas Bulan Ini'
        : (bill.dueDay < currentDay ? 'Jatuh Tempo Lewat' : 'Belum Bayar');

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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(meta.icon, size: 20, color: meta.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          bill.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Jatuh tempo tgl ${bill.dueDay} tiap bulan · ${bill.category}',
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
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          isPaid
                              ? Icons.check_circle_outline_rounded
                              : Icons.schedule_rounded,
                          size: 13,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                        IdrFormat.currency(bill.amount, hidden: hideBalance),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: saku.textPrimary,
                          fontFeatures: AppTheme.tabularNums,
                        ),
                      ),
                      if (defaultWalletName != null)
                        Text(
                          'Dompet utama: $defaultWalletName',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: saku.textMuted,
                          ),
                        ),
                    ],
                  ),
                  if (!isPaid)
                    FilledButton.icon(
                      onPressed: onPayNow,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Bayar Sekarang'),
                    )
                  else
                    TextButton.icon(
                      onPressed: onMarkUnpaid,
                      icon: const Icon(Icons.undo_rounded, size: 16),
                      label: const Text('Tandai Belum Bayar'),
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

class _EmptyBillsCard extends StatelessWidget {
  const _EmptyBillsCard({required this.controller});

  final FinanceController controller;

  static const List<(String, String)> _presets = <(String, String)>[
    ('Kos / Kontrakan', 'Tagihan & Utilitas'),
    ('WiFi Rumah', 'Tagihan & Utilitas'),
    ('Paket Kuota', 'Tagihan & Utilitas'),
    ('Langganan Streaming', 'Hiburan'),
    ('Cicilan Bulanan', 'Tagihan & Utilitas'),
  ];

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
            'Belum ada jadwal tagihan rutin',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Simpan daftar tagihan bulanan agar tidak terlewat. Saat dibayar, sistem otomatis memotong dompet dan mencatat pengeluaran.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((item) {
              return ActionChip(
                label: Text(item.$1),
                onPressed: () => _BillFormSheet.show(
                  context,
                  controller: controller,
                  presetName: item.$1,
                  presetCategory: item.$2,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PayBillSheet extends StatefulWidget {
  const _PayBillSheet({
    required this.controller,
    required this.bill,
  });

  final FinanceController controller;
  final BillModel bill;

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    required BillModel bill,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => _PayBillSheet(controller: controller, bill: bill),
    );
  }

  @override
  State<_PayBillSheet> createState() => _PayBillSheetState();
}

class _PayBillSheetState extends State<_PayBillSheet> {
  int? _walletId;

  @override
  void initState() {
    super.initState();
    _walletId =
        widget.bill.walletId ?? widget.controller.wallets.firstOrNull?.id;
  }

  Future<void> _confirmPay() async {
    final billId = widget.bill.id;
    if (billId == null || _walletId == null) {
      return;
    }
    await widget.controller.payBillNow(
      billId: billId,
      walletId: _walletId!,
    );
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tagihan "${widget.bill.name}" lunas dan tercatat di pengeluaran.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final hidden = widget.controller.hideBalance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Bayar Tagihan · ${widget.bill.name}',
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
          const SizedBox(height: 6),
          Text(
            'Nominal pengeluaran sebesar ${IdrFormat.currency(widget.bill.amount, hidden: hidden)} akan dicatat otomatis.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Text('Pilih Dompet Pembayaran', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.controller.wallets.map((w) {
              final selected = w.id == _walletId;
              return ChoiceChip(
                label: Text(
                  '${w.name} (${IdrFormat.compact(w.balance, hidden: hidden)})',
                ),
                selected: selected,
                onSelected: (_) => setState(() => _walletId = w.id),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _walletId != null ? _confirmPay : null,
            icon: const Icon(Icons.check_rounded, size: 20),
            label: Text(
              'Konfirmasi Lunas (${IdrFormat.currency(widget.bill.amount, hidden: hidden)})',
            ),
          ),
        ],
      ),
    );
  }
}

class _BillFormSheet extends StatefulWidget {
  const _BillFormSheet({
    required this.controller,
    this.existingBill,
    this.presetName,
    this.presetCategory,
  });

  final FinanceController controller;
  final BillModel? existingBill;
  final String? presetName;
  final String? presetCategory;

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    BillModel? existingBill,
    String? presetName,
    String? presetCategory,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _BillFormSheet(
        controller: controller,
        existingBill: existingBill,
        presetName: presetName,
        presetCategory: presetCategory,
      ),
    );
  }

  @override
  State<_BillFormSheet> createState() => _BillFormSheetState();
}

class _BillFormSheetState extends State<_BillFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _dueDayController;
  late String _category;
  int? _walletId;
  String? _error;

  bool get _isEditing => widget.existingBill != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existingBill;
    _nameController = TextEditingController(
      text: b?.name ?? widget.presetName ?? '',
    );
    _amountController = TextEditingController(
      text: b != null ? b.amount.toString() : '',
    );
    _dueDayController = TextEditingController(
      text: (b?.dueDay ?? 5).toString(),
    );
    _category = b?.category ?? widget.presetCategory ?? 'Tagihan & Utilitas';
    _walletId = b?.walletId ?? widget.controller.wallets.firstOrNull?.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  int _parsedAmount() {
    final digits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  int _parsedDueDay() {
    final digits = _dueDayController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return (int.tryParse(digits) ?? 1).clamp(1, 31);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amount = _parsedAmount();
    if (name.isEmpty) {
      setState(() => _error = 'Nama tagihan wajib diisi.');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Nominal tagihan harus lebih dari Rp 0.');
      return;
    }

    if (_isEditing) {
      await widget.controller.updateBill(
        widget.existingBill!.copyWith(
          name: name,
          amount: amount,
          category: _category,
          dueDay: _parsedDueDay(),
          walletId: _walletId,
        ),
      );
    } else {
      await widget.controller.addBill(
        name: name,
        amount: amount,
        category: _category,
        dueDay: _parsedDueDay(),
        walletId: _walletId,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final id = widget.existingBill?.id;
    if (id == null) {
      return;
    }
    await widget.controller.deleteBill(id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final amountVal = _parsedAmount();

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
                    _isEditing ? 'Edit Tagihan Rutin' : 'Tagihan Rutin Baru',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    tooltip: 'Hapus tagihan',
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
                labelText: 'Nama Tagihan',
                hintText: 'Mis. Kos, WiFi IndiHome, Kuota, Cicilan',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    decoration: const InputDecoration(
                      prefixText: 'Rp ',
                      labelText: 'Nominal Bulanan',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _dueDayController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Tgl (1-31)',
                    ),
                  ),
                ),
              ],
            ),
            if (amountVal > 0) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Nominal: ${IdrFormat.currency(amountVal)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: saku.brandInteractive,
                  fontFeatures: AppTheme.tabularNums,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text('Kategori', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CategoryCatalog.expenseCategories.map((cat) {
                return ChoiceChip(
                  label: Text(cat.name),
                  selected: cat.name == _category,
                  onSelected: (_) => setState(() => _category = cat.name),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text(
              'Dompet Default Pembayaran',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.controller.wallets.map((w) {
                return ChoiceChip(
                  label: Text(w.name),
                  selected: w.id == _walletId,
                  onSelected: (_) => setState(() => _walletId = w.id),
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
              label: Text(_isEditing ? 'Simpan Perubahan' : 'Simpan Tagihan'),
            ),
          ],
        ),
      ),
    );
  }
}

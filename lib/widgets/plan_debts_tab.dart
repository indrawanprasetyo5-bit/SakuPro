import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../models/roadmap_models.dart';
import '../services/finance_controller.dart';
import '../services/whatsapp_helper.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import 'split_bill_sheet.dart';

class PlanDebtsTab extends StatefulWidget {
  const PlanDebtsTab({super.key, required this.controller});

  final FinanceController controller;

  @override
  State<PlanDebtsTab> createState() => _PlanDebtsTabState();
}

class _PlanDebtsTabState extends State<PlanDebtsTab> {
  DebtKind _activeFilter = DebtKind.receivable;

  Future<void> _sendWhatsAppReminder(DebtModel debt) async {
    try {
      final launched = await WhatsAppHelper.launchDebtReminder(debt);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak dapat membuka aplikasi WhatsApp pada perangkat ini.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal meluncurkan tautan WhatsApp.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final hidden = widget.controller.hideBalance;
    final filtered = widget.controller.debts
        .where((d) => d.kind == _activeFilter)
        .toList();

    final isReceivableView = _activeFilter == DebtKind.receivable;
    final activeTotal = isReceivableView
        ? widget.controller.activeReceivablesTotal
        : widget.controller.activePayablesTotal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: saku.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: saku.border),
          ),
          child: Row(
            children: DebtKind.values.map((kind) {
              final selected = _activeFilter == kind;
              return Expanded(
                child: Material(
                  color: selected ? saku.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => setState(() => _activeFilter = kind),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        kind == DebtKind.receivable
                            ? 'Piutang (Orang Pinjam)'
                            : 'Hutang (Saya Pinjam)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? saku.brandInteractive
                              : saku.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: saku.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: saku.border),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    isReceivableView
                        ? 'Sisa Piutang Belum Kembali'
                        : 'Sisa Hutang Belum Lunas',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: saku.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    IdrFormat.currency(activeTotal, hidden: hidden),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isReceivableView ? saku.income : saku.expense,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (isReceivableView)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final count = await SplitBillSheet.show(
                          context,
                          controller: widget.controller,
                        );
                        if (count != null && count > 0 && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Patungan tersimpan ($count piutang baru).',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.groups_outlined, size: 18),
                      label: const Text('Patungan'),
                    ),
                  FilledButton.icon(
                    onPressed: () => _DebtFormSheet.show(
                      context,
                      controller: widget.controller,
                      initialKind: _activeFilter,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: Text(
                      isReceivableView ? 'Catat Piutang' : 'Catat Hutang',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (filtered.isEmpty)
          _EmptyDebtsCard(
            kind: _activeFilter,
            onAdd: () => _DebtFormSheet.show(
              context,
              controller: widget.controller,
              initialKind: _activeFilter,
            ),
          )
        else
          for (final debt in filtered) ...<Widget>[
            _DebtItemCard(
              debt: debt,
              hideBalance: hidden,
              onRecordPayment: () => _DebtInstallmentSheet.show(
                context,
                controller: widget.controller,
                debt: debt,
              ),
              onRemindWhatsApp: debt.isReceivable && !debt.isSettled
                  ? () => _sendWhatsAppReminder(debt)
                  : null,
              onEdit: () => _DebtFormSheet.show(
                context,
                controller: widget.controller,
                existingDebt: debt,
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _DebtItemCard extends StatelessWidget {
  const _DebtItemCard({
    required this.debt,
    required this.hideBalance,
    required this.onRecordPayment,
    required this.onRemindWhatsApp,
    required this.onEdit,
  });

  final DebtModel debt;
  final bool hideBalance;
  final VoidCallback onRecordPayment;
  final VoidCallback? onRemindWhatsApp;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final settled = debt.isSettled;
    final initial = debt.personName.isNotEmpty
        ? debt.personName.trim()[0].toUpperCase()
        : '?';

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
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: debt.isReceivable
                          ? saku.incomeSoft
                          : saku.expenseSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: debt.isReceivable ? saku.income : saku.expense,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          debt.personName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          <String>[
                            if (debt.dueDate != null)
                              'Jatuh tempo ${DateFormat('dd MMM yyyy').format(debt.dueDate!)}',
                            if (debt.phone.isNotEmpty) 'WA: ${debt.phone}',
                          ].isEmpty
                              ? 'Tanpa tenggat waktu'
                              : <String>[
                                  if (debt.dueDate != null)
                                    'Jatuh tempo ${DateFormat('dd MMM yyyy').format(debt.dueDate!)}',
                                  if (debt.phone.isNotEmpty) 'WA: ${debt.phone}',
                                ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                      color: settled ? saku.incomeSoft : saku.warningSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      settled ? 'Lunas' : 'Aktif',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: settled ? saku.income : saku.warning,
                      ),
                    ),
                  ),
                ],
              ),
              if (debt.note.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(debt.note, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: debt.progressRatio.clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: saku.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    settled ? saku.income : saku.brandInteractive,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Terbayar ${IdrFormat.currency(debt.paidAmount, hidden: hideBalance)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: saku.textSecondary,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                  Text(
                    'Sisa ${IdrFormat.currency(debt.remainingAmount, hidden: hideBalance)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: settled ? saku.income : saku.textPrimary,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                ],
              ),
              if (!settled) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: onRecordPayment,
                      icon: const Icon(Icons.payments_outlined, size: 17),
                      label: const Text('Catat Cicilan'),
                    ),
                    if (onRemindWhatsApp != null)
                      OutlinedButton.icon(
                        onPressed: onRemindWhatsApp,
                        icon: Icon(
                          Icons.chat_outlined,
                          size: 17,
                          color: saku.income,
                        ),
                        label: const Text('Ingatkan WA'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDebtsCard extends StatelessWidget {
  const _EmptyDebtsCard({required this.kind, required this.onAdd});

  final DebtKind kind;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final isReceivable = kind == DebtKind.receivable;

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
            isReceivable
                ? 'Tidak ada piutang aktif'
                : 'Tidak ada catatan hutang aktif',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            isReceivable
                ? 'Catat orang yang meminjam uang darimu lengkap dengan nomor WhatsApp untuk mengirim pengingat sopan dalam satu ketukan.'
                : 'Catat pinjaman beserta tenggat dan cicilan bertahap agar riwayat pelunasan selalu rapi.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              isReceivable ? 'Tambah Catatan Piutang' : 'Tambah Catatan Hutang',
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtFormSheet extends StatefulWidget {
  const _DebtFormSheet({
    required this.controller,
    this.existingDebt,
    this.initialKind = DebtKind.receivable,
  });

  final FinanceController controller;
  final DebtModel? existingDebt;
  final DebtKind initialKind;

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    DebtModel? existingDebt,
    DebtKind initialKind = DebtKind.receivable,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _DebtFormSheet(
        controller: controller,
        existingDebt: existingDebt,
        initialKind: existingDebt?.kind ?? initialKind,
      ),
    );
  }

  @override
  State<_DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends State<_DebtFormSheet> {
  late DebtKind _kind;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  DateTime? _dueDate;
  String? _error;

  bool get _isEditing => widget.existingDebt != null;

  @override
  void initState() {
    super.initState();
    final d = widget.existingDebt;
    _kind = d?.kind ?? widget.initialKind;
    _nameController = TextEditingController(text: d?.personName ?? '');
    _phoneController = TextEditingController(text: d?.phone ?? '');
    _amountController = TextEditingController(
      text: d != null ? d.principalAmount.toString() : '',
    );
    _noteController = TextEditingController(text: d?.note ?? '');
    _dueDate = d?.dueDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int _parsedAmount() {
    final digits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  Future<void> _pickDueDate() async {
    final now = widget.controller.now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 14)),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amount = _parsedAmount();
    if (name.isEmpty) {
      setState(() => _error = 'Nama orang wajib diisi.');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Nominal harus lebih dari Rp 0.');
      return;
    }

    if (_isEditing) {
      final old = widget.existingDebt!;
      final alreadyPaid = old.paidAmount;
      final newRemaining = (amount - alreadyPaid).clamp(0, amount);
      await widget.controller.updateDebt(
        old.copyWith(
          personName: name,
          phone: _phoneController.text.trim(),
          type: _kind.code,
          principalAmount: amount,
          remainingAmount: newRemaining,
          dueDate: _dueDate,
          clearDueDate: _dueDate == null,
          note: _noteController.text.trim(),
        ),
      );
    } else {
      await widget.controller.addDebt(
        personName: name,
        phone: _phoneController.text.trim(),
        kind: _kind,
        principalAmount: amount,
        dueDate: _dueDate,
        note: _noteController.text.trim(),
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final id = widget.existingDebt?.id;
    if (id == null) {
      return;
    }
    await widget.controller.deleteDebt(id);
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
                    _isEditing ? 'Edit Catatan' : 'Catat Hutang / Piutang',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    tooltip: 'Hapus catatan',
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DebtKind.values.map((k) {
                return ChoiceChip(
                  label: Text(k.label),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                labelText: 'Nama Orang / Kontak',
                hintText: 'Mis. Budi Santoso',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor WhatsApp (Opsional)',
                hintText: 'Mis. 081234567890',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
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
              decoration: InputDecoration(
                prefixText: 'Rp ',
                labelText: 'Nominal Pokok',
                helperText: amountVal > 0 ? IdrFormat.currency(amountVal) : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDueDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      _dueDate != null
                          ? 'Jatuh Tempo: ${DateFormat('dd MMM yyyy').format(_dueDate!)}'
                          : 'Pilih Jatuh Tempo (Opsional)',
                    ),
                  ),
                ),
                if (_dueDate != null) ...<Widget>[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Hapus tanggal jatuh tempo',
                    onPressed: () => setState(() => _dueDate = null),
                    icon: const Icon(Icons.clear_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Catatan (Opsional)',
                hintText: 'Mis. Talangan tiket makan bareng',
              ),
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
              label: Text(_isEditing ? 'Simpan Perubahan' : 'Simpan Catatan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtInstallmentSheet extends StatefulWidget {
  const _DebtInstallmentSheet({
    required this.controller,
    required this.debt,
  });

  final FinanceController controller;
  final DebtModel debt;

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    required DebtModel debt,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) =>
          _DebtInstallmentSheet(controller: controller, debt: debt),
    );
  }

  @override
  State<_DebtInstallmentSheet> createState() => _DebtInstallmentSheetState();
}

class _DebtInstallmentSheetState extends State<_DebtInstallmentSheet> {
  final TextEditingController _amountController = TextEditingController();
  bool _syncWithWallet = true;
  int? _walletId;

  @override
  void initState() {
    super.initState();
    _walletId = widget.controller.wallets.firstOrNull?.id;
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
    final debtId = widget.debt.id;
    final val = _parsed();
    if (debtId == null || val <= 0) {
      return;
    }
    await widget.controller.recordDebtInstallment(
      debtId: debtId,
      payAmount: val,
      walletId: _syncWithWallet ? _walletId : null,
    );
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            val >= widget.debt.remainingAmount
                ? 'Catatan ${widget.debt.personName} telah lunas.'
                : 'Cicilan ${IdrFormat.currency(val)} berhasil dicatat.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final remaining = widget.debt.remainingAmount;
    final entered = _parsed();

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
                    'Catat Pembayaran · ${widget.debt.personName}',
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
              'Sisa saat ini: ${IdrFormat.currency(remaining)}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: saku.textSecondary,
                fontFeatures: AppTheme.tabularNums,
              ),
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
                labelText: 'Nominal Cicilan / Pelunasan',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (remaining > 1)
                  ActionChip(
                    label: Text('50% (${IdrFormat.compact(remaining ~/ 2)})'),
                    onPressed: () {
                      final half = remaining ~/ 2;
                      setState(() {
                        _amountController.text = half.toString();
                        _amountController.selection = TextSelection.collapsed(
                          offset: _amountController.text.length,
                        );
                      });
                    },
                  ),
                ActionChip(
                  label: Text(
                    'Lunasi Penuh (${IdrFormat.compact(remaining)})',
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
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                widget.debt.isReceivable
                    ? 'Masukkan dana ke saldo dompet'
                    : 'Potong dana dari saldo dompet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              value: _syncWithWallet,
              onChanged: (v) => setState(() => _syncWithWallet = v),
            ),
            if (_syncWithWallet) ...<Widget>[
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
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: entered > 0 ? _submit : null,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(
                entered >= remaining && remaining > 0
                    ? 'Tandai Lunas (${IdrFormat.currency(remaining)})'
                    : 'Simpan Cicilan',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

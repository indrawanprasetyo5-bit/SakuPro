import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/automation_models.dart';
import '../models/category_meta.dart';
import '../services/export_backup_service.dart';
import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import 'luxury_widgets.dart';

class AutoCaptureSheet extends StatefulWidget {
  const AutoCaptureSheet({super.key, required this.controller});

  final FinanceController controller;

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
  }) {
    return showSakuBottomSheet<void>(
      context: context,
      builder: (ctx) => AutoCaptureSheet(controller: controller),
    );
  }

  @override
  State<AutoCaptureSheet> createState() => _AutoCaptureSheetState();
}

class _AutoCaptureSheetState extends State<AutoCaptureSheet> {
  @override
  void initState() {
    super.initState();
    widget.controller.refreshPostNotificationPermission();
  }

  Future<void> _openAddRecurringIncomeSheet() async {
    final wallets = widget.controller.wallets;
    if (wallets.isEmpty) {
      return;
    }
    final nameCtrl = TextEditingController(text: 'Gaji Bulanan');
    final amountCtrl = TextEditingController();
    var selectedDay = 25;
    var selectedWalletId = wallets.first.id ?? 1;
    var selectedCategory = CategoryCatalog.incomeCategories.first.name;

    final saved = await showSakuBottomSheet<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SakuSheetHandle(),
                    const SizedBox(height: 16),
                    Text(
                      'Jadwal Pemasukan Rutin',
                      style: Theme.of(ctx).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Pemasukan',
                        hintText: 'Contoh: Gaji Bulanan',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Nominal (Rp)',
                        prefixText: 'Rp ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: selectedDay,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tanggal Masuk Tiap Bulan',
                      ),
                      items: List<DropdownMenuItem<int>>.generate(
                        28,
                        (i) => DropdownMenuItem<int>(
                          value: i + 1,
                          child: Text('Setiap tanggal ${i + 1}'),
                        ),
                      ),
                      onChanged: (v) {
                        if (v != null) {
                          setSheetState(() => selectedDay = v);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: selectedWalletId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Dompet Tujuan',
                      ),
                      items: wallets
                          .where((w) => w.id != null)
                          .map(
                            (w) => DropdownMenuItem<int>(
                              value: w.id!,
                              child: Text(w.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setSheetState(() => selectedWalletId = v);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: CategoryCatalog.incomeCategories
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c.name,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setSheetState(() => selectedCategory = v);
                        }
                      },
                    ),
                    const SizedBox(height: 18),
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
                          flex: 2,
                          child: FilledButton(
                            onPressed: () {
                              final amount =
                                  int.tryParse(amountCtrl.text.trim()) ?? 0;
                              if (nameCtrl.text.trim().isEmpty || amount <= 0) {
                                return;
                              }
                              Navigator.of(ctx).pop(true);
                            },
                            child: const Text('Simpan Jadwal'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true) {
      final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
      if (amount > 0) {
        await widget.controller.addRecurringIncome(
          name: nameCtrl.text.trim(),
          amount: amount,
          dayOfMonth: selectedDay,
          walletId: selectedWalletId,
          category: selectedCategory,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jadwal pemasukan rutin ditambahkan.'),
            ),
          );
        }
      }
    }
    nameCtrl.dispose();
    amountCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final maxHeight = MediaQuery.sizeOf(context).height * 0.90;

        return SizedBox(
          height: maxHeight,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              const SakuSheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: saku.brandSoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.event_repeat_rounded,
                        size: 20,
                        color: saku.brandInteractive,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Pusat Otomatisasi',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '100% lokal di HP tanpa izin baca notifikasi',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: saku.border),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: <Widget>[
                    _buildShareReceiptCard(saku),
                    const SizedBox(height: 12),
                    _buildAutoGajiAndBillsCard(ctrl, saku),
                    const SizedBox(height: 12),
                    _buildAutoSaveGoalCard(ctrl, saku),
                    const SizedBox(height: 12),
                    _buildSmartAlertsCard(ctrl, saku),
                    const SizedBox(height: 12),
                    _buildAutoBackupCard(ctrl, saku),
                    const SizedBox(height: 12),
                    _buildMerchantMemoryCard(ctrl, saku),
                    const SizedBox(height: 12),
                    _buildShortcutsCard(saku),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareReceiptCard(SakuColors saku) {
    return LuxurySurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: saku.brandSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.ios_share_rounded,
              size: 19,
              color: saku.brandInteractive,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Bagikan Resi dari Aplikasi Bank',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Habis bayar QRIS atau transfer di Bank Jago, SeaBank, DANA, GoPay, atau BCA? Ketuk Bagikan lalu pilih SakuProWann. Nominal dan nama penerima langsung terbaca otomatis.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: saku.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoGajiAndBillsCard(FinanceController ctrl, SakuColors saku) {
    return LuxurySurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Auto-Gaji & Auto-Pay Tagihan',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gaji bulanan dan tagihan tetap tercatat otomatis sesuai tanggalnya.',
                      style: TextStyle(
                        fontSize: 12,
                        color: saku.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _openAddRecurringIncomeSheet,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Jadwal'),
              ),
            ],
          ),
          if (ctrl.recurringIncomes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            for (final inc in ctrl.recurringIncomes) ...<Widget>[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: saku.surfaceElevated,
                  borderRadius: BorderRadius.circular(SakuRadius.md),
                  border: Border.all(color: saku.border, width: 1),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            inc.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: saku.textPrimary,
                            ),
                          ),
                          Text(
                            '${IdrFormat.currency(inc.amount)} · Tgl ${inc.dayOfMonth} · ${ctrl.walletById(inc.walletId)?.name ?? 'Dompet'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: saku.textMuted,
                              fontFeatures: AppTheme.tabularNums,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: inc.enabled,
                      onChanged: (v) => ctrl.toggleRecurringIncome(inc.id, v),
                    ),
                    IconButton(
                      tooltip: 'Hapus jadwal',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ctrl.deleteRecurringIncome(inc.id),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: saku.expense,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Belum ada jadwal gaji rutin. Ketuk "+ Jadwal" untuk menambahkan.',
              style: TextStyle(fontSize: 12.5, color: saku.textMuted),
            ),
          ],
          if (ctrl.bills.isNotEmpty) ...<Widget>[
            Divider(height: 20, color: saku.border),
            Text(
              'Auto-Pay Tagihan Rutin',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: saku.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            for (final bill in ctrl.bills)
              if (bill.id != null)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    bill.name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${IdrFormat.currency(bill.amount)} · Jatuh tempo tgl ${bill.dueDay}',
                    style: TextStyle(
                      fontSize: 12,
                      color: saku.textMuted,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                  value: ctrl.isBillAutoPayEnabled(bill.id),
                  onChanged: (v) => ctrl.setBillAutoPay(bill.id!, v),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildAutoSaveGoalCard(FinanceController ctrl, SakuColors saku) {
    final goals = ctrl.goals;
    final activeGoal = ctrl.selectedAutoSaveGoal;

    return LuxurySurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Sisihkan Otomatis ke Target (Auto-Save)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              'Setiap gaji atau bonus masuk, langsung sisihkan ${ctrl.autoSaveGoalPercent}% ke target tabungan pilihanmu.',
              style: TextStyle(fontSize: 12, color: saku.textSecondary),
            ),
            value: ctrl.autoSaveGoalEnabled,
            onChanged: goals.isEmpty
                ? null
                : (v) => ctrl.configureAutoSaveGoal(enabled: v),
          ),
          if (goals.isEmpty)
            Text(
              'Buat minimal 1 target di tab Rencana > Goals terlebih dahulu.',
              style: TextStyle(fontSize: 12, color: saku.textMuted),
            )
          else if (ctrl.autoSaveGoalEnabled) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const <int>[10, 15, 20, 25, 30].map((pct) {
                return _PercentChip(
                  percent: pct,
                  selected: ctrl.autoSaveGoalPercent == pct,
                  onTap: () => ctrl.configureAutoSaveGoal(
                    enabled: true,
                    percent: pct,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: activeGoal?.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Target Tabungan Tujuan',
              ),
              items: goals
                  .where((g) => g.id != null)
                  .map(
                    (g) => DropdownMenuItem<int>(
                      value: g.id!,
                      child: Text(
                        '${g.name} (${IdrFormat.compact(g.currentAmount)} / ${IdrFormat.compact(g.targetAmount)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id != null) {
                  ctrl.configureAutoSaveGoal(enabled: true, goalId: id);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmartAlertsCard(FinanceController ctrl, SakuColors saku) {
    return LuxurySurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Pengingat Limit & Tagihan Lokal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              'Kirim notifikasi lokal biasa saat budget hampir penuh atau tagihan jatuh tempo.',
              style: TextStyle(fontSize: 12, color: saku.textSecondary),
            ),
            value: ctrl.smartAlertsEnabled,
            onChanged: (v) async {
              await ctrl.setSmartAlertsEnabled(v);
              if (v && !ctrl.postNotificationGranted) {
                await ctrl.requestPostNotificationPermission();
              }
            },
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (!ctrl.postNotificationGranted)
                OutlinedButton.icon(
                  onPressed: ctrl.requestPostNotificationPermission,
                  icon: const Icon(Icons.notifications_active_outlined, size: 17),
                  label: const Text('Izinkan Notifikasi'),
                ),
              FilledButton.tonalIcon(
                onPressed: () async {
                  final ok = await ctrl.sendTestSmartAlertNotification();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Notifikasi pengingat tes terkirim.'
                              : 'Aktifkan izin notifikasi dulu di HP ya.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.notifications_none_rounded, size: 17),
                label: const Text('Tes Pengingat'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutoBackupCard(FinanceController ctrl, SakuColors saku) {
    return LuxurySurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Auto-Backup JSON Mingguan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              ctrl.lastAutoBackupPath.isNotEmpty
                  ? 'Terakhir tersimpan: ${ctrl.lastAutoBackupPath}'
                  : 'Simpan otomatis 5 arsip JSON terakhir ke folder Download/SakuProWann.',
              style: TextStyle(fontSize: 12, color: saku.textSecondary),
            ),
            value: ctrl.autoBackupEnabled,
            onChanged: ctrl.setAutoBackupEnabled,
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () async {
              final path = await ctrl.runAutoBackupIfDue(force: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      path != null
                          ? 'Backup tersimpan di $path'
                          : 'Belum ada transaksi untuk di-backup.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.backup_outlined, size: 17),
            label: const Text('Backup Sekarang ke Download'),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantMemoryCard(FinanceController ctrl, SakuColors saku) {
    final entries = ctrl.learnedMerchantCategories.entries.toList();
    return LuxurySurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Memori Kategori Merchant (${entries.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (entries.isNotEmpty)
                TextButton(
                  onPressed: ctrl.clearLearnedMerchants,
                  child: const Text('Reset'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'SakuProWann mengingat kategori pilihanmu saat ketik cepat atau scan struk supaya makin akurat.',
            style: TextStyle(fontSize: 12, color: saku.textSecondary),
          ),
          if (entries.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entries.take(12).map((entry) {
                return InputChip(
                  label: Text(
                    '${entry.key} · ${entry.value}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onDeleted: () => ctrl.removeLearnedMerchant(entry.key),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShortcutsCard(SakuColors saku) {
    return LuxurySurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Pintasan Cepat Android',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '1. Widget Home Screen: Tekan lama layar beranda HP > Widget > SakuProWann untuk pantau Aman Dipakai Hari Ini langsung dari layar utama.\n'
            '2. Quick Settings Tile: Tarik panel atas Android > Edit > tambahkan tombol "Catat SakuPro".',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: saku.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PercentChip extends StatelessWidget {
  const _PercentChip({
    required this.percent,
    required this.selected,
    required this.onTap,
  });

  final int percent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    return TactilePressScale(
      child: ChoiceChip(
        selected: selected,
        label: Text(
          '$percent%',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? saku.brandInteractive : saku.textPrimary,
            fontFeatures: AppTheme.tabularNums,
          ),
        ),
        onSelected: (_) {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );
  }
}

class MonthlyClosingRecapCard extends StatelessWidget {
  const MonthlyClosingRecapCard({
    super.key,
    required this.controller,
    required this.recap,
    required this.hideBalance,
  });

  final FinanceController controller;
  final MonthlyClosingRecap recap;
  final bool hideBalance;

  static const List<String> _months = <String>[
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final monthName =
        '${_months[(recap.month.month - 1).clamp(0, 11)]} ${recap.month.year}';
    final isSurplus = recap.surplus >= 0;
    final firstGoal = controller.selectedAutoSaveGoal;

    return LuxurySurfaceCard(
      padding: const EdgeInsets.all(16),
      radius: SakuRadius.lg,
      borderColor: saku.borderStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: saku.brandSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: 17,
                  color: saku.brandInteractive,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Rekap Tutup Bulan · $monthName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Tutup Rekap',
                visualDensity: VisualDensity.compact,
                onPressed: controller.dismissMonthlyRecap,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: saku.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${isSurplus ? 'Surplus' : 'Defisit'} ${IdrFormat.currency(recap.surplus, hidden: hideBalance, signed: true)}'
            '${recap.savingsRatePercent != null ? ' · Rasio tabungan ${recap.savingsRatePercent!.toStringAsFixed(0)}%' : ''}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isSurplus ? saku.income : saku.expense,
              fontFeatures: AppTheme.tabularNums,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${recap.transactionCount} transaksi · Pos terbesar: ${recap.topCategory}'
            '${recap.savedExcelPath.isNotEmpty ? ' · Arsip Excel tersimpan' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: saku.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: () async {
                  final report = controller.buildMonthlyReport(recap.month);
                  await ExportBackupService.shareMonthlyExcel(
                    month: report.month,
                    monthTransactions: report.transactions,
                    wallets: controller.wallets,
                    netWorth: controller.netWorth,
                    monthlyBudget: controller.monthlyBudget,
                    categoryBudgets: controller.categoryBudgets,
                    goals: controller.goals,
                    bills: controller.bills,
                    debts: controller.debts,
                    previousMonthExpense: report.previousMonthExpense,
                    insights: report.insights,
                  );
                },
                icon: const Icon(Icons.table_view_outlined, size: 17),
                label: const Text('Bagikan Excel'),
              ),
              if (isSurplus &&
                  recap.surplus > 0 &&
                  firstGoal != null &&
                  firstGoal.id != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await controller.allocateMonthlySurplusToGoal(
                      firstGoal.id!,
                    );
                    if (context.mounted && ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Surplus ditambahkan ke target "${firstGoal.name}".',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.savings_outlined, size: 17),
                  label: Text('Simpan ke ${firstGoal.name}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

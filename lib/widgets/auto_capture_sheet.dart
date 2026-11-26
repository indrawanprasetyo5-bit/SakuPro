import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../models/automation_models.dart';
import '../models/category_meta.dart';
import '../models/transaction_item.dart';
import '../services/automation_bridge_service.dart';
import '../services/bank_notification_parser.dart';
import '../services/export_backup_service.dart';
import '../services/finance_controller.dart';
import '../services/notification_bridge_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import 'wallet_brand_avatar.dart';

class AutoCaptureSheet extends StatefulWidget {
  const AutoCaptureSheet({super.key, required this.controller});

  final FinanceController controller;

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => AutoCaptureSheet(controller: controller),
    );
  }

  @override
  State<AutoCaptureSheet> createState() => _AutoCaptureSheetState();
}

class _AutoCaptureSheetState extends State<AutoCaptureSheet>
    with WidgetsBindingObserver {
  final TextEditingController _customTextController = TextEditingController();
  String _selectedTestSourceId = 'seabank';
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.refreshNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _customTextController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.refreshNotificationPermission();
      if (widget.controller.autoCaptureEnabled) {
        widget.controller.drainNativeNotifications();
      }
    }
  }

  Future<void> _openPermissionSettings() async {
    HapticFeedback.lightImpact();
    final opened =
        await NotificationBridgeService.openNotificationAccessSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Izin Akses Notifikasi hanya tersedia saat aplikasi dipasang di HP Android.',
          ),
        ),
      );
    }
  }

  Future<void> _openAppDetails() async {
    HapticFeedback.lightImpact();
    await NotificationBridgeService.openAppDetailsSettings();
  }

  Future<void> _handleToggleEnabled(bool value) async {
    final isAndroid = NotificationBridgeService.isSupportedPlatform;
    if (value && isAndroid) {
      final granted = await widget.controller.refreshNotificationPermission();
      if (!granted && mounted) {
        await widget.controller.setAutoCaptureEnabled(true);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Auto-Catat diaktifkan. Sekarang nyalakan Akses Notifikasi untuk SakuProWann.',
            ),
          ),
        );
        await _openPermissionSettings();
        return;
      }
    }
    await widget.controller.setAutoCaptureEnabled(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Auto-Catat QRIS & Bank aktif.'
                : 'Auto-Catat QRIS & Bank dinonaktifkan.',
          ),
        ),
      );
    }
  }

  Future<void> _runPresetTest(BankNotificationPreset preset) async {
    if (_isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      final raw = RawBankNotification(
        packageName: preset.packageName,
        title: preset.title,
        text: preset.text,
        postTimeMs: DateTime.now().millisecondsSinceEpoch,
      );
      final accepted = await widget.controller.processRawNotification(
        raw,
        isSimulation: true,
      );
      if (mounted) {
        final mode = widget.controller.autoCaptureMode;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accepted
                  ? (mode == AutoCaptureMode.autoSave
                        ? 'Simulasi berhasil: transaksi langsung tercatat!'
                        : 'Simulasi berhasil: masuk antrean konfirmasi Beranda.')
                  : 'Simulasi diabaikan dengan aman (bukan transaksi / promo / OTP).',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _runCustomTest() async {
    final text = _customTextController.text.trim();
    if (text.isEmpty || _isBusy) {
      return;
    }
    final src = BankNotificationParser.findSourceById(_selectedTestSourceId);
    if (src == null) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      final raw = RawBankNotification(
        packageName: src.packages.first,
        title: 'Transaksi ${src.name}',
        text: text,
        postTimeMs: DateTime.now().millisecondsSinceEpoch,
      );
      final accepted = await widget.controller.processRawNotification(
        raw,
        isSimulation: true,
      );
      if (mounted) {
        if (accepted) {
          _customTextController.clear();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accepted
                  ? 'Teks notifikasi dikenali dan berhasil diproses!'
                  : 'Teks diabaikan (pastikan ada nominal Rp dan kata transaksi seperti bayar/QRIS/transfer).',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _addPriorityWallets() async {
    final added = await widget.controller.ensurePriorityBankWallets();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added > 0
                ? '$added dompet baru (SeaBank / Bank Jago) ditambahkan.'
                : 'Dompet SeaBank & Bank Jago sudah tersedia.',
          ),
        ),
      );
    }
  }

  Future<void> _openAddRecurringIncomeDialog() async {
    final wallets = widget.controller.wallets;
    if (wallets.isEmpty) {
      return;
    }
    final nameCtrl = TextEditingController(text: 'Gaji Bulanan');
    final amountCtrl = TextEditingController();
    var selectedDay = 25;
    var selectedWalletId = wallets.first.id ?? 1;
    var selectedCategory = CategoryCatalog.incomeCategories.first.name;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Jadwal Pemasukan Rutin'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
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
                          setDialogState(() => selectedDay = v);
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
                          setDialogState(() => selectedWalletId = v);
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
                          setDialogState(() => selectedCategory = v);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (nameCtrl.text.trim().isEmpty || amount <= 0) {
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Simpan Jadwal'),
                ),
              ],
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
              content: Text('Jadwal pemasukan rutin otomatis ditambahkan.'),
            ),
          );
        }
      }
    }
    nameCtrl.dispose();
    amountCtrl.dispose();
  }

  Future<void> _handleSendTestAlert() async {
    final isAndroid = AutomationBridgeService.isSupportedPlatform;
    if (!isAndroid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifikasi Android lokal aktif saat APK dipasang di HP.',
            ),
          ),
        );
      }
      return;
    }
    var granted = await widget.controller.refreshPostNotificationPermission();
    if (!granted) {
      granted = await widget.controller.requestPostNotificationPermission();
    }
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin notifikasi HP belum diberikan.'),
          ),
        );
      }
      return;
    }
    final sent = await widget.controller.sendTestSmartAlertNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Notifikasi uji dikirim ke status bar HP!'
                : 'Gagal mengirim notifikasi uji.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final saku = context.saku;
        final isAndroid = NotificationBridgeService.isSupportedPlatform;
        final granted = ctrl.notificationPermissionGranted;

        final primarySources = BankNotificationParser.supportedSources
            .where((s) => s.isPrimary)
            .toList();
        final extraSources = BankNotificationParser.supportedSources
            .where((s) => !s.isPrimary)
            .toList();

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          builder: (ctx, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Pusat Otomatisasi',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Auto-Catat QRIS, Auto-Transfer, Kamus Merchant, Rutin, Alert & Widget (100% gratis & offline).',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
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
                const SizedBox(height: 14),
                Material(
                  color: saku.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: granted && ctrl.autoCaptureEnabled
                          ? saku.brandInteractive.withValues(alpha: 0.45)
                          : saku.border,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: !isAndroid
                                ? saku.transferSoft
                                : granted
                                ? saku.incomeSoft
                                : saku.warningSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                !isAndroid
                                    ? Icons.science_outlined
                                    : granted
                                    ? Icons.verified_outlined
                                    : Icons.notifications_paused_outlined,
                                size: 15,
                                color: !isAndroid
                                    ? saku.transfer
                                    : granted
                                    ? saku.income
                                    : saku.warning,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  !isAndroid
                                      ? 'Preview Web (Gunakan Simulator)'
                                      : granted
                                      ? 'Izin Notifikasi Android Aktif'
                                      : 'Izin Notifikasi Belum Aktif',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: !isAndroid
                                        ? saku.transfer
                                        : granted
                                        ? saku.income
                                        : saku.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Aktifkan Auto-Catat QRIS',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          'Tangkap otomatis notifikasi SeaBank, DANA, GoPay, Bank Jago & bank lain.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        value: ctrl.autoCaptureEnabled,
                        onChanged: _handleToggleEnabled,
                      ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Auto-Pairing Transfer Sendiri',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            'Satukan top-up/transfer antar dompetmu sendiri agar tidak dihitung pengeluaran ganda.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          value: ctrl.autoPairTransfers,
                          onChanged: ctrl.setAutoPairTransfers,
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Auto-Lunas Tagihan & Potong Hutang',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            'Otomatis tandai Tagihan lunas atau potong sisa Piutang/Hutang jika notifikasi bank cocok.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          value: ctrl.autoReconcilePlan,
                          onChanged: ctrl.setAutoReconcilePlan,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Mode Pencatatan',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: saku.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<AutoCaptureMode>(
                          showSelectedIcon: false,
                          segments: const <ButtonSegment<AutoCaptureMode>>[
                            ButtonSegment<AutoCaptureMode>(
                              value: AutoCaptureMode.autoSave,
                              label: Text(
                                'Otomatis',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ButtonSegment<AutoCaptureMode>(
                              value: AutoCaptureMode.inbox,
                              label: Text(
                                'Konfirmasi',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          selected: <AutoCaptureMode>{ctrl.autoCaptureMode},
                          onSelectionChanged: (sel) =>
                              ctrl.setAutoCaptureMode(sel.first),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ctrl.autoCaptureMode == AutoCaptureMode.autoSave
                            ? 'Transaksi QRIS yang sah langsung masuk ke catatan & saldo dompet.'
                            : 'Transaksi QRIS masuk ke kartu antrean di Beranda untuk 1-tap konfirmasi.',
                        style: TextStyle(
                          fontSize: 12,
                          color: saku.textMuted,
                        ),
                      ),
                      if (isAndroid) ...<Widget>[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilledButton.icon(
                              onPressed: _openPermissionSettings,
                              icon: const Icon(
                                Icons.notifications_active_outlined,
                                size: 18,
                              ),
                              label: Text(
                                granted
                                    ? 'Kelola Izin Notifikasi'
                                    : 'Buka Izin Notifikasi',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _openAppDetails,
                              icon: const Icon(Icons.info_outline, size: 18),
                              label: const Text('Info Aplikasi (Android 13+)'),
                            ),
                          ],
                        ),
                        if (!granted) ...<Widget>[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: saku.surfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Cara buka kunci Android 13-16 ("Setelan terbatas / Bahaya"):\n'
                              '1. Tekan "Buka Izin Notifikasi" -> tap SakuProWann sekali (sampai muncul pop-up Setelan terbatas).\n'
                              '2. Kembali ke sini -> tekan "Info Aplikasi (Android 13+)".\n'
                              '3. Tap titik tiga (⋮) di pojok kanan atas (di Xiaomi/HyperOS scroll paling bawah) -> pilih "Izinkan setelan terbatas" -> konfirmasi PIN/sidik jari.\n'
                              '4. Kembali ke "Buka Izin Notifikasi" -> sekarang switch SakuProWann bisa dinyalakan normal.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: saku.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                  ),
                ),
                if (ctrl.hasMissingPriorityBankWallets) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: saku.goldSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: saku.goldAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              color: saku.goldAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Belum ada dompet SeaBank / Bank Jago',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonal(
                          onPressed: _addPriorityWallets,
                          child: const Text('Tambah Otomatis'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Prioritas Utamamu',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: primarySources.map((src) {
                    final selected = ctrl.enabledNotificationSourceIds.contains(
                      src.id,
                    );
                    return FilterChip(
                      selected: selected,
                      avatar: WalletBrandAvatar(
                        name: src.walletName,
                        kind: src.walletKind,
                        size: 22,
                        borderRadius: 6,
                      ),
                      label: Text(
                        src.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onSelected: (v) =>
                          ctrl.toggleNotificationSource(src.id, v),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  'Bank & E-Wallet Tambahan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: extraSources.map((src) {
                    final selected = ctrl.enabledNotificationSourceIds.contains(
                      src.id,
                    );
                    return FilterChip(
                      selected: selected,
                      avatar: WalletBrandAvatar(
                        name: src.walletName,
                        kind: src.walletKind,
                        size: 20,
                        borderRadius: 5,
                      ),
                      label: Text(src.name),
                      onSelected: (v) =>
                          ctrl.toggleNotificationSource(src.id, v),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Material(
                  color: saku.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: saku.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.autorenew_rounded,
                              size: 20,
                              color: saku.brandInteractive,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Auto-Catat Rutin (Gaji & Tagihan)',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _openAddRecurringIncomeDialog,
                              icon: const Icon(Icons.add_rounded, size: 17),
                              label: const Text('Gaji'),
                            ),
                          ],
                        ),
                        Text(
                          'Gaji & pemasukan rutin otomatis masuk sesuai tanggalnya. Tagihan rutin bisa diaktifkan Auto-Catat di tab Rencana > Tagihan (${ctrl.autoPayBillIds.length} aktif).',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (ctrl.recurringIncomes.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          ...ctrl.recurringIncomes.map((inc) {
                            final walletName =
                                ctrl.walletById(inc.walletId)?.name ?? 'Dompet';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: saku.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          inc.name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          '${IdrFormat.currency(inc.amount)} · Tgl ${inc.dayOfMonth} -> $walletName',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: saku.textMuted,
                                            fontFeatures: AppTheme.tabularNums,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: inc.enabled,
                                    onChanged: (v) =>
                                        ctrl.toggleRecurringIncome(inc.id, v),
                                  ),
                                  IconButton(
                                    tooltip: 'Hapus Jadwal',
                                    onPressed: () =>
                                        ctrl.deleteRecurringIncome(inc.id),
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: saku.expense,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: saku.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: saku.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Alert Budget & Pengingat Lokal',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            'Notifikasi otomatis saat budget >= 80%, tagihan H-2, dan ringkasan Minggu pagi.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          value: ctrl.smartAlertsEnabled,
                          onChanged: (v) async {
                            await ctrl.setSmartAlertsEnabled(v);
                            if (v && isAndroid) {
                              await ctrl.requestPostNotificationPermission();
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            if (isAndroid && !ctrl.postNotificationGranted)
                              FilledButton.tonalIcon(
                                onPressed: () =>
                                    ctrl.requestPostNotificationPermission(),
                                icon: const Icon(
                                  Icons.notifications_outlined,
                                  size: 17,
                                ),
                                label: const Text('Izinkan Notifikasi HP'),
                              ),
                            OutlinedButton.icon(
                              onPressed: _handleSendTestAlert,
                              icon: const Icon(
                                Icons.send_outlined,
                                size: 17,
                              ),
                              label: const Text('Tes Notifikasi'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: saku.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: saku.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.psychology_alt_outlined,
                              size: 20,
                              color: saku.goldAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Kamus Merchant Pribadi (${ctrl.learnedMerchantCategories.length})',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (ctrl.learnedMerchantCategories.isNotEmpty)
                              TextButton(
                                onPressed: ctrl.clearLearnedMerchants,
                                child: const Text('Reset'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ctrl.learnedMerchantCategories.isEmpty
                              ? 'Otomatis belajar setiap kali kamu mencatat atau mengedit kategori transaksi. QRIS berikutnya ke toko yang sama langsung tepat kategori.'
                              : 'Kategori otomatis yang sudah diingat SakuProWann dari kebiasaanmu:',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (ctrl.learnedMerchantCategories.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: ctrl.learnedMerchantCategories.entries
                                .take(12)
                                .map(
                                  (e) => InputChip(
                                    label: Text(
                                      '${e.key} -> ${e.value}',
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                    onDeleted: () =>
                                        ctrl.removeLearnedMerchant(e.key),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: saku.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: saku.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Auto-Alokasi Tabungan (Gaji Masuk)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            'Otomatis tambah progres Target Tabungan saat pemasukan Gaji / Bonus masuk.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          value: ctrl.autoSaveGoalEnabled,
                          onChanged: ctrl.goals.isEmpty
                              ? null
                              : (v) => ctrl.configureAutoSaveGoal(enabled: v),
                        ),
                        if (ctrl.goals.isEmpty)
                          Text(
                            'Buat dulu minimal 1 target di tab Rencana > Goals untuk mengaktifkan fitur ini.',
                            style: TextStyle(
                              fontSize: 12,
                              color: saku.textMuted,
                            ),
                          )
                        else ...<Widget>[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <int>[10, 15, 20, 30].map((pct) {
                              return ChoiceChip(
                                label: Text('$pct%'),
                                selected: ctrl.autoSaveGoalPercent == pct,
                                onSelected: (_) => ctrl.configureAutoSaveGoal(
                                  enabled: true,
                                  percent: pct,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            initialValue: ctrl.selectedAutoSaveGoal?.id,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Target Tabungan Tujuan',
                              isDense: true,
                            ),
                            items: ctrl.goals
                                .where((g) => g.id != null)
                                .map(
                                  (g) => DropdownMenuItem<int>(
                                    value: g.id!,
                                    child: Text(g.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (goalId) {
                              if (goalId != null) {
                                ctrl.configureAutoSaveGoal(
                                  enabled: ctrl.autoSaveGoalEnabled,
                                  goalId: goalId,
                                );
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: saku.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: saku.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Auto-Backup & Arsip Excel Bulanan',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            'Otomatis simpan backup JSON mingguan (5 arsip bergilir) & Excel 5-sheet tiap ganti bulan ke folder Download/SakuProWann/.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          value: ctrl.autoBackupEnabled,
                          onChanged: ctrl.setAutoBackupEnabled,
                        ),
                        if (ctrl.lastAutoBackupDate.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            'Backup otomatis terakhir: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.tryParse(ctrl.lastAutoBackupDate) ?? DateTime.now())}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: saku.textMuted,
                              fontFeatures: AppTheme.tabularNums,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                final saved = await ctrl.runAutoBackupIfDue(
                                  force: true,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        saved != null
                                            ? 'Backup disimpan: $saved'
                                            : 'Backup lokal hanya tersedia di HP Android.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.save_alt_rounded,
                                size: 17,
                              ),
                              label: const Text('Backup ke Download'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final saved = await ctrl
                                    .runMonthlyClosingArchiveIfNeeded(
                                      force: true,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        saved != null
                                            ? 'Arsip Excel bulan lalu disimpan: $saved'
                                            : 'Belum ada transaksi di bulan lalu untuk diarsipkan.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.table_view_outlined,
                                size: 17,
                              ),
                              label: const Text('Arsip Excel Bulan Lalu'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: saku.brandSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: saku.brandInteractive.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Tips Terima Beres di HP Android',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: saku.brandInteractive,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1. Share Bukti QRIS/Transfer: Dari SeaBank, DANA, GoPay, Bank Jago, atau WhatsApp tekan Bagikan -> pilih SakuProWann untuk OCR otomatis.\n'
                        '2. Widget Layar Utama: Tekan lama layar utama HP -> Widget -> pilih SakuProWann untuk pantau Aman Jajan + tombol Catat & Scan 1-tap.\n'
                        '3. Quick Settings Tile (Bayar Tunai): Tarik panel atas HP -> Edit tombol -> tambahkan "Catat SakuPro" untuk 1-tap catat cash dari mana saja.',
                        style: TextStyle(
                          fontSize: 12,
                          color: saku.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: saku.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: saku.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.play_circle_outline_rounded,
                            size: 20,
                            color: saku.brandInteractive,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Simulator Tes Notifikasi QRIS',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Coba klik salah satu contoh notifikasi nyata di bawah untuk melihat transaksi langsung masuk ke SakuProWann.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: BankNotificationParser.testPresets.map((p) {
                          return ActionChip(
                            label: Text(
                              p.label,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _isBusy ? null : () => _runPresetTest(p),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTestSourceId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Simulasikan Aplikasi Pengirim',
                          isDense: true,
                        ),
                        items: BankNotificationParser.supportedSources
                            .map(
                              (s) => DropdownMenuItem<String>(
                                value: s.id,
                                child: Text(s.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedTestSourceId = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _customTextController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Tempel contoh teks notifikasi bank',
                          hintText:
                              'Contoh: Pembayaran QRIS Rp32.000 ke Fore Coffee berhasil',
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isBusy ? null : _runCustomTest,
                          icon: const Icon(Icons.bolt_rounded, size: 18),
                          label: const Text('Uji & Catat Teks Notifikasi'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (ctrl.autoCaptureLogs.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Log Deteksi Terbaru (${ctrl.autoCaptureLogs.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: ctrl.clearAutoCaptureLogs,
                        child: const Text('Bersihkan'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...ctrl.autoCaptureLogs.take(10).map((log) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: saku.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: saku.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  '${log.sourceName} · ${DateFormat('HH:mm').format(log.timestamp)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: saku.textPrimary,
                                    fontFeatures: AppTheme.tabularNums,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: log.accepted
                                      ? saku.incomeSoft
                                      : saku.surfaceMuted,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  log.accepted ? 'Valid' : 'Diabaikan',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: log.accepted
                                        ? saku.income
                                        : saku.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log.text.isNotEmpty ? log.text : log.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: saku.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log.statusLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: log.accepted
                                  ? saku.brandInteractive
                                  : saku.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class PendingAutoCaptureCard extends StatelessWidget {
  const PendingAutoCaptureCard({
    super.key,
    required this.controller,
    required this.hideBalance,
  });

  final FinanceController controller;
  final bool hideBalance;

  @override
  Widget build(BuildContext context) {
    final items = controller.pendingAutoTransactions;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final saku = context.saku;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: saku.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: saku.goldAccent.withValues(alpha: 0.55),
          width: 1.1,
        ),
        boxShadow: context.isDarkMode
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: saku.cardShadow,
                  offset: const Offset(0, 6),
                  blurRadius: 16,
                  spreadRadius: -4,
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: saku.goldSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 17,
                      color: saku.goldAccent,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'Transaksi QRIS Terdeteksi (${items.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              if (items.length > 1)
                TextButton(
                  onPressed: () async {
                    final count = await controller
                        .approveAllPendingAutoTransactions();
                    if (context.mounted && count > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '$count transaksi QRIS berhasil disimpan.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Simpan Semua'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.take(3).map((item) {
            final isIncome = item.kind == TransactionKind.income;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: saku.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        IdrFormat.currency(
                          isIncome ? item.amount : -item.amount,
                          hidden: hideBalance,
                          signed: true,
                        ),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isIncome ? saku.income : saku.expense,
                          fontFeatures: AppTheme.tabularNums,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.sourceName} · ${item.category} · ${DateFormat('HH:mm').format(item.timestamp)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: saku.textMuted,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => controller
                            .dismissPendingAutoTransaction(item.fingerprint),
                        child: Text(
                          'Abaikan',
                          style: TextStyle(color: saku.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final ok = await controller
                              .approvePendingAutoTransaction(item.fingerprint);
                          if (context.mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${item.note} disimpan ke ${item.suggestedWalletName}.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Simpan'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: saku.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: saku.goldAccent.withValues(alpha: 0.45),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: saku.goldSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 17,
                  color: saku.goldAccent,
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
              if (isSurplus && recap.surplus > 0 && firstGoal != null && firstGoal.id != null)
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

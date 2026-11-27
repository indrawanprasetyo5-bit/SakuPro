import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/export_backup_service.dart';
import '../services/finance_controller.dart';
import '../services/receipt_archive.dart';
import '../services/security_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import 'auto_capture_sheet.dart';
import 'budget_dialog.dart';
import 'luxury_widgets.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key, required this.controller});

  final FinanceController controller;

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
  }) {
    return showSakuBottomSheet<void>(
      context: context,
      builder: (ctx) => SettingsSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final saku = context.saku;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.94,
          builder: (ctx, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
                      child: Text(
                        'Pengaturan & Keamanan',
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
                SettingsSectionPanel(controller: controller),
              ],
            );
          },
        );
      },
    );
  }
}

class SettingsSectionPanel extends StatefulWidget {
  const SettingsSectionPanel({super.key, required this.controller});

  final FinanceController controller;

  @override
  State<SettingsSectionPanel> createState() => _SettingsSectionPanelState();
}

class _SettingsSectionPanelState extends State<SettingsSectionPanel> {
  bool _biometricAvailable = false;
  ReceiptStorageStats _receiptStats = const ReceiptStorageStats(
    fileCount: 0,
    totalBytes: 0,
  );
  bool _isClearingPhotos = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _loadReceiptStats();
  }

  Future<void> _checkBiometric() async {
    final supported = await BiometricAuthService.isBiometricAvailable();
    if (mounted) {
      setState(() => _biometricAvailable = supported);
    }
  }

  Future<void> _loadReceiptStats() async {
    final stats = await ReceiptArchive.getStorageStats();
    if (mounted) {
      setState(() => _receiptStats = stats);
    }
  }

  Future<void> _confirmClearReceiptPhotos() async {
    if (_isClearingPhotos || _receiptStats.fileCount == 0) {
      return;
    }
    final confirmed = await showSakuBottomSheet<bool>(
      context: context,
      builder: (ctx) {
        final saku = ctx.saku;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SakuSheetHandle(),
              const SizedBox(height: 16),
              Text(
                'Bersihkan arsip foto struk?',
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                '${_receiptStats.fileCount} foto (${_receiptStats.formattedSize}) akan dihapus dari memori HP. Semua catatan transaksi, nominal, dan teks rincian item struk tetap aman.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
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
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: saku.expense,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Bersihkan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _isClearingPhotos = true);
    try {
      final removed = await widget.controller.clearArchivedReceiptPhotos();
      await _loadReceiptStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$removed foto struk dibersihkan. Data transaksi dan teks rincian tetap utuh.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearingPhotos = false);
      }
    }
  }

  Future<void> _handleToggleAppLock(bool enable) async {
    if (!enable) {
      await widget.controller.disableAppLock();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kunci aplikasi dinonaktifkan.')),
        );
      }
      return;
    }

    final result = await showSakuBottomSheet<(String, bool)>(
      context: context,
      builder: (ctx) => _PinSetupDialog(
        biometricAvailable: _biometricAvailable,
      ),
    );

    if (result != null) {
      await widget.controller.enableAppLock(
        pin: result.$1,
        useBiometric: result.$2,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN 4 digit berhasil diaktifkan.')),
        );
      }
    }
  }

  Future<void> _copyBackupJson() async {
    try {
      final snapshot = await widget.controller.createBackupSnapshot();
      final jsonStr = ExportBackupService.encodeBackupJson(snapshot);
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data backup JSON disalin ke clipboard.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat backup: $e')),
        );
      }
    }
  }

  Future<void> _shareBackupJson() async {
    try {
      final snapshot = await widget.controller.createBackupSnapshot();
      await ExportBackupService.shareBackupJsonFile(snapshot);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membagikan berkas backup: $e')),
        );
      }
    }
  }

  Future<void> _openRestoreDialog() async {
    final restored = await showSakuBottomSheet<bool>(
      context: context,
      builder: (ctx) => _RestoreJsonDialog(controller: widget.controller),
    );
    if (restored == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seluruh data SakuProWann berhasil dipulihkan dari JSON.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final isDark = context.isDarkMode;
    final ctrl = widget.controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: saku.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: saku.border),
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          isDark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          color: saku.brandInteractive,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Mode Tampilan',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              isDark ? 'Mode Gelap aktif' : 'Mode Terang aktif',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                    SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<ThemeMode>>[
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          label: Text('Terang'),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          label: Text('Gelap'),
                        ),
                      ],
                      selected: <ThemeMode>{
                        isDark ? ThemeMode.dark : ThemeMode.light,
                      },
                      onSelectionChanged: (sel) => ctrl.setThemeMode(sel.first),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: saku.border),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Icon(
                  Icons.event_repeat_rounded,
                  color: saku.brandInteractive,
                ),
                title: Text(
                  'Pusat Otomatisasi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  'Share Resi, Auto-Gaji, Auto-Pay, Auto-Save Goal, Auto-Backup',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: saku.textMuted,
                ),
                onTap: () => AutoCaptureSheet.show(context, controller: ctrl),
              ),
              Divider(height: 1, color: saku.border),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                secondary: Icon(
                  ctrl.hideBalance
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: saku.brandInteractive,
                ),
                title: Text(
                  'Sembunyikan Nominal Saldo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  'Samarkan angka menjadi Rp ••••••',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                value: ctrl.hideBalance,
                onChanged: (_) => ctrl.toggleHideBalance(),
              ),
              Divider(height: 1, color: saku.border),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                secondary: Icon(
                  Icons.lock_outline_rounded,
                  color: saku.brandInteractive,
                ),
                title: Text(
                  'Kunci Aplikasi (PIN 4 Digit)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  ctrl.appLockEnabled
                      ? 'Aktif saat aplikasi dibuka'
                      : 'Lindungi akses catatan keuanganmu',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                value: ctrl.appLockEnabled,
                onChanged: _handleToggleAppLock,
              ),
              if (ctrl.appLockEnabled) ...<Widget>[
                Divider(height: 1, color: saku.border),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  secondary: Icon(
                    Icons.fingerprint_rounded,
                    color: saku.brandInteractive,
                  ),
                  title: Text(
                    'Sidik Jari / Biometrik',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    kIsWeb
                        ? 'Biometrik hanya tersedia di perangkat Android/iOS'
                        : (_biometricAvailable
                              ? 'Buka kunci lebih cepat dengan sensor perangkat'
                              : 'Sensor biometrik tidak terdeteksi di perangkat ini'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  value: ctrl.biometricEnabled && _biometricAvailable,
                  onChanged: !kIsWeb && _biometricAvailable
                      ? (v) => ctrl.setBiometricEnabled(v)
                      : null,
                ),
                Divider(height: 1, color: saku.border),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  leading: Icon(
                    Icons.phonelink_lock_rounded,
                    color: saku.brandInteractive,
                  ),
                  title: Text(
                    'Kunci Layar Sekarang',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).maybePop();
                    ctrl.lockSessionNow();
                  },
                ),
              ],
              Divider(height: 1, color: saku.border),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Icon(
                  Icons.speed_rounded,
                  color: saku.brandInteractive,
                ),
                title: Text(
                  'Plafon Budget Bulanan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  IdrFormat.currency(
                    ctrl.monthlyBudget,
                    hidden: ctrl.hideBalance,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: saku.textSecondary,
                    fontFeatures: AppTheme.tabularNums,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => BudgetDialog.show(context, controller: ctrl),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Cadangan & Pemulihan Data (JSON)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Simpan seluruh dompet, transaksi, teks rincian struk, budget, goals, tagihan, dan hutang ke format JSON agar aman saat pindah perangkat.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed: _shareBackupJson,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Bagikan Backup JSON'),
            ),
            OutlinedButton.icon(
              onPressed: _copyBackupJson,
              icon: const Icon(Icons.copy_all_rounded, size: 18),
              label: const Text('Salin JSON'),
            ),
            OutlinedButton.icon(
              onPressed: _openRestoreDialog,
              icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
              label: const Text('Restore dari JSON'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
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
                  Icon(
                    Icons.photo_library_outlined,
                    size: 18,
                    color: saku.brandInteractive,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Arsip Foto Struk Lokal',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    kIsWeb
                        ? 'Khusus HP'
                        : '${_receiptStats.fileCount} foto · ${_receiptStats.formattedSize}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: saku.textSecondary,
                      fontFeatures: AppTheme.tabularNums,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Foto struk disimpan terpisah di memori HP dan tidak ikut di file Backup JSON (teks rincian item struk tetap ikut di JSON).',
                style: TextStyle(
                  fontSize: 12.5,
                  color: saku.textMuted,
                  height: 1.4,
                ),
              ),
              if (!kIsWeb && _receiptStats.fileCount > 0) ...<Widget>[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: saku.expense,
                    side: BorderSide(
                      color: saku.expense.withValues(alpha: 0.35),
                    ),
                  ),
                  onPressed: _isClearingPhotos
                      ? null
                      : _confirmClearReceiptPhotos,
                  icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                  label: Text(
                    _isClearingPhotos
                        ? 'Membersihkan...'
                        : 'Bersihkan Foto Struk',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog({required this.biometricAvailable});

  final bool biometricAvailable;

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  late bool _useBiometric;
  String? _error;

  @override
  void initState() {
    super.initState();
    _useBiometric = widget.biometricAvailable && !kIsWeb;
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'PIN harus terdiri dari 4 angka.');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'Konfirmasi PIN tidak cocok.');
      return;
    }
    Navigator.of(context).pop((pin, _useBiometric));
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
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
            Text(
              'Buat PIN 4 Digit',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Biar catatan keuangan kamu cuma bisa dibuka sama kamu sendiri.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              autofocus: true,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'PIN Baru (4 angka)',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Ulangi PIN',
                counterText: '',
              ),
            ),
            if (!kIsWeb && widget.biometricAvailable) ...<Widget>[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _useBiometric,
                onChanged: (v) => setState(() => _useBiometric = v ?? false),
                title: const Text(
                  'Aktifkan juga Sidik Jari / Biometrik',
                  style: TextStyle(fontSize: 13.5),
                ),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: saku.expense,
                ),
              ),
            ],
            const SizedBox(height: 18),
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
                    onPressed: _submit,
                    child: const Text('Aktifkan PIN'),
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

class _RestoreJsonDialog extends StatefulWidget {
  const _RestoreJsonDialog({required this.controller});

  final FinanceController controller;

  @override
  State<_RestoreJsonDialog> createState() => _RestoreJsonDialogState();
}

class _RestoreJsonDialogState extends State<_RestoreJsonDialog> {
  final TextEditingController _jsonController = TextEditingController();
  String? _error;
  bool _isRestoring = false;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && mounted) {
      setState(() {
        _jsonController.text = data!.text!;
        _error = null;
      });
    }
  }

  Future<void> _restore() async {
    final raw = _jsonController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Tempel teks JSON backup dulu ya.');
      return;
    }
    setState(() {
      _isRestoring = true;
      _error = null;
    });
    try {
      await widget.controller.restoreFromBackupJson(raw);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _isRestoring = false;
        _error = 'Gagal memulihkan data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
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
            Text(
              'Restore Data dari JSON',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Data sekarang akan diganti dengan isi backup JSON yang valid.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pasteClipboard,
                icon: const Icon(Icons.content_paste_rounded, size: 16),
                label: const Text('Tempel dari Clipboard'),
              ),
            ),
            TextField(
              controller: _jsonController,
              maxLines: 6,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: '{"app": "saku_pro", ...}',
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: saku.expense,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isRestoring
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _isRestoring ? null : _restore,
                    child: Text(
                      _isRestoring ? 'Memulihkan...' : 'Pulihkan Sekarang',
                    ),
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

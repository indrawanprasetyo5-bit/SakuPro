import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../db/database_helper.dart';
import '../models/wallet.dart';
import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import 'wallet_brand_avatar.dart';

class WalletFormSheet extends StatefulWidget {
  const WalletFormSheet({
    super.key,
    required this.controller,
    this.existingWallet,
  });

  final FinanceController controller;
  final WalletModel? existingWallet;

  static Future<bool?> show(
    BuildContext context, {
    required FinanceController controller,
    WalletModel? existingWallet,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => WalletFormSheet(
        controller: controller,
        existingWallet: existingWallet,
      ),
    );
  }

  @override
  State<WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends State<WalletFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late WalletKind _kind;
  late int _colorValue;
  late String _iconKey;
  late bool _excludeFromTotal;
  bool _isNegativeBalance = false;
  String? _errorText;
  bool _isSaving = false;

  bool get _isEditing => widget.existingWallet != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingWallet;
    _nameController = TextEditingController(text: existing?.name ?? '');
    final initialBal = existing?.balance ?? 0;
    _isNegativeBalance = initialBal < 0;
    _balanceController = TextEditingController(
      text: initialBal == 0 ? '' : initialBal.abs().toString(),
    );
    _kind = existing?.kind ?? WalletKind.bank;
    _colorValue = existing?.colorValue ?? WalletPalette.presetColors.first;
    _iconKey = existing?.iconKey ?? 'wallet';
    _excludeFromTotal = existing?.excludeFromTotal ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  int _parsedBalance() {
    final digits = _balanceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final absVal = int.tryParse(digits) ?? 0;
    return _isNegativeBalance ? -absVal : absVal;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Nama dompet wajib diisi.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final balance = _parsedBalance();
      if (_isEditing) {
        final updated = widget.existingWallet!.copyWith(
          name: name,
          kind: _kind,
          balance: balance,
          colorValue: _colorValue,
          iconKey: _iconKey,
          excludeFromTotal: _excludeFromTotal,
        );
        await widget.controller.updateWallet(updated);
      } else {
        await widget.controller.addWallet(
          name: name,
          kind: _kind,
          initialBalance: balance,
          colorValue: _colorValue,
          iconKey: _iconKey,
          excludeFromTotal: _excludeFromTotal,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorText = 'Gagal menyimpan dompet: $e';
        _isSaving = false;
      });
    }
  }

  Future<void> _deleteWallet() async {
    final wallet = widget.existingWallet;
    if (wallet?.id == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await widget.controller.deleteWallet(wallet!.id!);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on StorageException catch (e) {
      setState(() {
        _errorText = e.message;
        _isSaving = false;
      });
    } catch (e) {
      setState(() {
        _errorText = 'Tidak dapat menghapus dompet: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final currentBalance = _parsedBalance();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Dompet' : 'Tambah Dompet Baru',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    tooltip: 'Hapus dompet',
                    onPressed: _isSaving ? null : _deleteWallet,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: saku.expense,
                    ),
                  ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icon(Icons.close_rounded, color: saku.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                WalletBrandAvatar(
                  name: _nameController.text,
                  kind: _kind,
                  fallbackColor: Color(_colorValue),
                  fallbackIcon: WalletPalette.iconFor(_iconKey),
                  size: 52,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() => _errorText = null),
                    decoration: const InputDecoration(
                      labelText: 'Nama Dompet',
                      hintText: 'Mis. SeaBank, DANA, BCA, Bank Jago',
                    ),
                  ),
                ),
              ],
            ),
            if (!_isEditing) ...<Widget>[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: WalletBrandCatalog.quickPresets.map((brand) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        avatar: WalletBrandAvatar(
                          name: brand.displayName,
                          kind: brand.walletKind,
                          size: 20,
                          borderRadius: 6,
                        ),
                        label: Text(
                          brand.displayName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _nameController.text = brand.displayName;
                            _kind = brand.walletKind;
                            _colorValue = brand.primaryColor.toARGB32();
                            _errorText = null;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text('Tipe Dompet', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WalletKind.values.map((kind) {
                return ChoiceChip(
                  label: Text(kind.label),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  _isEditing ? 'Saldo Saat Ini' : 'Saldo Awal',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  IdrFormat.currency(currentBalance),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: saku.brandInteractive,
                    fontFeatures: AppTheme.tabularNums,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _balanceController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: saku.textPrimary,
                fontFeatures: AppTheme.tabularNums,
              ),
              onChanged: (_) => setState(() => _errorText = null),
              decoration: InputDecoration(
                prefixText: _isNegativeBalance ? '-Rp ' : 'Rp ',
                hintText: '0',
                suffixIcon: TextButton(
                  onPressed: () => setState(() {
                    _isNegativeBalance = !_isNegativeBalance;
                  }),
                  child: Text(
                    _isNegativeBalance ? 'Minus' : 'Plus',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Warna & Ikon', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: WalletPalette.presetColors.map((hex) {
                final selected = _colorValue == hex;
                return InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _colorValue = hex),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? saku.textPrimary : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WalletPalette.icons.entries.map((entry) {
                final selected = _iconKey == entry.key;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _iconKey = entry.key),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: selected ? saku.brandSoft : saku.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? saku.brandInteractive : saku.border,
                        width: selected ? 1.5 : 1,
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
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Kecualikan dari Total Saldo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                'Aktifkan untuk dana titipan atau rekening terpisah.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: _excludeFromTotal,
              onChanged: (v) => setState(() => _excludeFromTotal = v),
            ),
            if (_errorText != null) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: saku.expenseSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorText!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: saku.expense,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(_isEditing ? 'Simpan Dompet' : 'Tambah Dompet'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/category_meta.dart';
import '../services/finance_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/currency_format.dart';
import 'luxury_widgets.dart';
import 'wallet_brand_avatar.dart';

class SplitBillSheet extends StatefulWidget {
  const SplitBillSheet({super.key, required this.controller});

  final FinanceController controller;

  static Future<int?> show(
    BuildContext context, {
    required FinanceController controller,
  }) {
    return showSakuBottomSheet<int>(
      context: context,
      builder: (ctx) => SplitBillSheet(controller: controller),
    );
  }

  @override
  State<SplitBillSheet> createState() => _SplitBillSheetState();
}

class _FriendDraft {
  _FriendDraft({String name = '', String phone = ''})
    : nameCtrl = TextEditingController(text: name),
      phoneCtrl = TextEditingController(text: phone),
      customAmountCtrl = TextEditingController();

  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController customAmountCtrl;

  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    customAmountCtrl.dispose();
  }
}

class _SplitBillSheetState extends State<SplitBillSheet> {
  final TextEditingController _titleCtrl = TextEditingController(
    text: 'Makan Bareng',
  );
  final TextEditingController _totalCtrl = TextEditingController();
  final List<_FriendDraft> _friends = <_FriendDraft>[
    _FriendDraft(name: 'Teman 1'),
  ];

  bool _splitEvenly = true;
  late int _walletId;
  String _category = 'Makan & Minum';
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _walletId = widget.controller.wallets.isNotEmpty
        ? (widget.controller.wallets.first.id ?? 1)
        : 1;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _totalCtrl.dispose();
    for (final f in _friends) {
      f.dispose();
    }
    super.dispose();
  }

  int _parseDigits(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  int get _totalBill => _parseDigits(_totalCtrl.text);

  List<int> _computedFriendShares() {
    final total = _totalBill;
    if (_friends.isEmpty) {
      return const <int>[];
    }
    if (_splitEvenly) {
      final people = _friends.length + 1;
      final each = total > 0 ? (total / people).round() : 0;
      return List<int>.filled(_friends.length, each);
    }
    return _friends.map((f) => _parseDigits(f.customAmountCtrl.text)).toList();
  }

  int get _friendsTotal =>
      _computedFriendShares().fold<int>(0, (sum, amt) => sum + amt);

  int get _myShare {
    final diff = _totalBill - _friendsTotal;
    return diff > 0 ? diff : 0;
  }

  void _addFriend() {
    HapticFeedback.selectionClick();
    setState(() {
      _friends.add(_FriendDraft(name: 'Teman ${_friends.length + 1}'));
      _error = null;
    });
  }

  void _removeFriend(int index) {
    if (_friends.length <= 1) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      final removed = _friends.removeAt(index);
      removed.dispose();
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    final total = _totalBill;
    if (total <= 0) {
      setState(() => _error = 'Isi total tagihan dulu ya.');
      return;
    }

    final shares = _computedFriendShares();
    final friendsPayload = <SplitBillFriend>[];
    for (var i = 0; i < _friends.length; i++) {
      final name = _friends[i].nameCtrl.text.trim();
      final share = shares[i];
      if (name.isEmpty) {
        setState(() => _error = 'Nama teman ke-${i + 1} belum diisi.');
        return;
      }
      if (share <= 0) {
        setState(() => _error = 'Nominal porsi $name harus lebih dari 0.');
        return;
      }
      friendsPayload.add(
        SplitBillFriend(
          name: name,
          phone: _friends[i].phoneCtrl.text.trim(),
          shareAmount: share,
        ),
      );
    }

    if (_friendsTotal > total) {
      setState(
        () => _error = 'Total porsi teman melebihi total tagihan.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final count = await widget.controller.recordSplitBill(
        title: _titleCtrl.text.trim(),
        walletId: _walletId,
        category: _category,
        myShare: _myShare,
        friends: friendsPayload,
      );
      HapticFeedback.lightImpact();
      if (mounted) {
        Navigator.of(context).pop(count);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saku = context.saku;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final wallets = widget.controller.wallets;
    final shares = _computedFriendShares();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.90;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SakuSheetHandle(),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Split Bill / Patungan',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Porsi kamu masuk pengeluaran, porsi teman otomatis jadi Piutang + siap tagih WhatsApp.',
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
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Acara / Tempat',
                        hintText: 'Contoh: Nongkrong Kopi Kenangan',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _totalCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: saku.textPrimary,
                        fontFeatures: AppTheme.tabularNums,
                      ),
                      onChanged: (_) => setState(() => _error = null),
                      decoration: const InputDecoration(
                        prefixText: 'Rp ',
                        labelText: 'Total Tagihan',
                        hintText: '200000',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: wallets.any((w) => w.id == _walletId)
                                ? _walletId
                                : (wallets.isNotEmpty ? wallets.first.id : null),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Dompet Kamu',
                            ),
                            items: wallets
                                .where((w) => w.id != null)
                                .map(
                                  (w) => DropdownMenuItem<int>(
                                    value: w.id!,
                                    child: Row(
                                      children: <Widget>[
                                        WalletBrandAvatar.fromWallet(
                                          w,
                                          size: 20,
                                          borderRadius: 6,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            w.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _walletId = v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _category,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Kategori',
                            ),
                            items: CategoryCatalog.expenseCategories
                                .map(
                                  (c) => DropdownMenuItem<String>(
                                    value: c.name,
                                    child: Text(
                                      c.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _category = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Bagi Rata'),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Atur per Orang'),
                        ),
                      ],
                      selected: <bool>{_splitEvenly},
                      onSelectionChanged: (sel) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _splitEvenly = sel.first;
                          if (!_splitEvenly && _totalBill > 0) {
                            final each =
                                (_totalBill / (_friends.length + 1)).round();
                            for (final f in _friends) {
                              if (f.customAmountCtrl.text.isEmpty) {
                                f.customAmountCtrl.text = each.toString();
                              }
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Daftar Teman (${_friends.length} orang)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addFriend,
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                          label: const Text('Tambah'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (var i = 0; i < _friends.length; i++) ...<Widget>[
                      LuxurySurfaceCard(
                        padding: const EdgeInsets.all(12),
                        radius: SakuRadius.md,
                        child: Column(
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextField(
                                    controller: _friends[i].nameCtrl,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: 'Nama Teman ${i + 1}',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_splitEvenly)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: saku.brandSoft,
                                      borderRadius: BorderRadius.circular(
                                        SakuRadius.sm,
                                      ),
                                    ),
                                    child: Text(
                                      IdrFormat.compact(shares[i]),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: saku.brandInteractive,
                                        fontFeatures: AppTheme.tabularNums,
                                      ),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    width: 112,
                                    child: TextField(
                                      controller: _friends[i].customAmountCtrl,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: <TextInputFormatter>[
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        prefixText: 'Rp ',
                                        labelText: 'Porsi',
                                      ),
                                    ),
                                  ),
                                if (_friends.length > 1)
                                  IconButton(
                                    tooltip: 'Hapus teman',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _removeFriend(i),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: saku.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _friends[i].phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'No. WhatsApp (opsional)',
                                hintText: '0812xxxxxxxx',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 4),
                    LuxurySurfaceCard(
                      padding: const EdgeInsets.all(14),
                      radius: SakuRadius.md,
                      color: saku.surfaceElevated,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Porsi Kamu (Pengeluaran)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: saku.textMuted,
                                  ),
                                ),
                                Text(
                                  IdrFormat.currency(_myShare),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: saku.expense,
                                    fontFeatures: AppTheme.tabularNums,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Text(
                                  'Piutang ${_friends.length} Teman',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: saku.textMuted,
                                  ),
                                ),
                                Text(
                                  IdrFormat.currency(_friendsTotal),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: saku.income,
                                    fontFeatures: AppTheme.tabularNums,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: const Icon(Icons.groups_outlined, size: 19),
              label: Text(
                _isSaving ? 'Menyimpan...' : 'Simpan Patungan',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

enum WalletKind {
  cash('cash', 'Tunai'),
  bank('bank', 'Rekening Bank'),
  ewallet('ewallet', 'E-Wallet'),
  savings('savings', 'Tabungan');

  const WalletKind(this.code, this.label);

  final String code;
  final String label;

  static WalletKind fromCode(String? raw) {
    for (final item in WalletKind.values) {
      if (item.code == raw) {
        return item;
      }
    }
    return WalletKind.cash;
  }
}

class WalletPalette {
  WalletPalette._();

  static const List<int> presetColors = <int>[
    0xFF0F766E,
    0xFF1D4ED8,
    0xFF0284C7,
    0xFF059669,
    0xFFD97706,
    0xFF7C3AED,
    0xFFBE123C,
    0xFF334155,
  ];

  static const Map<String, IconData> icons = <String, IconData>{
    'payments': Icons.payments_outlined,
    'account_balance': Icons.account_balance_outlined,
    'wallet': Icons.account_balance_wallet_outlined,
    'qr_code': Icons.qr_code_2_rounded,
    'savings': Icons.savings_outlined,
    'credit_card': Icons.credit_card_outlined,
    'phone_android': Icons.phone_android_outlined,
    'work': Icons.work_outline_rounded,
  };

  static IconData iconFor(String key) =>
      icons[key] ?? Icons.account_balance_wallet_outlined;
}

class WalletModel {
  const WalletModel({
    this.id,
    required this.name,
    required this.kind,
    required this.balance,
    required this.colorValue,
    required this.iconKey,
    this.excludeFromTotal = false,
    this.sortOrder = 0,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final WalletKind kind;
  final int balance;
  final int colorValue;
  final String iconKey;
  final bool excludeFromTotal;
  final int sortOrder;
  final DateTime createdAt;

  Color get color => Color(colorValue);
  IconData get icon => WalletPalette.iconFor(iconKey);

  WalletModel copyWith({
    int? id,
    String? name,
    WalletKind? kind,
    int? balance,
    int? colorValue,
    String? iconKey,
    bool? excludeFromTotal,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return WalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      balance: balance ?? this.balance,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
      excludeFromTotal: excludeFromTotal ?? this.excludeFromTotal,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'type': kind.code,
      'balance': balance,
      'color_hex': colorValue,
      'icon_name': iconKey,
      'exclude_from_total': excludeFromTotal ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory WalletModel.fromMap(Map<String, Object?> map) {
    return WalletModel(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? 'Dompet',
      kind: WalletKind.fromCode(map['type'] as String?),
      balance: (map['balance'] as num?)?.toInt() ?? 0,
      colorValue: (map['color_hex'] as num?)?.toInt() ?? 0xFF0F766E,
      iconKey: (map['icon_name'] as String?) ?? 'wallet',
      excludeFromTotal: ((map['exclude_from_total'] as num?)?.toInt() ?? 0) == 1,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

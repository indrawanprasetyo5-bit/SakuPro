import 'package:material_ui/material_ui.dart';

class GoalIconCatalog {
  GoalIconCatalog._();

  static const Map<String, IconData> icons = <String, IconData>{
    'savings': Icons.savings_outlined,
    'shield': Icons.verified_user_outlined,
    'laptop': Icons.laptop_mac_rounded,
    'flight': Icons.flight_takeoff_rounded,
    'home': Icons.home_work_outlined,
    'car': Icons.directions_car_outlined,
    'school': Icons.school_outlined,
    'favorite': Icons.favorite_border_rounded,
  };

  static const List<int> colors = <int>[
    0xFF0F766E,
    0xFF1D4ED8,
    0xFF0284C7,
    0xFF059669,
    0xFFD97706,
    0xFF7C3AED,
    0xFFBE123C,
  ];

  static IconData iconFor(String key) =>
      icons[key] ?? Icons.savings_outlined;
}

class BudgetModel {
  const BudgetModel({
    this.id,
    required this.category,
    required this.monthlyLimit,
    required this.monthKey,
    this.alertThreshold = 0.8,
    required this.createdAt,
  });

  final int? id;
  final String category;
  final int monthlyLimit;
  final String monthKey;
  final double alertThreshold;
  final DateTime createdAt;

  BudgetModel copyWith({
    int? id,
    String? category,
    int? monthlyLimit,
    String? monthKey,
    double? alertThreshold,
    DateTime? createdAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      category: category ?? this.category,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      monthKey: monthKey ?? this.monthKey,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'category': category,
      'monthly_limit': monthlyLimit,
      'month_key': monthKey,
      'alert_threshold': alertThreshold,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BudgetModel.fromMap(Map<String, Object?> map) {
    return BudgetModel(
      id: map['id'] as int?,
      category: (map['category'] as String?) ?? 'GLOBAL',
      monthlyLimit: (map['monthly_limit'] as num?)?.toInt() ?? 0,
      monthKey: (map['month_key'] as String?) ?? '',
      alertThreshold: (map['alert_threshold'] as num?)?.toDouble() ?? 0.8,
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class GoalModel {
  const GoalModel({
    this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.deadline,
    this.walletId,
    this.colorValue = 0xFF0F766E,
    this.iconKey = 'savings',
    this.isCompleted = false,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final int targetAmount;
  final int currentAmount;
  final DateTime? deadline;
  final int? walletId;
  final int colorValue;
  final String iconKey;
  final bool isCompleted;
  final DateTime createdAt;

  Color get color => Color(colorValue);
  IconData get icon => GoalIconCatalog.iconFor(iconKey);

  double get progressRatio =>
      targetAmount <= 0 ? 0.0 : currentAmount / targetAmount;

  int get remainingAmount =>
      targetAmount > currentAmount ? targetAmount - currentAmount : 0;

  bool get reachedTarget => isCompleted || currentAmount >= targetAmount;

  GoalModel copyWith({
    int? id,
    String? name,
    int? targetAmount,
    int? currentAmount,
    DateTime? deadline,
    bool clearDeadline = false,
    int? walletId,
    int? colorValue,
    String? iconKey,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      walletId: walletId ?? this.walletId,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'deadline': deadline?.toIso8601String(),
      'wallet_id': walletId,
      'color_hex': colorValue,
      'icon_name': iconKey,
      'is_completed': isCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory GoalModel.fromMap(Map<String, Object?> map) {
    final rawDeadline = map['deadline'] as String?;
    return GoalModel(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      targetAmount: (map['target_amount'] as num?)?.toInt() ?? 0,
      currentAmount: (map['current_amount'] as num?)?.toInt() ?? 0,
      deadline: rawDeadline != null && rawDeadline.isNotEmpty
          ? DateTime.tryParse(rawDeadline)
          : null,
      walletId: (map['wallet_id'] as num?)?.toInt(),
      colorValue: (map['color_hex'] as num?)?.toInt() ?? 0xFF0F766E,
      iconKey: (map['icon_name'] as String?) ?? 'savings',
      isCompleted: ((map['is_completed'] as num?)?.toInt() ?? 0) == 1,
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

enum DebtKind {
  receivable('receivable', 'Piutang (Orang Pinjam)'),
  payable('payable', 'Hutang (Saya Pinjam)');

  const DebtKind(this.code, this.label);
  final String code;
  final String label;

  static DebtKind fromCode(String? raw) =>
      raw == 'receivable' ? DebtKind.receivable : DebtKind.payable;
}

class DebtModel {
  const DebtModel({
    this.id,
    required this.personName,
    this.phone = '',
    required this.type,
    required this.principalAmount,
    required this.remainingAmount,
    this.dueDate,
    this.note = '',
    this.status = 'open',
    required this.createdAt,
  });

  final int? id;
  final String personName;
  final String phone;
  final String type;
  final int principalAmount;
  final int remainingAmount;
  final DateTime? dueDate;
  final String note;
  final String status;
  final DateTime createdAt;

  DebtKind get kind => DebtKind.fromCode(type);
  bool get isReceivable => kind == DebtKind.receivable;
  bool get isSettled => status == 'paid' || remainingAmount <= 0;
  int get paidAmount =>
      (principalAmount - remainingAmount).clamp(0, principalAmount);
  double get progressRatio =>
      principalAmount <= 0 ? 1.0 : paidAmount / principalAmount;

  DebtModel copyWith({
    int? id,
    String? personName,
    String? phone,
    String? type,
    int? principalAmount,
    int? remainingAmount,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? note,
    String? status,
    DateTime? createdAt,
  }) {
    return DebtModel(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      phone: phone ?? this.phone,
      type: type ?? this.type,
      principalAmount: principalAmount ?? this.principalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      note: note ?? this.note,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'person_name': personName,
      'phone': phone,
      'type': type,
      'principal_amount': principalAmount,
      'remaining_amount': remainingAmount,
      'due_date': dueDate?.toIso8601String(),
      'note': note,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DebtModel.fromMap(Map<String, Object?> map) {
    final rawDue = map['due_date'] as String?;
    return DebtModel(
      id: map['id'] as int?,
      personName: (map['person_name'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      type: (map['type'] as String?) ?? 'receivable',
      principalAmount: (map['principal_amount'] as num?)?.toInt() ?? 0,
      remainingAmount: (map['remaining_amount'] as num?)?.toInt() ?? 0,
      dueDate: rawDue != null && rawDue.isNotEmpty
          ? DateTime.tryParse(rawDue)
          : null,
      note: (map['note'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'open',
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class BillModel {
  const BillModel({
    this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.dueDay,
    this.frequency = 'monthly',
    this.walletId,
    this.isPaidCurrentCycle = false,
    this.lastPaidMonth = '',
    this.autoRemind = true,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final int amount;
  final String category;
  final int dueDay;
  final String frequency;
  final int? walletId;
  final bool isPaidCurrentCycle;
  final String lastPaidMonth;
  final bool autoRemind;
  final DateTime createdAt;

  static String monthKeyFor(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';

  bool isPaidFor(DateTime current) {
    final key = monthKeyFor(current);
    if (lastPaidMonth.isNotEmpty) {
      return lastPaidMonth == key;
    }
    return isPaidCurrentCycle;
  }

  BillModel copyWith({
    int? id,
    String? name,
    int? amount,
    String? category,
    int? dueDay,
    String? frequency,
    int? walletId,
    bool? isPaidCurrentCycle,
    String? lastPaidMonth,
    bool? autoRemind,
    DateTime? createdAt,
  }) {
    return BillModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dueDay: dueDay ?? this.dueDay,
      frequency: frequency ?? this.frequency,
      walletId: walletId ?? this.walletId,
      isPaidCurrentCycle: isPaidCurrentCycle ?? this.isPaidCurrentCycle,
      lastPaidMonth: lastPaidMonth ?? this.lastPaidMonth,
      autoRemind: autoRemind ?? this.autoRemind,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'amount': amount,
      'category': category,
      'due_day': dueDay,
      'frequency': frequency,
      'wallet_id': walletId,
      'is_paid_current_cycle': isPaidCurrentCycle ? 1 : 0,
      'last_paid_month': lastPaidMonth,
      'auto_remind': autoRemind ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BillModel.fromMap(Map<String, Object?> map) {
    return BillModel(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      category: (map['category'] as String?) ?? 'Tagihan & Utilitas',
      dueDay: (map['due_day'] as num?)?.toInt() ?? 1,
      frequency: (map['frequency'] as String?) ?? 'monthly',
      walletId: (map['wallet_id'] as num?)?.toInt(),
      isPaidCurrentCycle:
          ((map['is_paid_current_cycle'] as num?)?.toInt() ?? 0) == 1,
      lastPaidMonth: (map['last_paid_month'] as String?) ?? '',
      autoRemind: ((map['auto_remind'] as num?)?.toInt() ?? 1) == 1,
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

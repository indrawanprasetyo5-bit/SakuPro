class RecurringIncomeModel {
  const RecurringIncomeModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.dayOfMonth,
    required this.walletId,
    this.category = 'Gaji',
    this.enabled = true,
    this.lastCreditedMonth = '',
  });

  final String id;
  final String name;
  final int amount;
  final int dayOfMonth;
  final int walletId;
  final String category;
  final bool enabled;
  final String lastCreditedMonth;

  static String monthKeyFor(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';

  bool isCreditedFor(DateTime current) =>
      lastCreditedMonth == monthKeyFor(current);

  RecurringIncomeModel copyWith({
    String? id,
    String? name,
    int? amount,
    int? dayOfMonth,
    int? walletId,
    String? category,
    bool? enabled,
    String? lastCreditedMonth,
  }) {
    return RecurringIncomeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      walletId: walletId ?? this.walletId,
      category: category ?? this.category,
      enabled: enabled ?? this.enabled,
      lastCreditedMonth: lastCreditedMonth ?? this.lastCreditedMonth,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'amount': amount,
    'dayOfMonth': dayOfMonth,
    'walletId': walletId,
    'category': category,
    'enabled': enabled,
    'lastCreditedMonth': lastCreditedMonth,
  };

  factory RecurringIncomeModel.fromJson(Map<String, Object?> map) {
    return RecurringIncomeModel(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Gaji Bulanan',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      dayOfMonth: ((map['dayOfMonth'] as num?)?.toInt() ?? 25).clamp(1, 28),
      walletId: (map['walletId'] as num?)?.toInt() ?? 1,
      category: (map['category'] as String?) ?? 'Gaji',
      enabled: (map['enabled'] as bool?) ?? true,
      lastCreditedMonth: (map['lastCreditedMonth'] as String?) ?? '',
    );
  }
}

class AutomationRunSummary {
  const AutomationRunSummary({
    this.autoCreditedIncomes = 0,
    this.autoPaidBills = 0,
    this.dueBillReminders = 0,
  });

  final int autoCreditedIncomes;
  final int autoPaidBills;
  final int dueBillReminders;

  int get totalRecorded => autoCreditedIncomes + autoPaidBills;
}

class MonthlyClosingRecap {
  const MonthlyClosingRecap({
    required this.monthKey,
    required this.month,
    required this.income,
    required this.expense,
    required this.surplus,
    required this.savingsRatePercent,
    required this.topCategory,
    required this.transactionCount,
    this.savedExcelPath = '',
  });

  final String monthKey;
  final DateTime month;
  final int income;
  final int expense;
  final int surplus;
  final double? savingsRatePercent;
  final String topCategory;
  final int transactionCount;
  final String savedExcelPath;
}

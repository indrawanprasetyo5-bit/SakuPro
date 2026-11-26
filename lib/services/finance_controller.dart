import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../db/database_helper.dart';
import '../models/automation_models.dart';
import '../models/category_meta.dart';
import '../models/roadmap_models.dart';
import '../models/transaction_item.dart';
import '../models/wallet.dart';
import '../theme/currency_format.dart';
import 'automation_bridge_service.dart';
import 'export_backup_service.dart';

enum SafeSpendLevel {
  safe('Aman'),
  caution('Hati-hati'),
  overbudget('Overbudget');

  const SafeSpendLevel(this.label);
  final String label;
}

class SafeSpendSnapshot {
  const SafeSpendSnapshot({
    required this.monthlyBudget,
    required this.monthlyExpense,
    required this.remainingBudget,
    required this.remainingDays,
    required this.dailySafeAmount,
    required this.usageRatio,
    required this.level,
  });

  final int monthlyBudget;
  final int monthlyExpense;
  final int remainingBudget;
  final int remainingDays;
  final int dailySafeAmount;
  final double usageRatio;
  final SafeSpendLevel level;
}

class CategorySpendSlice {
  const CategorySpendSlice({
    required this.category,
    required this.amount,
    required this.share,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String category;
  final int amount;
  final double share;
  final int count;
  final Color color;
  final IconData icon;
}

class MonthlyAnalyticsReport {
  const MonthlyAnalyticsReport({
    required this.month,
    required this.transactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.previousMonthExpense,
    required this.expenseDeltaPercent,
    required this.savingsRatePercent,
    required this.categorySlices,
    required this.insights,
  });

  final DateTime month;
  final List<TransactionModel> transactions;
  final int totalIncome;
  final int totalExpense;
  final int previousMonthExpense;
  final double? expenseDeltaPercent;
  final double? savingsRatePercent;
  final List<CategorySpendSlice> categorySlices;
  final List<String> insights;
}

class QuickHabitPreset {
  const QuickHabitPreset({
    required this.label,
    required this.phrase,
    this.isLearned = false,
  });

  final String label;
  final String phrase;
  final bool isLearned;
}

class MonthlyTrendPoint {
  const MonthlyTrendPoint({
    required this.month,
    required this.shortLabel,
    required this.income,
    required this.expense,
  });

  final DateTime month;
  final String shortLabel;
  final int income;
  final int expense;
}

class WeekdaySpendBucket {
  const WeekdaySpendBucket({
    required this.weekday,
    required this.shortLabel,
    required this.fullLabel,
    required this.amount,
    required this.count,
  });

  final int weekday;
  final String shortLabel;
  final String fullLabel;
  final int amount;
  final int count;
}

class WeekdaySpendPattern {
  const WeekdaySpendPattern({
    required this.buckets,
    required this.peakBucket,
    required this.totalExpense,
  });

  final List<WeekdaySpendBucket> buckets;
  final WeekdaySpendBucket? peakBucket;
  final int totalExpense;
}

class SplitBillFriend {
  const SplitBillFriend({
    required this.name,
    required this.shareAmount,
    this.phone = '',
  });

  final String name;
  final int shareAmount;
  final String phone;
}

class FinanceController extends ChangeNotifier {
  FinanceController({this._customStore, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SakuStore? _customStore;
  final DateTime Function() _clock;

  SakuStore? _store;
  bool _isLoading = true;
  String? _errorMessage;

  ThemeMode _themeMode = ThemeMode.dark;
  bool _hideBalance = false;
  bool _appLockEnabled = false;
  bool _biometricEnabled = false;
  String _pinCode = '';
  bool _isSessionLocked = false;

  bool _smartAlertsEnabled = true;
  bool _autoBackupEnabled = true;
  bool _autoSaveGoalEnabled = false;
  int _autoSaveGoalPercent = 20;
  int? _autoSaveGoalId;
  String _lastAutoBackupDate = '';
  String _lastAutoBackupPath = '';
  String _lastClosedMonthKey = '';
  String _lastClosedExcelPath = '';
  String _dismissedRecapMonthKey = '';
  bool _postNotificationGranted = false;
  Map<String, String> _learnedMerchantCategories = <String, String>{};
  Set<int> _autoPayBillIds = <int>{};
  List<RecurringIncomeModel> _recurringIncomes = <RecurringIncomeModel>[];
  final Set<String> _sentAlertKeysToday = <String>{};

  int _monthlyBudget = 3000000;
  List<WalletModel> _wallets = <WalletModel>[];
  List<TransactionModel> _transactions = <TransactionModel>[];
  List<BudgetModel> _categoryBudgets = <BudgetModel>[];
  List<GoalModel> _goals = <GoalModel>[];
  List<BillModel> _bills = <BillModel>[];
  List<DebtModel> _debts = <DebtModel>[];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ThemeMode get themeMode => _themeMode;
  bool get hideBalance => _hideBalance;
  bool get appLockEnabled => _appLockEnabled;
  bool get biometricEnabled => _biometricEnabled;
  bool get isSessionLocked => _appLockEnabled && _isSessionLocked;
  bool get smartAlertsEnabled => _smartAlertsEnabled;
  bool get autoBackupEnabled => _autoBackupEnabled;
  bool get autoSaveGoalEnabled => _autoSaveGoalEnabled;
  int get autoSaveGoalPercent => _autoSaveGoalPercent;
  int? get autoSaveGoalId => _autoSaveGoalId;
  String get lastAutoBackupDate => _lastAutoBackupDate;
  String get lastAutoBackupPath => _lastAutoBackupPath;
  String get lastClosedExcelPath => _lastClosedExcelPath;
  bool get postNotificationGranted => _postNotificationGranted;
  Map<String, String> get learnedMerchantCategories =>
      Map<String, String>.unmodifiable(_learnedMerchantCategories);
  Set<int> get autoPayBillIds => Set<int>.unmodifiable(_autoPayBillIds);
  List<RecurringIncomeModel> get recurringIncomes =>
      List<RecurringIncomeModel>.unmodifiable(_recurringIncomes);
  int get monthlyBudget => _monthlyBudget;
  bool get isUsingInMemory => _store?.isInMemory ?? false;

  List<WalletModel> get wallets => List<WalletModel>.unmodifiable(_wallets);
  List<TransactionModel> get transactions =>
      List<TransactionModel>.unmodifiable(_transactions);
  List<BudgetModel> get categoryBudgets =>
      List<BudgetModel>.unmodifiable(_categoryBudgets);
  List<GoalModel> get goals => List<GoalModel>.unmodifiable(_goals);
  List<BillModel> get bills => List<BillModel>.unmodifiable(_bills);
  List<DebtModel> get debts => List<DebtModel>.unmodifiable(_debts);

  DateTime get now => _clock();

  int get netWorth {
    var sum = 0;
    for (final w in _wallets) {
      if (!w.excludeFromTotal) {
        sum += w.balance;
      }
    }
    return sum;
  }

  int get totalAllWallets {
    var sum = 0;
    for (final w in _wallets) {
      sum += w.balance;
    }
    return sum;
  }

  WalletModel? walletById(int? id) {
    if (id == null) {
      return null;
    }
    for (final w in _wallets) {
      if (w.id == id) {
        return w;
      }
    }
    return null;
  }

  List<TransactionModel> transactionsForMonth(DateTime month) {
    return _transactions.where((tx) {
      return tx.transactionDate.year == month.year &&
          tx.transactionDate.month == month.month;
    }).toList();
  }

  List<TransactionModel> get currentMonthTransactions =>
      transactionsForMonth(now);

  List<DateTime> get selectableMonths {
    final current = DateTime(now.year, now.month);
    final set = <String, DateTime>{};
    for (var i = 0; i < 6; i++) {
      final dt = DateTime(current.year, current.month - i);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      set[key] = dt;
    }
    for (final tx in _transactions) {
      final dt = DateTime(tx.transactionDate.year, tx.transactionDate.month);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      set[key] = dt;
    }
    final list = set.values.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  int get monthlyIncome {
    var sum = 0;
    for (final tx in currentMonthTransactions) {
      if (tx.kind == TransactionKind.income) {
        sum += tx.amount;
      }
    }
    return sum;
  }

  int get monthlyExpense {
    var sum = 0;
    for (final tx in currentMonthTransactions) {
      // Transfers between user wallets never count as expense.
      if (tx.kind == TransactionKind.expense) {
        sum += tx.amount;
      }
    }
    return sum;
  }

  Map<String, int> get monthlyExpenseByCategory {
    final result = <String, int>{};
    for (final tx in currentMonthTransactions) {
      if (tx.kind == TransactionKind.expense) {
        result[tx.category] = (result[tx.category] ?? 0) + tx.amount;
      }
    }
    return result;
  }

  int spentForCategory(String category) =>
      monthlyExpenseByCategory[category] ?? 0;

  int get totalCategoryBudgetsSum {
    var sum = 0;
    for (final b in _categoryBudgets) {
      sum += b.monthlyLimit;
    }
    return sum;
  }

  int get unpaidBillsTotal {
    final current = now;
    var sum = 0;
    for (final bill in _bills) {
      if (!bill.isPaidFor(current)) {
        sum += bill.amount;
      }
    }
    return sum;
  }

  int get activeReceivablesTotal {
    var sum = 0;
    for (final d in _debts) {
      if (d.isReceivable && !d.isSettled) {
        sum += d.remainingAmount;
      }
    }
    return sum;
  }

  int get activePayablesTotal {
    var sum = 0;
    for (final d in _debts) {
      if (!d.isReceivable && !d.isSettled) {
        sum += d.remainingAmount;
      }
    }
    return sum;
  }

  MonthlyAnalyticsReport buildMonthlyReport(DateTime targetMonth) {
    final normalizedMonth = DateTime(targetMonth.year, targetMonth.month);
    final prevMonth = DateTime(targetMonth.year, targetMonth.month - 1);

    final monthTx = transactionsForMonth(normalizedMonth);
    final prevTx = transactionsForMonth(prevMonth);

    var income = 0;
    var expense = 0;
    final catTotals = <String, int>{};
    final catCounts = <String, int>{};

    for (final tx in monthTx) {
      if (tx.kind == TransactionKind.income) {
        income += tx.amount;
      } else if (tx.kind == TransactionKind.expense) {
        expense += tx.amount;
        catTotals[tx.category] = (catTotals[tx.category] ?? 0) + tx.amount;
        catCounts[tx.category] = (catCounts[tx.category] ?? 0) + 1;
      }
    }

    var prevExpense = 0;
    for (final tx in prevTx) {
      if (tx.kind == TransactionKind.expense) {
        prevExpense += tx.amount;
      }
    }

    final slices = catTotals.entries.map((e) {
      final meta = CategoryCatalog.resolve(TransactionKind.expense, e.key);
      return CategorySpendSlice(
        category: e.key,
        amount: e.value,
        share: expense <= 0 ? 0.0 : e.value / expense,
        count: catCounts[e.key] ?? 0,
        color: meta.color,
        icon: meta.icon,
      );
    }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

    final double? deltaPct = prevExpense > 0
        ? ((expense - prevExpense) / prevExpense) * 100
        : null;

    final double? savingsPct = income > 0
        ? ((income - expense) / income) * 100
        : null;

    final insights = <String>[];
    if (income == 0 && expense == 0) {
      insights.add(
        'Belum ada catatan keluar masuk bulan ini. Mulai dari transaksi pertamamu di tombol +.',
      );
    } else {
      if (slices.isNotEmpty) {
        final top = slices.first;
        final topPct = (top.share * 100).round();
        insights.add(
          'Pos terbesar bulan ini ada di ${top.category}, total ${IdrFormat.currency(top.amount, hidden: _hideBalance)} ($topPct% dari seluruh belanja).',
        );
      }

      if (deltaPct != null) {
        final diffAbs = (expense - prevExpense).abs();
        final rounded = deltaPct.abs().round();
        if (expense < prevExpense) {
          insights.add(
            'Belanjamu turun $rounded% dari bulan lalu, lebih hemat ${IdrFormat.currency(diffAbs, hidden: _hideBalance)}.',
          );
        } else if (expense > prevExpense) {
          insights.add(
            'Belanjamu naik $rounded% dibanding bulan lalu, bertambah ${IdrFormat.currency(diffAbs, hidden: _hideBalance)}.',
          );
        } else {
          insights.add(
            'Total pengeluaranmu persis sama dengan bulan lalu.',
          );
        }
      } else if (expense > 0) {
        insights.add(
          'Bulan ini jadi acuan awalmu, bulan depan perbandingan tren otomatis muncul di sini.',
        );
      }

      if (savingsPct != null) {
        final net = income - expense;
        final pctRounded = savingsPct.round();
        if (net >= 0) {
          insights.add(
            'Kamu menyisihkan $pctRounded% dari pemasukan bulan ini dengan surplus ${IdrFormat.currency(net, hidden: _hideBalance)}.',
          );
        } else {
          insights.add(
            'Pengeluaran bulan ini melebihi pemasukan sebesar ${IdrFormat.currency(net.abs(), hidden: _hideBalance)}.',
          );
        }
      }
    }

    return MonthlyAnalyticsReport(
      month: normalizedMonth,
      transactions: monthTx,
      totalIncome: income,
      totalExpense: expense,
      previousMonthExpense: prevExpense,
      expenseDeltaPercent: deltaPct,
      savingsRatePercent: savingsPct,
      categorySlices: slices,
      insights: insights,
    );
  }

  SafeSpendSnapshot get safeToSpend {
    final current = now;
    final daysInMonth = DateTime(current.year, current.month + 1, 0).day;
    final remainingDays = (daysInMonth - current.day + 1).clamp(1, 31);
    final spent = monthlyExpense;
    final budget = _monthlyBudget;
    final remaining = budget - spent;

    if (budget <= 0) {
      return SafeSpendSnapshot(
        monthlyBudget: 0,
        monthlyExpense: spent,
        remainingBudget: -spent,
        remainingDays: remainingDays,
        dailySafeAmount: 0,
        usageRatio: 0,
        level: SafeSpendLevel.caution,
      );
    }

    final ratio = spent / budget;
    final dailySafe = remaining <= 0 ? 0 : (remaining / remainingDays).floor();
    final idealDaily = budget / daysInMonth;

    final SafeSpendLevel level;
    if (remaining < 0) {
      level = SafeSpendLevel.overbudget;
    } else if (ratio >= 0.78 || dailySafe < idealDaily * 0.55) {
      level = SafeSpendLevel.caution;
    } else {
      level = SafeSpendLevel.safe;
    }

    return SafeSpendSnapshot(
      monthlyBudget: budget,
      monthlyExpense: spent,
      remainingBudget: remaining,
      remainingDays: remainingDays,
      dailySafeAmount: dailySafe,
      usageRatio: ratio,
      level: level,
    );
  }

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_customStore != null) {
        await _customStore.init();
        _store = _customStore;
      } else {
        _store = await DatabaseHelper.openPreferredStore();
      }

      final store = _store!;
      final savedTheme = await store.getSetting('theme_mode');
      if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      }

      final savedHide = await store.getSetting('hide_balance');
      _hideBalance = savedHide == '1';

      final savedLock = await store.getSetting('lock_enabled');
      final savedPin = await store.getSetting('lock_pin') ?? '';
      final savedBio = await store.getSetting('lock_biometric');

      _pinCode = savedPin;
      _appLockEnabled = savedLock == '1' && savedPin.length == 4;
      _biometricEnabled = savedBio == '1';
      _isSessionLocked = _appLockEnabled;

      await _loadAutomationSettings(store);
      await _reloadData();
      await runRecurringAutomations(notify: false);

      if (_customStore == null) {
        unawaited(_bootstrapNativeAutomations());
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Gagal memuat penyimpanan lokal: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadData() async {
    final store = _store;
    if (store == null) {
      return;
    }
    _wallets = await store.getWallets();
    _transactions = await store.getTransactions();
    _monthlyBudget = await store.getGlobalMonthlyBudget();
    _categoryBudgets = await store.getCategoryBudgets();
    _goals = await store.getGoals();
    _bills = await store.getBills();
    _debts = await store.getDebts();
    unawaited(_syncHomeWidgetAndReminders());
  }

  bool verifyPinAndUnlock(String enteredPin) {
    if (enteredPin == _pinCode) {
      _isSessionLocked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  void unlockByBiometrics() {
    _isSessionLocked = false;
    notifyListeners();
  }

  void lockSessionNow() {
    if (_appLockEnabled && _pinCode.length == 4) {
      _isSessionLocked = true;
      notifyListeners();
    }
  }

  Future<void> enableAppLock({
    required String pin,
    required bool useBiometric,
  }) async {
    if (pin.length != 4) {
      return;
    }
    final store = _store;
    _pinCode = pin;
    _appLockEnabled = true;
    _biometricEnabled = useBiometric;
    _isSessionLocked = false;
    notifyListeners();

    if (store != null) {
      await store.setSetting('lock_enabled', '1');
      await store.setSetting('lock_pin', pin);
      await store.setSetting('lock_biometric', useBiometric ? '1' : '0');
    }
  }

  Future<void> disableAppLock() async {
    final store = _store;
    _appLockEnabled = false;
    _biometricEnabled = false;
    _pinCode = '';
    _isSessionLocked = false;
    notifyListeners();

    if (store != null) {
      await store.setSetting('lock_enabled', '0');
      await store.setSetting('lock_pin', '');
      await store.setSetting('lock_biometric', '0');
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final store = _store;
    _biometricEnabled = enabled;
    notifyListeners();
    if (store != null) {
      await store.setSetting('lock_biometric', enabled ? '1' : '0');
    }
  }

  Future<Map<String, Object?>> createBackupSnapshot() async {
    final store = _store;
    if (store == null) {
      throw const StorageException('Penyimpanan belum siap.');
    }
    final base = Map<String, Object?>.from(await store.exportSnapshot());
    base['automation_settings'] = <String, Object?>{
      'smart_alerts_enabled': _smartAlertsEnabled,
      'auto_backup_enabled': _autoBackupEnabled,
      'auto_save_goal_enabled': _autoSaveGoalEnabled,
      'auto_save_goal_percent': _autoSaveGoalPercent,
      'auto_save_goal_id': _autoSaveGoalId,
      'merchant_category_memory': _learnedMerchantCategories,
      'auto_pay_bill_ids': _autoPayBillIds.toList(),
      'recurring_incomes': _recurringIncomes.map((e) => e.toJson()).toList(),
    };
    return base;
  }

  Future<void> restoreFromBackupJson(String rawJson) async {
    final store = _store;
    if (store == null) {
      throw const StorageException('Penyimpanan belum siap.');
    }
    final validated = ExportBackupService.decodeAndValidateBackupJson(rawJson);
    await store.restoreSnapshot(validated);

    final autoRaw = validated['automation_settings'];
    if (autoRaw is Map) {
      final auto = Map<String, Object?>.from(autoRaw);
      if (auto['smart_alerts_enabled'] is bool) {
        _smartAlertsEnabled = auto['smart_alerts_enabled'] as bool;
        await store.setSetting(
          'smart_alerts_enabled',
          _smartAlertsEnabled ? '1' : '0',
        );
      }
      if (auto['auto_backup_enabled'] is bool) {
        _autoBackupEnabled = auto['auto_backup_enabled'] as bool;
        await store.setSetting(
          'auto_backup_enabled',
          _autoBackupEnabled ? '1' : '0',
        );
      }
      if (auto['auto_save_goal_enabled'] is bool) {
        _autoSaveGoalEnabled = auto['auto_save_goal_enabled'] as bool;
        await store.setSetting(
          'auto_save_goal_enabled',
          _autoSaveGoalEnabled ? '1' : '0',
        );
      }
      if (auto['auto_save_goal_percent'] is num) {
        _autoSaveGoalPercent = (auto['auto_save_goal_percent'] as num)
            .toInt()
            .clamp(5, 50);
        await store.setSetting(
          'auto_save_goal_percent',
          _autoSaveGoalPercent.toString(),
        );
      }
      if (auto['auto_save_goal_id'] is num) {
        _autoSaveGoalId = (auto['auto_save_goal_id'] as num).toInt();
        await store.setSetting('auto_save_goal_id', _autoSaveGoalId.toString());
      }
      if (auto['merchant_category_memory'] is Map) {
        _learnedMerchantCategories = <String, String>{
          for (final e in (auto['merchant_category_memory'] as Map).entries)
            if (e.key is String && e.value is String)
              e.key as String: e.value as String,
        };
        await _persistLearnedMerchants();
      }
      if (auto['auto_pay_bill_ids'] is List) {
        _autoPayBillIds = (auto['auto_pay_bill_ids'] as List)
            .whereType<num>()
            .map((e) => e.toInt())
            .toSet();
        await store.setSetting(
          'auto_pay_bill_ids',
          _autoPayBillIds.map((e) => e.toString()).join(','),
        );
      }
      if (auto['recurring_incomes'] is List) {
        _recurringIncomes = (auto['recurring_incomes'] as List)
            .whereType<Map>()
            .map(
              (m) =>
                  RecurringIncomeModel.fromJson(Map<String, Object?>.from(m)),
            )
            .toList();
        await _persistRecurringIncomes();
      }
    }

    await _reloadData();
    notifyListeners();
  }

  Future<void> toggleThemeMode() async {
    final next = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(next);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final store = _store;
    if (store != null) {
      await store.setSetting(
        'theme_mode',
        mode == ThemeMode.dark ? 'dark' : 'light',
      );
    }
  }

  Future<void> toggleHideBalance() async {
    _hideBalance = !_hideBalance;
    notifyListeners();
    final store = _store;
    if (store != null) {
      await store.setSetting('hide_balance', _hideBalance ? '1' : '0');
    }
    unawaited(_syncHomeWidgetAndReminders());
  }

  Future<void> setMonthlyBudget(int amount) async {
    final store = _store;
    if (store == null) {
      return;
    }
    final sanitized = amount < 0 ? 0 : amount;
    await store.setGlobalMonthlyBudget(sanitized);
    _monthlyBudget = sanitized;
    notifyListeners();
  }

  Future<void> upsertCategoryBudget({
    required String category,
    required int monthlyLimit,
  }) async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.upsertCategoryBudget(category, monthlyLimit);
    await _reloadData();
    notifyListeners();
  }

  Future<void> deleteCategoryBudget(int id) async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.deleteCategoryBudget(id);
    await _reloadData();
    notifyListeners();
  }

  Future<void> addGoal({
    required String name,
    required int targetAmount,
    int initialSaved = 0,
    DateTime? deadline,
    int colorValue = 0xFF0F766E,
    String iconKey = 'savings',
  }) async {
    final store = _store;
    if (store == null) {
      return;
    }
    final goal = GoalModel(
      name: name.trim(),
      targetAmount: targetAmount,
      currentAmount: initialSaved,
      deadline: deadline,
      colorValue: colorValue,
      iconKey: iconKey,
      isCompleted: initialSaved >= targetAmount,
      createdAt: now,
    );
    await store.addGoal(goal);
    await _reloadData();
    notifyListeners();
  }

  Future<void> updateGoal(GoalModel goal) async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.updateGoal(
      goal.copyWith(isCompleted: goal.currentAmount >= goal.targetAmount),
    );
    await _reloadData();
    notifyListeners();
  }

  Future<void> deleteGoal(int id) async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.deleteGoal(id);
    await _reloadData();
    notifyListeners();
  }

  Future<void> contributeToGoal({
    required int goalId,
    required int amount,
    required int walletId,
  }) async {
    final store = _store;
    if (store == null || amount <= 0) {
      return;
    }
    await store.addGoalContribution(
      goalId: goalId,
      amount: amount,
      walletId: walletId,
      timestamp: now,
    );
    await _reloadData();
    notifyListeners();
  }

  Future<void> addBill({
    required String name,
    required int amount,
    required String category,
    required int dueDay,
    int? walletId,
  }) async {
    final store = _store;
    if (store == null) {
      return;
    }
    final bill = BillModel(
      name: name.trim(),
      amount: amount,
      category: category,
      dueDay: dueDay.clamp(1, 31),
      walletId: walletId,
      createdAt: now,
    );
    await store.addBill(bill);
    await _reloadData();
    notifyListeners();
  }

  Future<void> updateBill(BillModel bill) async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.updateBill(bill.copyWith(dueDay: bill.dueDay.clamp(1, 31)));
    await _reloadData();
    notifyListeners();
  }

  Future<void> deleteBill(int id) async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.deleteBill(id);
    await _reloadData();
    notifyListeners();
  }

  Future<void> payBillNow({
    required int billId,
    required int walletId,
  }) async {
    final store = _store;
    if (store == null) {
      return;
    }
    final current = now;
    await store.payBill(
      billId: billId,
      walletId: walletId,
      monthKey: BillModel.monthKeyFor(current),
      timestamp: current,
    );
    await _reloadData();
    notifyListeners();
  }

  Future<void> markBillUnpaid(int billId) async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.markBillUnpaid(billId);
    await _reloadData();
    notifyListeners();
  }

  Future<void> addDebt({
    required String personName,
    required String phone,
    required DebtKind kind,
    required int principalAmount,
    DateTime? dueDate,
    String note = '',
  }) async {
    final store = _store;
    if (store == null) {
      return;
    }
    final debt = DebtModel(
      personName: personName.trim(),
      phone: phone.trim(),
      type: kind.code,
      principalAmount: principalAmount,
      remainingAmount: principalAmount,
      dueDate: dueDate,
      note: note.trim(),
      status: 'open',
      createdAt: now,
    );
    await store.addDebt(debt);
    await _reloadData();
    notifyListeners();
  }

  Future<void> updateDebt(DebtModel debt) async {
    final store = _store;
    if (store == null) {
      return;
    }
    final adjustedRemaining = debt.remainingAmount > debt.principalAmount
        ? debt.principalAmount
        : debt.remainingAmount;
    await store.updateDebt(
      debt.copyWith(
        remainingAmount: adjustedRemaining,
        status: adjustedRemaining <= 0 ? 'paid' : 'open',
      ),
    );
    await _reloadData();
    notifyListeners();
  }

  Future<void> deleteDebt(int id) async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.deleteDebt(id);
    await _reloadData();
    notifyListeners();
  }

  Future<void> recordDebtInstallment({
    required int debtId,
    required int payAmount,
    int? walletId,
  }) async {
    final store = _store;
    if (store == null || payAmount <= 0) {
      return;
    }
    await store.recordDebtInstallment(
      debtId: debtId,
      payAmount: payAmount,
      walletId: walletId,
      timestamp: now,
    );
    await _reloadData();
    notifyListeners();
  }

  Future<void> addTransaction(TransactionModel tx) async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.addTransaction(tx);
    await _learnFromTransaction(tx);
    await _applyAutoGoalAllocationIfEligible(tx);
    await _reloadData();
    if (tx.kind == TransactionKind.expense) {
      unawaited(_evaluateBudgetAlertsAfterExpense(tx.category));
    }
    notifyListeners();
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.updateTransaction(tx);
    await _learnFromTransaction(tx);
    await _reloadData();
    notifyListeners();
  }

  Future<void> deleteTransaction(int id) async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.deleteTransaction(id);
    await _reloadData();
    notifyListeners();
  }

  Future<void> addWallet({
    required String name,
    required WalletKind kind,
    required int initialBalance,
    required int colorValue,
    required String iconKey,
    bool excludeFromTotal = false,
  }) async {
    final store = _store;
    if (store == null) {
      return;
    }
    final wallet = WalletModel(
      name: name.trim(),
      kind: kind,
      balance: initialBalance,
      colorValue: colorValue,
      iconKey: iconKey,
      excludeFromTotal: excludeFromTotal,
      sortOrder: _wallets.length,
      createdAt: now,
    );
    await store.addWallet(wallet);
    await _reloadData();
    notifyListeners();
  }

  Future<void> updateWallet(WalletModel wallet) async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.updateWallet(wallet);
    await _reloadData();
    notifyListeners();
  }

  Future<void> deleteWallet(int id) async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.deleteWallet(id);
    await _reloadData();
    notifyListeners();
  }

  Future<void> _loadAutomationSettings(SakuStore store) async {
    _smartAlertsEnabled =
        (await store.getSetting('smart_alerts_enabled')) != '0';
    _autoBackupEnabled =
        (await store.getSetting('auto_backup_enabled')) != '0';
    _autoSaveGoalEnabled =
        (await store.getSetting('auto_save_goal_enabled')) == '1';
    _autoSaveGoalPercent =
        (int.tryParse(
                  (await store.getSetting('auto_save_goal_percent')) ?? '20',
                ) ??
                20)
            .clamp(5, 50);
    _autoSaveGoalId = int.tryParse(
      (await store.getSetting('auto_save_goal_id')) ?? '',
    );
    _lastAutoBackupDate =
        (await store.getSetting('last_auto_backup_date')) ?? '';
    _lastAutoBackupPath =
        (await store.getSetting('last_auto_backup_path')) ?? '';
    _lastClosedMonthKey =
        (await store.getSetting('last_closed_month_key')) ?? '';
    _lastClosedExcelPath =
        (await store.getSetting('last_closed_excel_path')) ?? '';
    _dismissedRecapMonthKey =
        (await store.getSetting('dismissed_recap_month_key')) ?? '';

    final rawMemory = await store.getSetting('merchant_category_memory');
    if (rawMemory != null && rawMemory.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMemory);
        if (decoded is Map) {
          _learnedMerchantCategories = <String, String>{
            for (final entry in decoded.entries)
              if (entry.key is String && entry.value is String)
                entry.key as String: entry.value as String,
          };
        }
      } catch (_) {
        _learnedMerchantCategories = <String, String>{};
      }
    }

    final rawAutoBills = await store.getSetting('auto_pay_bill_ids');
    if (rawAutoBills != null && rawAutoBills.isNotEmpty) {
      _autoPayBillIds = rawAutoBills
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toSet();
    }

    final rawRecurring = await store.getSetting('recurring_incomes_json');
    if (rawRecurring != null && rawRecurring.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawRecurring);
        if (decoded is List) {
          _recurringIncomes = decoded
              .whereType<Map>()
              .map(
                (m) => RecurringIncomeModel.fromJson(
                  Map<String, Object?>.from(m),
                ),
              )
              .toList();
        }
      } catch (_) {
        _recurringIncomes = <RecurringIncomeModel>[];
      }
    }
  }

  Future<void> _bootstrapNativeAutomations() async {
    await refreshPostNotificationPermission();
    await _syncHomeWidgetAndReminders();
    unawaited(runMonthlyClosingArchiveIfNeeded());
    unawaited(runAutoBackupIfDue());
  }

  Future<bool> refreshPostNotificationPermission({bool notify = true}) async {
    if (_customStore != null) {
      return _postNotificationGranted;
    }
    final granted = await AutomationBridgeService.hasPostNotificationPermission();
    _postNotificationGranted = granted;
    if (notify) {
      notifyListeners();
    }
    return granted;
  }

  Future<bool> requestPostNotificationPermission() async {
    if (_customStore != null) {
      return _postNotificationGranted;
    }
    final granted =
        await AutomationBridgeService.requestPostNotificationPermission();
    _postNotificationGranted = granted;
    notifyListeners();
    return granted;
  }

  Future<void> setSmartAlertsEnabled(bool enabled) async {
    _smartAlertsEnabled = enabled;
    await _store?.setSetting('smart_alerts_enabled', enabled ? '1' : '0');
    unawaited(_syncHomeWidgetAndReminders());
    notifyListeners();
  }

  static String _normalizeMerchantKey(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? lookupLearnedCategory(String text) {
    final key = _normalizeMerchantKey(text);
    if (key.length < 3 || _learnedMerchantCategories.isEmpty) {
      return null;
    }
    final exact = _learnedMerchantCategories[key];
    if (exact != null) {
      return exact;
    }
    for (final entry in _learnedMerchantCategories.entries) {
      if (entry.key.length >= 4 &&
          (key.contains(entry.key) || entry.key.contains(key))) {
        return entry.value;
      }
    }
    return null;
  }

  Future<void> _learnFromTransaction(TransactionModel tx) async {
    if (tx.kind == TransactionKind.transfer ||
        tx.note.trim().isEmpty ||
        tx.category == 'Lainnya' ||
        tx.category == 'Pemasukan Lain') {
      return;
    }
    final key = _normalizeMerchantKey(tx.note);
    if (key.length < 3) {
      return;
    }
    if (_learnedMerchantCategories[key] == tx.category) {
      return;
    }
    _learnedMerchantCategories = <String, String>{
      ..._learnedMerchantCategories,
      key: tx.category,
    };
    await _persistLearnedMerchants();
  }

  Future<void> removeLearnedMerchant(String key) async {
    final next = Map<String, String>.from(_learnedMerchantCategories);
    next.remove(key);
    _learnedMerchantCategories = next;
    await _persistLearnedMerchants();
    notifyListeners();
  }

  Future<void> clearLearnedMerchants() async {
    _learnedMerchantCategories = <String, String>{};
    await _persistLearnedMerchants();
    notifyListeners();
  }

  Future<void> _persistLearnedMerchants() async {
    await _store?.setSetting(
      'merchant_category_memory',
      jsonEncode(_learnedMerchantCategories),
    );
  }

  bool isBillAutoPayEnabled(int? billId) =>
      billId != null && _autoPayBillIds.contains(billId);

  Future<void> setBillAutoPay(int billId, bool enabled) async {
    final next = Set<int>.from(_autoPayBillIds);
    if (enabled) {
      next.add(billId);
    } else {
      next.remove(billId);
    }
    _autoPayBillIds = next;
    await _store?.setSetting(
      'auto_pay_bill_ids',
      next.map((e) => e.toString()).join(','),
    );
    if (enabled) {
      await runRecurringAutomations(notify: false);
    }
    notifyListeners();
  }

  Future<void> addRecurringIncome({
    required String name,
    required int amount,
    required int dayOfMonth,
    required int walletId,
    String category = 'Gaji',
  }) async {
    final item = RecurringIncomeModel(
      id: 'inc_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      amount: amount,
      dayOfMonth: dayOfMonth.clamp(1, 28),
      walletId: walletId,
      category: category,
    );
    _recurringIncomes = <RecurringIncomeModel>[..._recurringIncomes, item];
    await _persistRecurringIncomes();
    await runRecurringAutomations(notify: false);
    notifyListeners();
  }

  Future<void> toggleRecurringIncome(String id, bool enabled) async {
    _recurringIncomes = _recurringIncomes
        .map((e) => e.id == id ? e.copyWith(enabled: enabled) : e)
        .toList();
    await _persistRecurringIncomes();
    if (enabled) {
      await runRecurringAutomations(notify: false);
    }
    notifyListeners();
  }

  Future<void> deleteRecurringIncome(String id) async {
    _recurringIncomes = _recurringIncomes.where((e) => e.id != id).toList();
    await _persistRecurringIncomes();
    notifyListeners();
  }

  Future<void> _persistRecurringIncomes() async {
    await _store?.setSetting(
      'recurring_incomes_json',
      jsonEncode(_recurringIncomes.map((e) => e.toJson()).toList()),
    );
  }

  Future<AutomationRunSummary> runRecurringAutomations({
    bool notify = true,
  }) async {
    final store = _store;
    if (store == null || _wallets.isEmpty) {
      return const AutomationRunSummary();
    }

    final current = now;
    final currentMonthKey = RecurringIncomeModel.monthKeyFor(current);
    var credited = 0;
    var paidBills = 0;
    var updatedIncomes = false;

    final nextIncomes = <RecurringIncomeModel>[];
    for (final inc in _recurringIncomes) {
      if (inc.enabled &&
          inc.amount > 0 &&
          current.day >= inc.dayOfMonth &&
          !inc.isCreditedFor(current)) {
        final targetWallet = walletById(inc.walletId) ?? _wallets.first;
        if (targetWallet.id != null) {
          final autoIncomeTx = TransactionModel(
            kind: TransactionKind.income,
            amount: inc.amount,
            category: inc.category,
            note: '${inc.name} (Auto-Rutin)',
            walletId: targetWallet.id!,
            transactionDate: current,
            createdAt: current,
          );
          await store.addTransaction(autoIncomeTx);
          await _applyAutoGoalAllocationIfEligible(autoIncomeTx);
          credited++;
          updatedIncomes = true;
          nextIncomes.add(inc.copyWith(lastCreditedMonth: currentMonthKey));
          continue;
        }
      }
      nextIncomes.add(inc);
    }
    if (updatedIncomes) {
      _recurringIncomes = nextIncomes;
      await _persistRecurringIncomes();
    }

    for (final bill in List<BillModel>.from(_bills)) {
      final billId = bill.id;
      if (billId != null &&
          _autoPayBillIds.contains(billId) &&
          !bill.isPaidFor(current) &&
          current.day >= bill.dueDay) {
        final targetWallet = walletById(bill.walletId) ?? _wallets.first;
        if (targetWallet.id != null) {
          await store.payBill(
            billId: billId,
            walletId: targetWallet.id!,
            monthKey: BillModel.monthKeyFor(current),
            timestamp: current,
          );
          paidBills++;
        }
      }
    }

    if (credited > 0 || paidBills > 0) {
      await _reloadData();
      if (notify) {
        notifyListeners();
      }
    }

    var dueSoonCount = 0;
    for (final bill in _bills) {
      if (!bill.isPaidFor(current) &&
          bill.dueDay >= current.day &&
          bill.dueDay <= current.day + 2) {
        dueSoonCount++;
      }
    }

    return AutomationRunSummary(
      autoCreditedIncomes: credited,
      autoPaidBills: paidBills,
      dueBillReminders: dueSoonCount,
    );
  }

  Future<void> _evaluateBudgetAlertsAfterExpense(String category) async {
    if (_customStore != null || !_smartAlertsEnabled) {
      return;
    }
    final dayStamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    for (final b in _categoryBudgets) {
      if (b.category.toLowerCase() == category.toLowerCase() &&
          b.monthlyLimit > 0) {
        final spent = spentForCategory(b.category);
        final ratio = spent / b.monthlyLimit;
        if (ratio >= b.alertThreshold) {
          final key = '$dayStamp:cat:${b.category}:${ratio >= 1.0 ? 'over' : 'warn'}';
          if (_sentAlertKeysToday.add(key)) {
            final pct = (ratio * 100).round();
            final title = ratio >= 1.0
                ? 'Budget ${b.category} Terlampaui!'
                : 'Budget ${b.category} Hampir Penuh ($pct%)';
            final body =
                'Terpakai ${IdrFormat.currency(spent)} dari batas ${IdrFormat.currency(b.monthlyLimit)}.';
            await AutomationBridgeService.showLocalNotification(
              id: 5200 + (b.id ?? 1),
              channel: 'sakupro_budget_alerts',
              title: title,
              body: body,
            );
          }
        }
      }
    }

    final safe = safeToSpend;
    if (safe.monthlyBudget > 0 && safe.level != SafeSpendLevel.safe) {
      final key = '$dayStamp:global:${safe.level.name}';
      if (_sentAlertKeysToday.add(key)) {
        final title = safe.level == SafeSpendLevel.overbudget
            ? 'Budget Bulanan Overbudget'
            : 'Peringatan Aman Jajan Hari Ini';
        final body = safe.level == SafeSpendLevel.overbudget
            ? 'Pengeluaran bulan ini sudah melewati batas ${IdrFormat.currency(safe.monthlyBudget)}.'
            : 'Sisa batas harian tinggal ${IdrFormat.currency(safe.dailySafeAmount)} / hari (${safe.remainingDays} hari lagi).';
        await AutomationBridgeService.showLocalNotification(
          id: 5299,
          channel: 'sakupro_budget_alerts',
          title: title,
          body: body,
        );
      }
    }
  }

  Future<bool> sendTestSmartAlertNotification() async {
    final safe = safeToSpend;
    return AutomationBridgeService.showLocalNotification(
      id: 5300,
      channel: 'sakupro_reminders',
      title: 'Ringkasan SakuProWann',
      body:
          'Aman jajan hari ini ${IdrFormat.currency(safe.dailySafeAmount)} · Total keluar bulan ini ${IdrFormat.currency(monthlyExpense)}.',
    );
  }

  Future<void> _syncHomeWidgetAndReminders() async {
    if (_customStore != null) {
      return;
    }
    final safe = safeToSpend;
    final safeDailyText = _hideBalance
        ? 'Rp •••••• / hari'
        : '${IdrFormat.currency(safe.dailySafeAmount)} / hari';
    final netWorthText =
        'Saldo Bersih: ${IdrFormat.currency(netWorth, hidden: _hideBalance)}';
    await AutomationBridgeService.syncWidgetData(
      safeDailyText: safeDailyText,
      netWorthText: netWorthText,
      statusLabel: safe.level.label,
    );

    final current = now;
    final billsPayload = jsonEncode(
      _bills
          .map(
            (b) => <String, Object?>{
              'name': b.name,
              'dueDay': b.dueDay,
              'paid': b.isPaidFor(current),
            },
          )
          .toList(),
    );
    final weeklySummary =
        'Bulan ini terpakai ${IdrFormat.currency(monthlyExpense)}, sisa aman jajan ${IdrFormat.currency(safe.dailySafeAmount)}/hari.';
    await AutomationBridgeService.syncReminderSchedule(
      enabled: _smartAlertsEnabled,
      billsJson: billsPayload,
      weeklySummary: weeklySummary,
    );
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    _autoBackupEnabled = enabled;
    await _store?.setSetting('auto_backup_enabled', enabled ? '1' : '0');
    if (enabled) {
      unawaited(runAutoBackupIfDue());
    }
    notifyListeners();
  }

  Future<void> configureAutoSaveGoal({
    required bool enabled,
    int? percent,
    int? goalId,
  }) async {
    _autoSaveGoalEnabled = enabled;
    if (percent != null) {
      _autoSaveGoalPercent = percent.clamp(5, 50);
    }
    if (goalId != null) {
      _autoSaveGoalId = goalId;
    } else if (_autoSaveGoalId == null && _goals.isNotEmpty) {
      _autoSaveGoalId = _goals.first.id;
    }
    await _store?.setSetting('auto_save_goal_enabled', enabled ? '1' : '0');
    await _store?.setSetting(
      'auto_save_goal_percent',
      _autoSaveGoalPercent.toString(),
    );
    if (_autoSaveGoalId != null) {
      await _store?.setSetting('auto_save_goal_id', _autoSaveGoalId.toString());
    }
    notifyListeners();
  }

  GoalModel? get selectedAutoSaveGoal {
    if (_goals.isEmpty) {
      return null;
    }
    if (_autoSaveGoalId != null) {
      for (final g in _goals) {
        if (g.id == _autoSaveGoalId) {
          return g;
        }
      }
    }
    for (final g in _goals) {
      if (!g.reachedTarget) {
        return g;
      }
    }
    return _goals.first;
  }

  Future<void> _applyAutoGoalAllocationIfEligible(TransactionModel tx) async {
    final store = _store;
    if (store == null || !_autoSaveGoalEnabled || tx.kind != TransactionKind.income) {
      return;
    }
    final eligibleCategory =
        tx.category == 'Gaji' || tx.category == 'Bonus & THR';
    if (!eligibleCategory || tx.amount <= 0) {
      return;
    }
    final goal = selectedAutoSaveGoal;
    if (goal == null || goal.id == null || goal.reachedTarget) {
      return;
    }
    final rawAlloc = (tx.amount * _autoSaveGoalPercent / 100).round();
    final alloc = rawAlloc.clamp(0, goal.remainingAmount);
    if (alloc <= 0) {
      return;
    }
    final nextSaved = goal.currentAmount + alloc;
    await store.updateGoal(
      goal.copyWith(
        currentAmount: nextSaved,
        isCompleted: nextSaved >= goal.targetAmount,
      ),
    );
  }

  MonthlyClosingRecap? get activeMonthlyRecap {
    final prevMonth = DateTime(now.year, now.month - 1);
    final prevKey = BillModel.monthKeyFor(prevMonth);
    if (_dismissedRecapMonthKey == prevKey) {
      return null;
    }
    final prevTx = transactionsForMonth(prevMonth);
    if (prevTx.isEmpty) {
      return null;
    }
    final report = buildMonthlyReport(prevMonth);
    final topCat = report.categorySlices.isNotEmpty
        ? report.categorySlices.first.category
        : '-';
    return MonthlyClosingRecap(
      monthKey: prevKey,
      month: prevMonth,
      income: report.totalIncome,
      expense: report.totalExpense,
      surplus: report.totalIncome - report.totalExpense,
      savingsRatePercent: report.savingsRatePercent,
      topCategory: topCat,
      transactionCount: prevTx.length,
      savedExcelPath: _lastClosedMonthKey == prevKey ? _lastClosedExcelPath : '',
    );
  }

  Future<void> dismissMonthlyRecap() async {
    final prevMonth = DateTime(now.year, now.month - 1);
    final prevKey = BillModel.monthKeyFor(prevMonth);
    _dismissedRecapMonthKey = prevKey;
    await _store?.setSetting('dismissed_recap_month_key', prevKey);
    notifyListeners();
  }

  Future<bool> allocateMonthlySurplusToGoal(int goalId) async {
    final recap = activeMonthlyRecap;
    final store = _store;
    if (recap == null || recap.surplus <= 0 || store == null) {
      return false;
    }
    GoalModel? target;
    for (final g in _goals) {
      if (g.id == goalId) {
        target = g;
        break;
      }
    }
    if (target == null || target.id == null) {
      return false;
    }
    final nextAmount = target.currentAmount + recap.surplus;
    await store.updateGoal(
      target.copyWith(
        currentAmount: nextAmount,
        isCompleted: nextAmount >= target.targetAmount,
      ),
    );
    await dismissMonthlyRecap();
    await _reloadData();
    notifyListeners();
    return true;
  }

  Future<String?> runMonthlyClosingArchiveIfNeeded({bool force = false}) async {
    final prevMonth = DateTime(now.year, now.month - 1);
    final prevKey = BillModel.monthKeyFor(prevMonth);
    if (!force && _lastClosedMonthKey == prevKey) {
      return null;
    }
    final prevTx = transactionsForMonth(prevMonth);
    if (prevTx.isEmpty) {
      return null;
    }

    final report = buildMonthlyReport(prevMonth);
    final bytes = ExportBackupService.buildMonthlyExcelBytes(
      month: report.month,
      monthTransactions: report.transactions,
      wallets: _wallets,
      netWorth: netWorth,
      monthlyBudget: _monthlyBudget,
      categoryBudgets: _categoryBudgets,
      goals: _goals,
      bills: _bills,
      debts: _debts,
      previousMonthExpense: report.previousMonthExpense,
      insights: report.insights,
    );

    final ym = '${prevMonth.year}${prevMonth.month.toString().padLeft(2, '0')}';
    final fileName = 'SakuProWann_Laporan_$ym.xlsx';
    String? savedPath;
    if (_customStore == null) {
      savedPath = await AutomationBridgeService.saveFileToDownloads(
        fileName: fileName,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        bytes: bytes,
      );
    }

    _lastClosedMonthKey = prevKey;
    _lastClosedExcelPath = savedPath ?? fileName;
    await _store?.setSetting('last_closed_month_key', _lastClosedMonthKey);
    await _store?.setSetting('last_closed_excel_path', _lastClosedExcelPath);
    notifyListeners();
    return _lastClosedExcelPath;
  }

  Future<String?> runAutoBackupIfDue({bool force = false}) async {
    if (!force && (!_autoBackupEnabled || _transactions.isEmpty)) {
      return null;
    }
    final current = now;
    if (!force && _lastAutoBackupDate.isNotEmpty) {
      final prev = DateTime.tryParse(_lastAutoBackupDate);
      if (prev != null && current.difference(prev).inDays < 7) {
        return null;
      }
    }

    final snapshot = await createBackupSnapshot();
    final jsonString = ExportBackupService.encodeBackupJson(snapshot);
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final stamp =
        '${current.year}${current.month.toString().padLeft(2, '0')}${current.day.toString().padLeft(2, '0')}';
    final fileName = 'SakuProWann_AutoBackup_$stamp.json';

    String? savedPath;
    if (_customStore == null) {
      savedPath = await AutomationBridgeService.saveFileToDownloads(
        fileName: fileName,
        mimeType: 'application/json',
        bytes: bytes,
        prunePrefix: 'SakuProWann_AutoBackup_',
        maxRetained: 5,
      );
    }

    _lastAutoBackupDate = current.toIso8601String();
    _lastAutoBackupPath = savedPath ?? 'Download/SakuProWann/$fileName';
    await _store?.setSetting('last_auto_backup_date', _lastAutoBackupDate);
    await _store?.setSetting('last_auto_backup_path', _lastAutoBackupPath);
    notifyListeners();
    return _lastAutoBackupPath;
  }

  static const List<String> _trendShortMonths = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const List<(String, String)> _weekdayLabels = <(String, String)>[
    ('Sen', 'Senin'),
    ('Sel', 'Selasa'),
    ('Rab', 'Rabu'),
    ('Kam', 'Kamis'),
    ('Jum', 'Jumat'),
    ('Sab', 'Sabtu'),
    ('Min', 'Minggu'),
  ];

  String _preferredQuickWalletSlug() {
    if (_wallets.isEmpty) {
      return '';
    }
    for (final w in _wallets) {
      final lower = w.name.toLowerCase();
      if (lower.contains('gopay') || lower.contains('dana')) {
        return lower;
      }
    }
    return _wallets.first.name.toLowerCase();
  }

  List<QuickHabitPreset> get smartQuickPresets {
    final cutoff = now.subtract(const Duration(days: 30));
    final grouped = <String, _HabitAccumulator>{};

    for (final tx in _transactions) {
      if (tx.kind != TransactionKind.expense ||
          tx.amount <= 0 ||
          tx.transactionDate.isBefore(cutoff)) {
        continue;
      }
      final title = tx.displayTitle.trim();
      final key = _normalizeMerchantKey(title);
      if (key.length < 2) {
        continue;
      }
      final walletName = walletById(tx.walletId)?.name ?? '';
      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = _HabitAccumulator(
          title: title,
          amount: tx.amount,
          walletName: walletName,
          count: 1,
          latest: tx.transactionDate,
        );
      } else {
        existing.count += 1;
        if (tx.transactionDate.isAfter(existing.latest)) {
          existing.latest = tx.transactionDate;
          existing.amount = tx.amount;
          existing.walletName = walletName;
        }
      }
    }

    final ranked = grouped.values.toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) {
          return byCount;
        }
        return b.latest.compareTo(a.latest);
      });

    final results = <QuickHabitPreset>[];
    final seenLabels = <String>{};

    for (final item in ranked.take(4)) {
      final compactAmt = _formatPresetAmount(item.amount);
      final shortTitle = item.title.length > 14
          ? '${item.title.substring(0, 14).trim()}...'
          : item.title;
      final label = '$shortTitle $compactAmt';
      final walletPart = item.walletName.trim().toLowerCase();
      final phrase = walletPart.isEmpty
          ? '${item.title} ${item.amount}'
          : '${item.title} ${item.amount} $walletPart';
      if (seenLabels.add(label.toLowerCase())) {
        results.add(
          QuickHabitPreset(label: label, phrase: phrase, isLearned: true),
        );
      }
    }

    final fallbackSlug = _preferredQuickWalletSlug();
    const defaults = <(String, String)>[
      ('Ngopi 25rb', 'kopi 25rb'),
      ('Makan 35rb', 'makan 35rb'),
      ('Ojek 15rb', 'ojek 15rb'),
      ('Jajan 20rb', 'jajan 20rb'),
    ];
    for (final item in defaults) {
      if (results.length >= 4) {
        break;
      }
      if (seenLabels.add(item.$1.toLowerCase())) {
        final phrase = fallbackSlug.isEmpty
            ? item.$2
            : '${item.$2} $fallbackSlug';
        results.add(
          QuickHabitPreset(label: item.$1, phrase: phrase, isLearned: false),
        );
      }
    }

    return results;
  }

  static String _formatPresetAmount(int amount) {
    if (amount >= 1000000) {
      final jt = amount / 1000000;
      return '${jt == jt.roundToDouble() ? jt.toInt() : jt.toStringAsFixed(1)}jt';
    }
    if (amount >= 1000) {
      final rb = amount / 1000;
      return '${rb == rb.roundToDouble() ? rb.toInt() : rb.toStringAsFixed(1)}rb';
    }
    return '$amount';
  }

  List<MonthlyTrendPoint> buildSixMonthTrend(DateTime anchorMonth) {
    final points = <MonthlyTrendPoint>[];
    for (var offset = 5; offset >= 0; offset--) {
      final m = DateTime(anchorMonth.year, anchorMonth.month - offset);
      final monthTx = transactionsForMonth(m);
      var income = 0;
      var expense = 0;
      for (final tx in monthTx) {
        if (tx.kind == TransactionKind.income) {
          income += tx.amount;
        } else if (tx.kind == TransactionKind.expense) {
          expense += tx.amount;
        }
      }
      points.add(
        MonthlyTrendPoint(
          month: m,
          shortLabel: _trendShortMonths[(m.month - 1).clamp(0, 11)],
          income: income,
          expense: expense,
        ),
      );
    }
    return points;
  }

  WeekdaySpendPattern buildWeekdaySpendPattern(DateTime targetMonth) {
    final totals = List<int>.filled(7, 0);
    final counts = List<int>.filled(7, 0);
    var totalExpense = 0;

    for (final tx in transactionsForMonth(targetMonth)) {
      if (tx.kind != TransactionKind.expense) {
        continue;
      }
      final idx = (tx.transactionDate.weekday - 1).clamp(0, 6);
      totals[idx] += tx.amount;
      counts[idx] += 1;
      totalExpense += tx.amount;
    }

    final buckets = List<WeekdaySpendBucket>.generate(7, (i) {
      return WeekdaySpendBucket(
        weekday: i + 1,
        shortLabel: _weekdayLabels[i].$1,
        fullLabel: _weekdayLabels[i].$2,
        amount: totals[i],
        count: counts[i],
      );
    });

    WeekdaySpendBucket? peak;
    for (final b in buckets) {
      if (b.amount > 0 && (peak == null || b.amount > peak.amount)) {
        peak = b;
      }
    }

    return WeekdaySpendPattern(
      buckets: buckets,
      peakBucket: peak,
      totalExpense: totalExpense,
    );
  }

  Future<int> recordSplitBill({
    required String title,
    required int walletId,
    required String category,
    required int myShare,
    required List<SplitBillFriend> friends,
  }) async {
    final store = _store;
    if (store == null) {
      return 0;
    }

    final cleanTitle = title.trim().isEmpty ? 'Patungan' : title.trim();
    final timestamp = now;

    if (myShare > 0) {
      final tx = TransactionModel(
        kind: TransactionKind.expense,
        amount: myShare,
        category: category,
        note: 'Patungan: $cleanTitle',
        walletId: walletId,
        transactionDate: timestamp,
        createdAt: timestamp,
      );
      await store.addTransaction(tx);
      await _learnFromTransaction(tx);
    }

    var createdDebts = 0;
    for (final friend in friends) {
      final name = friend.name.trim();
      if (name.isEmpty || friend.shareAmount <= 0) {
        continue;
      }
      await store.addDebt(
        DebtModel(
          personName: name,
          phone: friend.phone.trim(),
          type: DebtKind.receivable.code,
          principalAmount: friend.shareAmount,
          remainingAmount: friend.shareAmount,
          note: 'Patungan: $cleanTitle',
          status: 'open',
          createdAt: timestamp,
        ),
      );
      createdDebts++;
    }

    await _reloadData();
    if (myShare > 0) {
      unawaited(_evaluateBudgetAlertsAfterExpense(category));
    }
    notifyListeners();
    return createdDebts;
  }
}

class _HabitAccumulator {
  _HabitAccumulator({
    required this.title,
    required this.amount,
    required this.walletName,
    required this.count,
    required this.latest,
  });

  final String title;
  int amount;
  String walletName;
  int count;
  DateTime latest;
}

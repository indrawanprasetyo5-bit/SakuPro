import 'package:material_ui/material_ui.dart';

import '../db/database_helper.dart';
import '../models/category_meta.dart';
import '../models/roadmap_models.dart';
import '../models/transaction_item.dart';
import '../models/wallet.dart';
import '../theme/currency_format.dart';
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

class FinanceController extends ChangeNotifier {
  FinanceController({this._customStore, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SakuStore? _customStore;
  final DateTime Function() _clock;

  SakuStore? _store;
  bool _isLoading = true;
  String? _errorMessage;

  ThemeMode _themeMode = ThemeMode.light;
  bool _hideBalance = false;
  bool _appLockEnabled = false;
  bool _biometricEnabled = false;
  String _pinCode = '';
  bool _isSessionLocked = false;

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
      insights.add('Belum ada pemasukan atau pengeluaran pada periode ini.');
    } else {
      if (slices.isNotEmpty) {
        final top = slices.first;
        final topPct = (top.share * 100).round();
        insights.add(
          'Pengeluaran terbesar ada pada kategori ${top.category} sebesar ${IdrFormat.currency(top.amount, hidden: _hideBalance)} ($topPct% dari total belanja).',
        );
      }

      if (deltaPct != null) {
        final diffAbs = (expense - prevExpense).abs();
        final rounded = deltaPct.abs().round();
        if (expense < prevExpense) {
          insights.add(
            'Pengeluaran turun $rounded% dibanding bulan sebelumnya (lebih hemat ${IdrFormat.currency(diffAbs, hidden: _hideBalance)}).',
          );
        } else if (expense > prevExpense) {
          insights.add(
            'Pengeluaran naik $rounded% dibanding bulan sebelumnya (bertambah ${IdrFormat.currency(diffAbs, hidden: _hideBalance)}).',
          );
        } else {
          insights.add(
            'Total pengeluaran sama persis dengan bulan sebelumnya.',
          );
        }
      } else if (expense > 0) {
        insights.add(
          'Belum ada data pengeluaran bulan sebelumnya sebagai pembanding tren.',
        );
      }

      if (savingsPct != null) {
        final net = income - expense;
        final pctRounded = savingsPct.round();
        if (net >= 0) {
          insights.add(
            'Rasio tabungan periode ini mencapai $pctRounded% (surplus ${IdrFormat.currency(net, hidden: _hideBalance)}).',
          );
        } else {
          insights.add(
            'Pengeluaran melampaui pemasukan sebesar ${IdrFormat.currency(net.abs(), hidden: _hideBalance)} ($pctRounded%).',
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

      await _reloadData();
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
    return store.exportSnapshot();
  }

  Future<void> restoreFromBackupJson(String rawJson) async {
    final store = _store;
    if (store == null) {
      throw const StorageException('Penyimpanan belum siap.');
    }
    final validated = ExportBackupService.decodeAndValidateBackupJson(rawJson);
    await store.restoreSnapshot(validated);
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
    await _reloadData();
    notifyListeners();
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.updateTransaction(tx);
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
}

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
import 'bank_notification_parser.dart';
import 'export_backup_service.dart';
import 'notification_bridge_service.dart';

enum AutoCaptureMode {
  autoSave('auto', 'Langsung Catat'),
  inbox('inbox', 'Konfirmasi Dulu');

  const AutoCaptureMode(this.code, this.label);
  final String code;
  final String label;

  static AutoCaptureMode fromCode(String? code) =>
      code == 'inbox' ? AutoCaptureMode.inbox : AutoCaptureMode.autoSave;
}

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

  ThemeMode _themeMode = ThemeMode.dark;
  bool _hideBalance = false;
  bool _appLockEnabled = false;
  bool _biometricEnabled = false;
  String _pinCode = '';
  bool _isSessionLocked = false;

  bool _autoCaptureEnabled = false;
  AutoCaptureMode _autoCaptureMode = AutoCaptureMode.autoSave;
  bool _autoPairTransfers = true;
  bool _autoReconcilePlan = true;
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
  Set<String> _enabledNotificationSourceIds = Set<String>.from(
    BankNotificationParser.defaultEnabledSourceIds,
  );
  List<ParsedBankNotification> _pendingAutoTransactions =
      <ParsedBankNotification>[];
  List<AutoCaptureLogEntry> _autoCaptureLogs = <AutoCaptureLogEntry>[];
  List<String> _processedFingerprints = <String>[];
  Map<String, String> _learnedMerchantCategories = <String, String>{};
  Set<int> _autoPayBillIds = <int>{};
  List<RecurringIncomeModel> _recurringIncomes = <RecurringIncomeModel>[];
  final Set<String> _sentAlertKeysToday = <String>{};
  bool _notificationPermissionGranted = false;
  bool _isDrainingNotifications = false;

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
  bool get autoCaptureEnabled => _autoCaptureEnabled;
  AutoCaptureMode get autoCaptureMode => _autoCaptureMode;
  bool get autoPairTransfers => _autoPairTransfers;
  bool get autoReconcilePlan => _autoReconcilePlan;
  bool get smartAlertsEnabled => _smartAlertsEnabled;
  bool get autoBackupEnabled => _autoBackupEnabled;
  bool get autoSaveGoalEnabled => _autoSaveGoalEnabled;
  int get autoSaveGoalPercent => _autoSaveGoalPercent;
  int? get autoSaveGoalId => _autoSaveGoalId;
  String get lastAutoBackupDate => _lastAutoBackupDate;
  String get lastAutoBackupPath => _lastAutoBackupPath;
  String get lastClosedExcelPath => _lastClosedExcelPath;
  bool get postNotificationGranted => _postNotificationGranted;
  Set<String> get enabledNotificationSourceIds =>
      Set<String>.unmodifiable(_enabledNotificationSourceIds);
  List<ParsedBankNotification> get pendingAutoTransactions =>
      List<ParsedBankNotification>.unmodifiable(_pendingAutoTransactions);
  List<AutoCaptureLogEntry> get autoCaptureLogs =>
      List<AutoCaptureLogEntry>.unmodifiable(_autoCaptureLogs);
  Map<String, String> get learnedMerchantCategories =>
      Map<String, String>.unmodifiable(_learnedMerchantCategories);
  Set<int> get autoPayBillIds => Set<int>.unmodifiable(_autoPayBillIds);
  List<RecurringIncomeModel> get recurringIncomes =>
      List<RecurringIncomeModel>.unmodifiable(_recurringIncomes);
  bool get notificationPermissionGranted => _notificationPermissionGranted;
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

      await _loadAutoCaptureSettings(store);
      await _reloadData();
      await runRecurringAutomations(notify: false);

      if (_customStore == null) {
        NotificationBridgeService.setOnPendingEventsAvailable(() {
          unawaited(drainNativeNotifications());
        });
        unawaited(_bootstrapNativeNotifications());
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
      'auto_capture_enabled': _autoCaptureEnabled,
      'auto_capture_mode': _autoCaptureMode.code,
      'auto_capture_sources': _enabledNotificationSourceIds.toList(),
      'auto_pair_transfers': _autoPairTransfers,
      'auto_reconcile_plan': _autoReconcilePlan,
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
      if (auto['auto_capture_enabled'] is bool) {
        _autoCaptureEnabled = auto['auto_capture_enabled'] as bool;
        await store.setSetting(
          'auto_capture_enabled',
          _autoCaptureEnabled ? '1' : '0',
        );
      }
      if (auto['auto_capture_mode'] is String) {
        _autoCaptureMode = AutoCaptureMode.fromCode(
          auto['auto_capture_mode'] as String,
        );
        await store.setSetting('auto_capture_mode', _autoCaptureMode.code);
      }
      if (auto['auto_capture_sources'] is List) {
        final sources = (auto['auto_capture_sources'] as List)
            .whereType<String>()
            .toSet();
        if (sources.isNotEmpty) {
          _enabledNotificationSourceIds = sources;
          await store.setSetting('auto_capture_sources', sources.join(','));
        }
      }
      if (auto['auto_pair_transfers'] is bool) {
        _autoPairTransfers = auto['auto_pair_transfers'] as bool;
        await store.setSetting(
          'auto_pair_transfers',
          _autoPairTransfers ? '1' : '0',
        );
      }
      if (auto['auto_reconcile_plan'] is bool) {
        _autoReconcilePlan = auto['auto_reconcile_plan'] as bool;
        await store.setSetting(
          'auto_reconcile_plan',
          _autoReconcilePlan ? '1' : '0',
        );
      }
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
      unawaited(_syncNativeNotificationConfig());
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

  Future<void> _loadAutoCaptureSettings(SakuStore store) async {
    _autoCaptureEnabled =
        (await store.getSetting('auto_capture_enabled')) == '1';
    _autoCaptureMode = AutoCaptureMode.fromCode(
      await store.getSetting('auto_capture_mode'),
    );
    _autoPairTransfers =
        (await store.getSetting('auto_pair_transfers')) != '0';
    _autoReconcilePlan =
        (await store.getSetting('auto_reconcile_plan')) != '0';
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

    final rawSources = await store.getSetting('auto_capture_sources');
    if (rawSources != null && rawSources.trim().isNotEmpty) {
      final parsed = rawSources
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      if (parsed.isNotEmpty) {
        _enabledNotificationSourceIds = parsed;
      }
    }

    final rawPending = await store.getSetting('auto_capture_pending');
    if (rawPending != null && rawPending.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPending);
        if (decoded is List) {
          _pendingAutoTransactions = decoded
              .whereType<Map>()
              .map(
                (m) => ParsedBankNotification.fromJson(
                  Map<String, Object?>.from(m),
                ),
              )
              .toList();
        }
      } catch (_) {
        _pendingAutoTransactions = <ParsedBankNotification>[];
      }
    }

    final rawFingerprints = await store.getSetting('auto_capture_fingerprints');
    if (rawFingerprints != null && rawFingerprints.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawFingerprints);
        if (decoded is List) {
          _processedFingerprints = decoded
              .whereType<String>()
              .take(250)
              .toList();
        }
      } catch (_) {
        _processedFingerprints = <String>[];
      }
    }

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

  Future<void> _persistPendingAutoTransactions() async {
    final store = _store;
    if (store == null) {
      return;
    }
    final payload = jsonEncode(
      _pendingAutoTransactions.map((e) => e.toJson()).toList(),
    );
    await store.setSetting('auto_capture_pending', payload);
  }

  Future<void> _persistProcessedFingerprints() async {
    final store = _store;
    if (store == null) {
      return;
    }
    if (_processedFingerprints.length > 250) {
      _processedFingerprints = _processedFingerprints.sublist(
        _processedFingerprints.length - 250,
      );
    }
    await store.setSetting(
      'auto_capture_fingerprints',
      jsonEncode(_processedFingerprints),
    );
  }

  Future<void> _bootstrapNativeNotifications() async {
    await _syncNativeNotificationConfig();
    await refreshNotificationPermission();
    await refreshPostNotificationPermission();
    await _syncHomeWidgetAndReminders();
    if (_autoCaptureEnabled) {
      await drainNativeNotifications();
    }
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

  Future<void> setAutoPairTransfers(bool enabled) async {
    _autoPairTransfers = enabled;
    await _store?.setSetting('auto_pair_transfers', enabled ? '1' : '0');
    notifyListeners();
  }

  Future<void> setSmartAlertsEnabled(bool enabled) async {
    _smartAlertsEnabled = enabled;
    await _store?.setSetting('smart_alerts_enabled', enabled ? '1' : '0');
    unawaited(_syncHomeWidgetAndReminders());
    notifyListeners();
  }

  String? lookupLearnedCategory(String text) {
    final key = BankNotificationParser.normalizeMerchantKey(text);
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
    final key = BankNotificationParser.normalizeMerchantKey(tx.note);
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

  Future<void> _syncNativeNotificationConfig() async {
    if (_customStore != null) {
      return;
    }
    final packages = BankNotificationParser.packagesForSourceIds(
      _enabledNotificationSourceIds,
    );
    await NotificationBridgeService.updateConfig(
      enabled: _autoCaptureEnabled,
      packages: packages,
    );
  }

  Future<bool> refreshNotificationPermission({bool notify = true}) async {
    if (_customStore != null) {
      return _notificationPermissionGranted;
    }
    final granted = await NotificationBridgeService.isPermissionGranted();
    _notificationPermissionGranted = granted;
    if (notify) {
      notifyListeners();
    }
    return granted;
  }

  Future<void> setAutoCaptureEnabled(bool enabled) async {
    _autoCaptureEnabled = enabled;
    await _store?.setSetting('auto_capture_enabled', enabled ? '1' : '0');
    await _syncNativeNotificationConfig();
    if (enabled) {
      await drainNativeNotifications(notify: false);
    }
    notifyListeners();
  }

  Future<void> setAutoCaptureMode(AutoCaptureMode mode) async {
    _autoCaptureMode = mode;
    await _store?.setSetting('auto_capture_mode', mode.code);
    notifyListeners();
  }

  Future<void> toggleNotificationSource(String sourceId, bool enabled) async {
    final next = Set<String>.from(_enabledNotificationSourceIds);
    if (enabled) {
      next.add(sourceId);
    } else if (next.length > 1) {
      next.remove(sourceId);
    }
    _enabledNotificationSourceIds = next;
    await _store?.setSetting('auto_capture_sources', next.join(','));
    await _syncNativeNotificationConfig();
    notifyListeners();
  }

  bool get hasMissingPriorityBankWallets {
    final names = _wallets.map((w) => w.name.toLowerCase()).toSet();
    return !names.contains('seabank') || !names.contains('bank jago');
  }

  Future<int> ensurePriorityBankWallets() async {
    final store = _store;
    if (store == null) {
      return 0;
    }
    var added = 0;
    for (final sourceId in <String>['seabank', 'jago']) {
      final src = BankNotificationParser.findSourceById(sourceId);
      if (src == null) {
        continue;
      }
      final exists = _wallets.any(
        (w) => w.name.toLowerCase() == src.walletName.toLowerCase(),
      );
      if (!exists) {
        await store.addWallet(
          WalletModel(
            name: src.walletName,
            kind: src.walletKind,
            balance: 0,
            colorValue: src.walletColor,
            iconKey: src.walletIconKey,
            sortOrder: _wallets.length + added,
            createdAt: now,
          ),
        );
        added++;
      }
    }
    if (added > 0) {
      await _reloadData();
      notifyListeners();
    }
    return added;
  }

  Future<WalletModel?> _resolveOrCreateWalletForSource(
    String sourceId,
    String suggestedName,
  ) async {
    for (final w in _wallets) {
      if (w.name.toLowerCase() == suggestedName.toLowerCase()) {
        return w;
      }
    }
    for (final w in _wallets) {
      if (w.name.toLowerCase().contains(suggestedName.toLowerCase()) ||
          suggestedName.toLowerCase().contains(w.name.toLowerCase())) {
        return w;
      }
    }

    final store = _store;
    final src = BankNotificationParser.findSourceById(sourceId);
    if (store != null && src != null) {
      await store.addWallet(
        WalletModel(
          name: src.walletName,
          kind: src.walletKind,
          balance: 0,
          colorValue: src.walletColor,
          iconKey: src.walletIconKey,
          sortOrder: _wallets.length,
          createdAt: now,
        ),
      );
      await _reloadData();
      for (final w in _wallets) {
        if (w.name.toLowerCase() == src.walletName.toLowerCase()) {
          return w;
        }
      }
    }
    return _wallets.isNotEmpty ? _wallets.first : null;
  }

  Future<int> drainNativeNotifications({bool notify = true}) async {
    if (_isDrainingNotifications) {
      return 0;
    }
    _isDrainingNotifications = true;
    try {
      final events = await NotificationBridgeService.drainPendingEvents();
      var capturedCount = 0;
      for (final event in events) {
        final accepted = await processRawNotification(
          event,
          notify: false,
        );
        if (accepted) {
          capturedCount++;
        }
      }
      if (notify && (capturedCount > 0 || events.isNotEmpty)) {
        notifyListeners();
      }
      return capturedCount;
    } finally {
      _isDrainingNotifications = false;
    }
  }

  Future<bool> processRawNotification(
    RawBankNotification raw, {
    bool isSimulation = false,
    bool notify = true,
  }) async {
    final source = BankNotificationParser.findSourceByPackage(raw.packageName);
    final sourceName = source?.name ?? raw.packageName;
    final parsed = BankNotificationParser.parse(
      raw,
      learnedCategories: _learnedMerchantCategories,
    );

    if (parsed == null) {
      _appendLog(
        AutoCaptureLogEntry(
          sourceName: sourceName,
          title: raw.title,
          text: raw.text,
          statusLabel: 'Diabaikan (bukan transaksi / promo / OTP)',
          accepted: false,
          timestamp: raw.timestamp,
        ),
      );
      if (notify) {
        notifyListeners();
      }
      return false;
    }

    if (!isSimulation && _processedFingerprints.contains(parsed.fingerprint)) {
      _appendLog(
        AutoCaptureLogEntry(
          sourceName: parsed.sourceName,
          title: raw.title,
          text: raw.text,
          statusLabel: 'Duplikat diabaikan',
          accepted: false,
          timestamp: raw.timestamp,
        ),
      );
      if (notify) {
        notifyListeners();
      }
      return false;
    }

    if (!isSimulation) {
      _processedFingerprints.add(parsed.fingerprint);
      await _persistProcessedFingerprints();
    }

    if (_autoCaptureMode == AutoCaptureMode.autoSave) {
      final wallet = await _resolveOrCreateWalletForSource(
        parsed.sourceId,
        parsed.suggestedWalletName,
      );
      if (wallet?.id != null && _store != null) {
        if (_autoPairTransfers) {
          final pairedLog = await _tryPairSelfTransfer(
            parsed: parsed,
            wallet: wallet!,
          );
          if (pairedLog != null) {
            _appendLog(
              AutoCaptureLogEntry(
                sourceName: parsed.sourceName,
                title: raw.title,
                text: raw.text,
                statusLabel: pairedLog,
                accepted: true,
                timestamp: parsed.timestamp,
              ),
            );
            if (notify) {
              notifyListeners();
            }
            return true;
          }
        }

        final savedTx = TransactionModel(
          kind: parsed.kind,
          amount: parsed.amount,
          category: parsed.category,
          note: parsed.note,
          walletId: wallet!.id!,
          transactionDate: parsed.timestamp,
          createdAt: now,
        );
        await _store!.addTransaction(savedTx);
        final reconcileNote = _autoReconcilePlan
            ? await _autoReconcileBillsAndDebts(parsed)
            : null;
        await _applyAutoGoalAllocationIfEligible(savedTx);
        await _reloadData();
        if (parsed.kind == TransactionKind.expense) {
          unawaited(_evaluateBudgetAlertsAfterExpense(parsed.category));
        }
        final baseStatus =
            'Tercatat otomatis (${IdrFormat.currency(parsed.amount)} · ${wallet.name})';
        _appendLog(
          AutoCaptureLogEntry(
            sourceName: parsed.sourceName,
            title: raw.title,
            text: raw.text,
            statusLabel: reconcileNote != null
                ? '$baseStatus · $reconcileNote'
                : baseStatus,
            accepted: true,
            timestamp: parsed.timestamp,
          ),
        );
        if (notify) {
          notifyListeners();
        }
        return true;
      }
    }

    final uniqueItem = isSimulation
        ? ParsedBankNotification(
            fingerprint:
                '${parsed.fingerprint}_${DateTime.now().microsecondsSinceEpoch}',
            sourceId: parsed.sourceId,
            sourceName: parsed.sourceName,
            suggestedWalletName: parsed.suggestedWalletName,
            kind: parsed.kind,
            amount: parsed.amount,
            merchant: parsed.merchant,
            category: parsed.category,
            note: parsed.note,
            timestamp: parsed.timestamp,
            rawTitle: parsed.rawTitle,
            rawText: parsed.rawText,
          )
        : parsed;

    _pendingAutoTransactions = <ParsedBankNotification>[
      uniqueItem,
      ..._pendingAutoTransactions,
    ];
    await _persistPendingAutoTransactions();

    _appendLog(
      AutoCaptureLogEntry(
        sourceName: parsed.sourceName,
        title: raw.title,
        text: raw.text,
        statusLabel:
            'Masuk antrean konfirmasi (${IdrFormat.currency(parsed.amount)})',
        accepted: true,
        timestamp: parsed.timestamp,
      ),
    );
    if (notify) {
      notifyListeners();
    }
    return true;
  }

  Future<bool> approvePendingAutoTransaction(
    String fingerprint, {
    int? overrideWalletId,
    String? overrideCategory,
    String? overrideNote,
    int? overrideAmount,
  }) async {
    final idx = _pendingAutoTransactions.indexWhere(
      (e) => e.fingerprint == fingerprint,
    );
    if (idx < 0 || _store == null) {
      return false;
    }
    final item = _pendingAutoTransactions[idx];
    final targetWallet = overrideWalletId != null
        ? walletById(overrideWalletId)
        : await _resolveOrCreateWalletForSource(
            item.sourceId,
            item.suggestedWalletName,
          );
    if (targetWallet?.id == null) {
      return false;
    }

    final savedTx = TransactionModel(
      kind: item.kind,
      amount: overrideAmount ?? item.amount,
      category: overrideCategory ?? item.category,
      note: overrideNote ?? item.note,
      walletId: targetWallet!.id!,
      transactionDate: item.timestamp,
      createdAt: now,
    );
    await _store!.addTransaction(savedTx);
    await _learnFromTransaction(savedTx);
    await _applyAutoGoalAllocationIfEligible(savedTx);
    _pendingAutoTransactions.removeAt(idx);
    await _persistPendingAutoTransactions();
    await _reloadData();
    if (savedTx.kind == TransactionKind.expense) {
      unawaited(_evaluateBudgetAlertsAfterExpense(savedTx.category));
    }
    notifyListeners();
    return true;
  }

  WalletModel? _findExistingWalletByName(String name) {
    final target = name.trim().toLowerCase();
    for (final w in _wallets) {
      if (w.name.toLowerCase() == target) {
        return w;
      }
    }
    return null;
  }

  Future<String?> _tryPairSelfTransfer({
    required ParsedBankNotification parsed,
    required WalletModel wallet,
  }) async {
    final store = _store;
    if (store == null || wallet.id == null) {
      return null;
    }

    const pairWindow = Duration(minutes: 3);
    const maxAdminFeeDelta = 6500;

    // 1. Absorb the second leg if a matching transfer was already recorded moments earlier.
    for (final existing in _transactions.take(15)) {
      if (existing.kind != TransactionKind.transfer) {
        continue;
      }
      final timeDiff = parsed.timestamp
          .difference(existing.transactionDate)
          .abs();
      final amountDiff = (existing.amount - parsed.amount).abs();
      if (timeDiff <= pairWindow && amountDiff <= maxAdminFeeDelta) {
        final matchesIncomingLeg =
            parsed.kind == TransactionKind.income &&
            existing.toWalletId == wallet.id;
        final matchesOutgoingLeg =
            parsed.kind == TransactionKind.expense &&
            existing.walletId == wallet.id;
        if (matchesIncomingLeg || matchesOutgoingLeg) {
          return 'Disatukan ke Transfer Antar Dompet yang sudah tercatat';
        }
      }
    }

    // 2. Pair opposite-direction notification (expense in wallet A + income in wallet B).
    for (final existing in _transactions.take(15)) {
      if (existing.id == null || existing.walletId == wallet.id) {
        continue;
      }
      final isOpposite =
          (existing.kind == TransactionKind.expense &&
              parsed.kind == TransactionKind.income) ||
          (existing.kind == TransactionKind.income &&
              parsed.kind == TransactionKind.expense);
      if (!isOpposite) {
        continue;
      }
      final timeDiff = parsed.timestamp
          .difference(existing.transactionDate)
          .abs();
      final amountDiff = (existing.amount - parsed.amount).abs();
      if (timeDiff <= pairWindow && amountDiff <= maxAdminFeeDelta) {
        final fromWalletId = existing.kind == TransactionKind.expense
            ? existing.walletId
            : wallet.id!;
        final toWalletId = existing.kind == TransactionKind.expense
            ? wallet.id!
            : existing.walletId;
        final fromName = walletById(fromWalletId)?.name ?? 'Dompet';
        final toName = walletById(toWalletId)?.name ?? 'Dompet';
        final transferAmount = existing.amount < parsed.amount
            ? existing.amount
            : parsed.amount;

        await store.updateTransaction(
          existing.copyWith(
            kind: TransactionKind.transfer,
            amount: transferAmount,
            category: CategoryCatalog.transferMeta.name,
            note: 'Transfer $fromName -> $toName',
            walletId: fromWalletId,
            toWalletId: toWalletId,
          ),
        );
        await _reloadData();
        return 'Dipasangkan otomatis: Transfer $fromName -> $toName (${IdrFormat.currency(transferAmount)})';
      }
    }

    // 3. Explicit outgoing top-up or transfer naming another wallet owned by the user.
    if (parsed.kind == TransactionKind.expense &&
        parsed.targetWalletHint != null) {
      final destWallet = _findExistingWalletByName(parsed.targetWalletHint!);
      if (destWallet?.id != null && destWallet!.id != wallet.id) {
        await store.addTransaction(
          TransactionModel(
            kind: TransactionKind.transfer,
            amount: parsed.amount,
            category: CategoryCatalog.transferMeta.name,
            note: 'Transfer ${wallet.name} -> ${destWallet.name}',
            walletId: wallet.id!,
            toWalletId: destWallet.id!,
            transactionDate: parsed.timestamp,
            createdAt: now,
          ),
        );
        await _reloadData();
        return 'Transfer otomatis: ${wallet.name} -> ${destWallet.name} (${IdrFormat.currency(parsed.amount)})';
      }
    }

    return null;
  }

  Future<int> approveAllPendingAutoTransactions() async {
    final snapshot = List<ParsedBankNotification>.from(_pendingAutoTransactions);
    var saved = 0;
    for (final item in snapshot) {
      final ok = await approvePendingAutoTransaction(item.fingerprint);
      if (ok) {
        saved++;
      }
    }
    return saved;
  }

  Future<void> dismissPendingAutoTransaction(String fingerprint) async {
    _pendingAutoTransactions.removeWhere((e) => e.fingerprint == fingerprint);
    await _persistPendingAutoTransactions();
    notifyListeners();
  }

  Future<List<RawBankNotification>> loadNativeRecentLogs() {
    return NotificationBridgeService.readRecentLogs();
  }

  Future<void> clearAutoCaptureLogs() async {
    _autoCaptureLogs = <AutoCaptureLogEntry>[];
    await NotificationBridgeService.clearRecentLogs();
    notifyListeners();
  }

  void _appendLog(AutoCaptureLogEntry entry) {
    _autoCaptureLogs = <AutoCaptureLogEntry>[entry, ..._autoCaptureLogs];
    if (_autoCaptureLogs.length > 30) {
      _autoCaptureLogs = _autoCaptureLogs.sublist(0, 30);
    }
  }

  Future<void> setAutoReconcilePlan(bool enabled) async {
    _autoReconcilePlan = enabled;
    await _store?.setSetting('auto_reconcile_plan', enabled ? '1' : '0');
    notifyListeners();
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

  Future<String?> _autoReconcileBillsAndDebts(
    ParsedBankNotification parsed,
  ) async {
    final store = _store;
    if (store == null) {
      return null;
    }

    final hay = BankNotificationParser.normalizeMerchantKey(
      '${parsed.merchant} ${parsed.rawTitle} ${parsed.rawText}',
    );
    if (hay.isEmpty) {
      return null;
    }

    // 1. Match active Receivables (incoming) or Payables (outgoing) by party name.
    for (final debt in _debts) {
      if (debt.id == null || debt.isSettled) {
        continue;
      }
      final kindMatches =
          (parsed.kind == TransactionKind.income && debt.isReceivable) ||
          (parsed.kind == TransactionKind.expense && !debt.isReceivable);
      if (!kindMatches) {
        continue;
      }
      if (_matchesEntityName(debt.personName, hay)) {
        final nextRemaining = (debt.remainingAmount - parsed.amount).clamp(
          0,
          debt.principalAmount,
        );
        await store.updateDebt(
          debt.copyWith(
            remainingAmount: nextRemaining,
            status: nextRemaining <= 0 ? 'paid' : 'open',
          ),
        );
        final label = debt.isReceivable ? 'Piutang' : 'Hutang';
        return nextRemaining <= 0
            ? 'Auto-Lunas $label ${debt.personName}'
            : 'Auto-Potong $label ${debt.personName} (sisa ${IdrFormat.currency(nextRemaining)})';
      }
    }

    // 2. Match unpaid monthly Bills on outgoing expense by bill name or exact amount + category.
    if (parsed.kind == TransactionKind.expense) {
      final cycleKey = BillModel.monthKeyFor(parsed.timestamp);
      for (final bill in _bills) {
        if (bill.id == null || bill.isPaidFor(parsed.timestamp)) {
          continue;
        }
        final nameMatched = _matchesEntityName(bill.name, hay);
        final amountAndCatMatched =
            (bill.amount - parsed.amount).abs() <= 5000 &&
            bill.category.toLowerCase() == parsed.category.toLowerCase();
        if (nameMatched || amountAndCatMatched) {
          await store.updateBill(
            bill.copyWith(
              isPaidCurrentCycle: true,
              lastPaidMonth: cycleKey,
            ),
          );
          return 'Auto-Lunas Tagihan ${bill.name}';
        }
      }
    }

    return null;
  }

  bool _matchesEntityName(String entityName, String normalizedHaystack) {
    final normalizedName = BankNotificationParser.normalizeMerchantKey(
      entityName,
    );
    if (normalizedName.length < 3) {
      return false;
    }
    if (normalizedHaystack.contains(normalizedName)) {
      return true;
    }
    final tokens = normalizedName
        .split(' ')
        .where(
          (t) =>
              t.length >= 4 &&
              !const <String>{
                'bayar',
                'tagihan',
                'cicilan',
                'bulanan',
                'rumah',
                'paket',
                'token',
              }.contains(t),
        )
        .toList();
    if (tokens.isEmpty) {
      return false;
    }
    return tokens.any((t) => normalizedHaystack.contains(t));
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
    _appendLog(
      AutoCaptureLogEntry(
        sourceName: 'Auto-Tabungan',
        title: 'Sisihkan $_autoSaveGoalPercent% ke ${goal.name}',
        text: 'Dari pemasukan ${tx.displayTitle} (${IdrFormat.currency(tx.amount)})',
        statusLabel:
            'Progres ${goal.name} bertambah ${IdrFormat.currency(alloc)}',
        accepted: true,
        timestamp: now,
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

  @override
  void dispose() {
    NotificationBridgeService.setOnPendingEventsAvailable(null);
    super.dispose();
  }
}

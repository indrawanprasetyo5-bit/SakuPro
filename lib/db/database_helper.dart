import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/roadmap_models.dart';
import '../models/transaction_item.dart';
import '../models/wallet.dart';

class StorageException implements Exception {
  const StorageException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class SakuStore {
  bool get isInMemory;

  Future<void> init();

  Future<List<WalletModel>> getWallets();
  Future<WalletModel> addWallet(WalletModel wallet);
  Future<void> updateWallet(WalletModel wallet);
  Future<void> deleteWallet(int id);

  Future<List<TransactionModel>> getTransactions({int? limit});
  Future<TransactionModel> addTransaction(TransactionModel tx);
  Future<void> updateTransaction(TransactionModel updated);
  Future<void> deleteTransaction(int id);

  Future<int> getGlobalMonthlyBudget();
  Future<void> setGlobalMonthlyBudget(int amount);
  Future<List<BudgetModel>> getCategoryBudgets();
  Future<void> upsertCategoryBudget(String category, int monthlyLimit);
  Future<void> deleteCategoryBudget(int id);

  Future<List<GoalModel>> getGoals();
  Future<GoalModel> addGoal(GoalModel goal);
  Future<void> updateGoal(GoalModel goal);
  Future<void> deleteGoal(int id);
  Future<void> addGoalContribution({
    required int goalId,
    required int amount,
    required int walletId,
    required DateTime timestamp,
  });

  Future<List<BillModel>> getBills();
  Future<BillModel> addBill(BillModel bill);
  Future<void> updateBill(BillModel bill);
  Future<void> deleteBill(int id);
  Future<void> payBill({
    required int billId,
    required int walletId,
    required String monthKey,
    required DateTime timestamp,
  });
  Future<void> markBillUnpaid(int billId);

  Future<List<DebtModel>> getDebts();
  Future<DebtModel> addDebt(DebtModel debt);
  Future<void> updateDebt(DebtModel debt);
  Future<void> deleteDebt(int id);
  Future<void> recordDebtInstallment({
    required int debtId,
    required int payAmount,
    int? walletId,
    required DateTime timestamp,
  });

  Future<String?> getSetting(String key);
  Future<void> setSetting(String key, String value);

  Future<Map<String, Object?>> exportSnapshot();
  Future<void> restoreSnapshot(Map<String, Object?> snapshot);
}

List<WalletModel> buildDefaultWallets(DateTime now) {
  return <WalletModel>[
    WalletModel(
      name: 'Cash',
      kind: WalletKind.cash,
      balance: 0,
      colorValue: 0xFF0F766E,
      iconKey: 'payments',
      sortOrder: 0,
      createdAt: now,
    ),
    WalletModel(
      name: 'BCA',
      kind: WalletKind.bank,
      balance: 0,
      colorValue: 0xFF1D4ED8,
      iconKey: 'account_balance',
      sortOrder: 1,
      createdAt: now,
    ),
    WalletModel(
      name: 'GoPay',
      kind: WalletKind.ewallet,
      balance: 0,
      colorValue: 0xFF059669,
      iconKey: 'qr_code',
      sortOrder: 2,
      createdAt: now,
    ),
    WalletModel(
      name: 'DANA',
      kind: WalletKind.ewallet,
      balance: 0,
      colorValue: 0xFF0284C7,
      iconKey: 'phone_android',
      sortOrder: 3,
      createdAt: now,
    ),
    WalletModel(
      name: 'Tabungan',
      kind: WalletKind.savings,
      balance: 0,
      colorValue: 0xFFD97706,
      iconKey: 'savings',
      sortOrder: 4,
      createdAt: now,
    ),
  ];
}

class SqliteSakuStore implements SakuStore {
  Database? _db;

  @override
  bool get isInMemory => false;

  Database get _database {
    final db = _db;
    if (db == null) {
      throw const StorageException('Database belum siap.');
    }
    return db;
  }

  @override
  Future<void> init() async {
    if (_db != null) {
      return;
    }
    final dbDir = await getDatabasesPath();
    final fullPath = p.join(dbDir, 'saku_pro_v1.db');
    _db = await openDatabase(
      fullPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE wallets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            balance INTEGER NOT NULL DEFAULT 0,
            color_hex INTEGER NOT NULL,
            icon_name TEXT NOT NULL,
            exclude_from_total INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            amount INTEGER NOT NULL,
            category TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            wallet_id INTEGER NOT NULL,
            to_wallet_id INTEGER,
            transaction_date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            receipt_detail TEXT NOT NULL DEFAULT '',
            receipt_image_path TEXT NOT NULL DEFAULT ''
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_tx_date ON transactions(transaction_date DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_tx_wallet ON transactions(wallet_id)',
        );

        await db.execute('''
          CREATE TABLE budgets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category TEXT NOT NULL,
            monthly_limit INTEGER NOT NULL,
            month_key TEXT NOT NULL,
            alert_threshold REAL NOT NULL DEFAULT 0.8,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE goals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            target_amount INTEGER NOT NULL,
            current_amount INTEGER NOT NULL DEFAULT 0,
            deadline TEXT,
            wallet_id INTEGER,
            color_hex INTEGER NOT NULL DEFAULT 1013358,
            icon_name TEXT NOT NULL DEFAULT 'savings',
            is_completed INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE debts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            person_name TEXT NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            type TEXT NOT NULL,
            principal_amount INTEGER NOT NULL,
            remaining_amount INTEGER NOT NULL,
            due_date TEXT,
            note TEXT NOT NULL DEFAULT '',
            status TEXT NOT NULL DEFAULT 'open',
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE bills (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            amount INTEGER NOT NULL,
            category TEXT NOT NULL,
            due_day INTEGER NOT NULL,
            frequency TEXT NOT NULL DEFAULT 'monthly',
            wallet_id INTEGER,
            is_paid_current_cycle INTEGER NOT NULL DEFAULT 0,
            last_paid_month TEXT NOT NULL DEFAULT '',
            auto_remind INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        final now = DateTime.now();
        for (final wallet in buildDefaultWallets(now)) {
          await db.insert('wallets', wallet.toMap());
        }

        await db.insert(
          'budgets',
          BudgetModel(
            category: 'GLOBAL',
            monthlyLimit: 3000000,
            monthKey: 'ALL',
            createdAt: now,
          ).toMap(),
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE debts ADD COLUMN phone TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE bills ADD COLUMN last_paid_month TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE transactions ADD COLUMN receipt_detail TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE transactions ADD COLUMN receipt_image_path TEXT NOT NULL DEFAULT ''",
          );
        }
      },
    );
  }

  @override
  Future<List<WalletModel>> getWallets() async {
    final rows = await _database.query(
      'wallets',
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(WalletModel.fromMap).toList();
  }

  @override
  Future<WalletModel> addWallet(WalletModel wallet) async {
    final id = await _database.insert('wallets', wallet.toMap());
    return wallet.copyWith(id: id);
  }

  @override
  Future<void> updateWallet(WalletModel wallet) async {
    if (wallet.id == null) {
      return;
    }
    await _database.update(
      'wallets',
      wallet.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[wallet.id],
    );
  }

  @override
  Future<void> deleteWallet(int id) async {
    final walletCount =
        Sqflite.firstIntValue(
          await _database.rawQuery('SELECT COUNT(*) FROM wallets'),
        ) ??
        0;
    if (walletCount <= 1) {
      throw const StorageException('Minimal satu dompet harus tetap aktif.');
    }

    final txRefCount =
        Sqflite.firstIntValue(
          await _database.rawQuery(
            'SELECT COUNT(*) FROM transactions WHERE wallet_id = ? OR to_wallet_id = ?',
            <Object?>[id, id],
          ),
        ) ??
        0;
    if (txRefCount > 0) {
      throw const StorageException(
        'Dompet ini memiliki riwayat transaksi dan tidak bisa dihapus.',
      );
    }

    await _database.delete('wallets', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  @override
  Future<List<TransactionModel>> getTransactions({int? limit}) async {
    final rows = await _database.query(
      'transactions',
      orderBy: 'transaction_date DESC, id DESC',
      limit: limit,
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<void> _applyWalletEffect(
    Transaction txn,
    TransactionModel item, {
    required int sign,
  }) async {
    switch (item.kind) {
      case TransactionKind.expense:
        await txn.rawUpdate(
          'UPDATE wallets SET balance = balance + ? WHERE id = ?',
          <Object?>[-item.amount * sign, item.walletId],
        );
      case TransactionKind.income:
        await txn.rawUpdate(
          'UPDATE wallets SET balance = balance + ? WHERE id = ?',
          <Object?>[item.amount * sign, item.walletId],
        );
      case TransactionKind.transfer:
        await txn.rawUpdate(
          'UPDATE wallets SET balance = balance + ? WHERE id = ?',
          <Object?>[-item.amount * sign, item.walletId],
        );
        if (item.toWalletId != null) {
          await txn.rawUpdate(
            'UPDATE wallets SET balance = balance + ? WHERE id = ?',
            <Object?>[item.amount * sign, item.toWalletId],
          );
        }
    }
  }

  @override
  Future<TransactionModel> addTransaction(TransactionModel tx) async {
    return _database.transaction<TransactionModel>((txn) async {
      final id = await txn.insert('transactions', tx.toMap());
      await _applyWalletEffect(txn, tx, sign: 1);
      return tx.copyWith(id: id);
    });
  }

  @override
  Future<void> updateTransaction(TransactionModel updated) async {
    final id = updated.id;
    if (id == null) {
      return;
    }
    await _database.transaction<void>((txn) async {
      final existingRows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (existingRows.isEmpty) {
        return;
      }
      final previous = TransactionModel.fromMap(existingRows.first);
      // Reverse old wallet delta before applying the edited transaction.
      await _applyWalletEffect(txn, previous, sign: -1);
      await txn.update(
        'transactions',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      await _applyWalletEffect(txn, updated, sign: 1);
    });
  }

  @override
  Future<void> deleteTransaction(int id) async {
    await _database.transaction<void>((txn) async {
      final existingRows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (existingRows.isEmpty) {
        return;
      }
      final previous = TransactionModel.fromMap(existingRows.first);
      await _applyWalletEffect(txn, previous, sign: -1);
      await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }

  @override
  Future<int> getGlobalMonthlyBudget() async {
    final rows = await _database.query(
      'budgets',
      where: 'category = ?',
      whereArgs: const <Object?>['GLOBAL'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return 3000000;
    }
    return BudgetModel.fromMap(rows.first).monthlyLimit;
  }

  @override
  Future<void> setGlobalMonthlyBudget(int amount) async {
    final existing = await _database.query(
      'budgets',
      where: 'category = ?',
      whereArgs: const <Object?>['GLOBAL'],
      limit: 1,
    );
    if (existing.isEmpty) {
      await _database.insert(
        'budgets',
        BudgetModel(
          category: 'GLOBAL',
          monthlyLimit: amount,
          monthKey: 'ALL',
          createdAt: DateTime.now(),
        ).toMap(),
      );
    } else {
      await _database.update(
        'budgets',
        <String, Object?>{'monthly_limit': amount},
        where: 'category = ?',
        whereArgs: const <Object?>['GLOBAL'],
      );
    }
  }

  @override
  Future<List<BudgetModel>> getCategoryBudgets() async {
    final rows = await _database.query(
      'budgets',
      where: 'category != ?',
      whereArgs: const <Object?>['GLOBAL'],
      orderBy: 'id ASC',
    );
    return rows.map(BudgetModel.fromMap).toList();
  }

  @override
  Future<void> upsertCategoryBudget(String category, int monthlyLimit) async {
    final existing = await _database.query(
      'budgets',
      where: 'category = ?',
      whereArgs: <Object?>[category],
      limit: 1,
    );
    if (existing.isEmpty) {
      await _database.insert(
        'budgets',
        BudgetModel(
          category: category,
          monthlyLimit: monthlyLimit,
          monthKey: 'ALL',
          createdAt: DateTime.now(),
        ).toMap(),
      );
    } else {
      await _database.update(
        'budgets',
        <String, Object?>{'monthly_limit': monthlyLimit},
        where: 'id = ?',
        whereArgs: <Object?>[existing.first['id']],
      );
    }
  }

  @override
  Future<void> deleteCategoryBudget(int id) async {
    await _database.delete(
      'budgets',
      where: 'id = ? AND category != ?',
      whereArgs: <Object?>[id, 'GLOBAL'],
    );
  }

  @override
  Future<List<GoalModel>> getGoals() async {
    final rows = await _database.query(
      'goals',
      orderBy: 'is_completed ASC, id DESC',
    );
    return rows.map(GoalModel.fromMap).toList();
  }

  @override
  Future<GoalModel> addGoal(GoalModel goal) async {
    final id = await _database.insert('goals', goal.toMap());
    return goal.copyWith(id: id);
  }

  @override
  Future<void> updateGoal(GoalModel goal) async {
    if (goal.id == null) {
      return;
    }
    await _database.update(
      'goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[goal.id],
    );
  }

  @override
  Future<void> deleteGoal(int id) async {
    await _database.delete('goals', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  @override
  Future<void> addGoalContribution({
    required int goalId,
    required int amount,
    required int walletId,
    required DateTime timestamp,
  }) async {
    await _database.transaction<void>((txn) async {
      final rows = await txn.query(
        'goals',
        where: 'id = ?',
        whereArgs: <Object?>[goalId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return;
      }
      final goal = GoalModel.fromMap(rows.first);
      final nextAmount = goal.currentAmount + amount;
      final completed = nextAmount >= goal.targetAmount ? 1 : 0;

      await txn.update(
        'goals',
        <String, Object?>{
          'current_amount': nextAmount,
          'is_completed': completed,
        },
        where: 'id = ?',
        whereArgs: <Object?>[goalId],
      );

      final tx = TransactionModel(
        kind: TransactionKind.expense,
        amount: amount,
        category: 'Tabungan & Target',
        note: 'Tabungan: ${goal.name}',
        walletId: walletId,
        transactionDate: timestamp,
        createdAt: timestamp,
      );
      await txn.insert('transactions', tx.toMap());
      await _applyWalletEffect(txn, tx, sign: 1);
    });
  }

  @override
  Future<List<BillModel>> getBills() async {
    final rows = await _database.query(
      'bills',
      orderBy: 'due_day ASC, id ASC',
    );
    return rows.map(BillModel.fromMap).toList();
  }

  @override
  Future<BillModel> addBill(BillModel bill) async {
    final id = await _database.insert('bills', bill.toMap());
    return bill.copyWith(id: id);
  }

  @override
  Future<void> updateBill(BillModel bill) async {
    if (bill.id == null) {
      return;
    }
    await _database.update(
      'bills',
      bill.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[bill.id],
    );
  }

  @override
  Future<void> deleteBill(int id) async {
    await _database.delete('bills', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  @override
  Future<void> payBill({
    required int billId,
    required int walletId,
    required String monthKey,
    required DateTime timestamp,
  }) async {
    await _database.transaction<void>((txn) async {
      final rows = await txn.query(
        'bills',
        where: 'id = ?',
        whereArgs: <Object?>[billId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return;
      }
      final bill = BillModel.fromMap(rows.first);
      final tx = TransactionModel(
        kind: TransactionKind.expense,
        amount: bill.amount,
        category: bill.category,
        note: 'Tagihan: ${bill.name}',
        walletId: walletId,
        transactionDate: timestamp,
        createdAt: timestamp,
      );
      await txn.insert('transactions', tx.toMap());
      await _applyWalletEffect(txn, tx, sign: 1);

      await txn.update(
        'bills',
        <String, Object?>{
          'is_paid_current_cycle': 1,
          'last_paid_month': monthKey,
          'wallet_id': walletId,
        },
        where: 'id = ?',
        whereArgs: <Object?>[billId],
      );
    });
  }

  @override
  Future<void> markBillUnpaid(int billId) async {
    await _database.update(
      'bills',
      const <String, Object?>{
        'is_paid_current_cycle': 0,
        'last_paid_month': '',
      },
      where: 'id = ?',
      whereArgs: <Object?>[billId],
    );
  }

  @override
  Future<List<DebtModel>> getDebts() async {
    final rows = await _database.query(
      'debts',
      orderBy: 'status DESC, id DESC',
    );
    return rows.map(DebtModel.fromMap).toList();
  }

  @override
  Future<DebtModel> addDebt(DebtModel debt) async {
    final id = await _database.insert('debts', debt.toMap());
    return debt.copyWith(id: id);
  }

  @override
  Future<void> updateDebt(DebtModel debt) async {
    if (debt.id == null) {
      return;
    }
    await _database.update(
      'debts',
      debt.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[debt.id],
    );
  }

  @override
  Future<void> deleteDebt(int id) async {
    await _database.delete('debts', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  @override
  Future<void> recordDebtInstallment({
    required int debtId,
    required int payAmount,
    int? walletId,
    required DateTime timestamp,
  }) async {
    await _database.transaction<void>((txn) async {
      final rows = await txn.query(
        'debts',
        where: 'id = ?',
        whereArgs: <Object?>[debtId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return;
      }
      final debt = DebtModel.fromMap(rows.first);
      final effective = payAmount > debt.remainingAmount
          ? debt.remainingAmount
          : payAmount;
      if (effective <= 0) {
        return;
      }

      final nextRemaining = debt.remainingAmount - effective;
      final nextStatus = nextRemaining <= 0 ? 'paid' : 'open';

      await txn.update(
        'debts',
        <String, Object?>{
          'remaining_amount': nextRemaining,
          'status': nextStatus,
        },
        where: 'id = ?',
        whereArgs: <Object?>[debtId],
      );

      if (walletId != null) {
        final tx = debt.isReceivable
            ? TransactionModel(
                kind: TransactionKind.income,
                amount: effective,
                category: 'Pemasukan Lain',
                note: 'Pelunasan piutang: ${debt.personName}',
                walletId: walletId,
                transactionDate: timestamp,
                createdAt: timestamp,
              )
            : TransactionModel(
                kind: TransactionKind.expense,
                amount: effective,
                category: 'Tagihan & Utilitas',
                note: 'Cicilan hutang: ${debt.personName}',
                walletId: walletId,
                transactionDate: timestamp,
                createdAt: timestamp,
              );
        await txn.insert('transactions', tx.toMap());
        await _applyWalletEffect(txn, tx, sign: 1);
      }
    });
  }

  @override
  Future<String?> getSetting(String key) async {
    final rows = await _database.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    await _database.insert(
      'app_settings',
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Map<String, Object?>> exportSnapshot() async {
    final wallets = await getWallets();
    final transactions = await getTransactions();
    final globalBudget = await getGlobalMonthlyBudget();
    final categoryBudgets = await getCategoryBudgets();
    final goals = await getGoals();
    final bills = await getBills();
    final debts = await getDebts();

    return <String, Object?>{
      'app': 'saku_pro',
      'schema_version': 3,
      'exported_at': DateTime.now().toIso8601String(),
      'global_budget': globalBudget,
      'wallets': wallets.map((w) => w.toMap()).toList(),
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'category_budgets': categoryBudgets.map((b) => b.toMap()).toList(),
      'goals': goals.map((g) => g.toMap()).toList(),
      'bills': bills.map((b) => b.toMap()).toList(),
      'debts': debts.map((d) => d.toMap()).toList(),
    };
  }

  @override
  Future<void> restoreSnapshot(Map<String, Object?> snapshot) async {
    final rawWallets = (snapshot['wallets'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => WalletModel.fromMap(Map<String, Object?>.from(e as Map)))
        .toList();
    if (rawWallets.isEmpty) {
      throw const StorageException(
        'Backup tidak memiliki daftar dompet yang valid.',
      );
    }

    final rawTx = (snapshot['transactions'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (e) => TransactionModel.fromMap(Map<String, Object?>.from(e as Map)),
        )
        .toList();
    final rawCatBudgets =
        (snapshot['category_budgets'] as List<dynamic>? ?? <dynamic>[])
            .map(
              (e) => BudgetModel.fromMap(Map<String, Object?>.from(e as Map)),
            )
            .toList();
    final rawGoals = (snapshot['goals'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => GoalModel.fromMap(Map<String, Object?>.from(e as Map)))
        .toList();
    final rawBills = (snapshot['bills'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => BillModel.fromMap(Map<String, Object?>.from(e as Map)))
        .toList();
    final rawDebts = (snapshot['debts'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => DebtModel.fromMap(Map<String, Object?>.from(e as Map)))
        .toList();
    final globalBudget =
        (snapshot['global_budget'] as num?)?.toInt() ?? 3000000;

    await _database.transaction<void>((txn) async {
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('goals');
      await txn.delete('bills');
      await txn.delete('debts');
      await txn.delete('wallets');

      for (final w in rawWallets) {
        await txn.insert('wallets', w.toMap());
      }
      await txn.insert(
        'budgets',
        BudgetModel(
          category: 'GLOBAL',
          monthlyLimit: globalBudget,
          monthKey: 'ALL',
          createdAt: DateTime.now(),
        ).toMap(),
      );
      for (final b in rawCatBudgets) {
        if (b.category != 'GLOBAL') {
          await txn.insert('budgets', b.copyWith(id: null).toMap());
        }
      }
      for (final tx in rawTx) {
        await txn.insert('transactions', tx.toMap());
      }
      for (final g in rawGoals) {
        await txn.insert('goals', g.toMap());
      }
      for (final bill in rawBills) {
        await txn.insert('bills', bill.toMap());
      }
      for (final d in rawDebts) {
        await txn.insert('debts', d.toMap());
      }
    });
  }
}

class InMemorySakuStore implements SakuStore {
  final List<WalletModel> _wallets = <WalletModel>[];
  final List<TransactionModel> _transactions = <TransactionModel>[];
  final List<BudgetModel> _budgets = <BudgetModel>[];
  final List<GoalModel> _goals = <GoalModel>[];
  final List<DebtModel> _debts = <DebtModel>[];
  final List<BillModel> _bills = <BillModel>[];
  final Map<String, String> _settings = <String, String>{};

  int _walletSeq = 1;
  int _txSeq = 1;
  int _budgetSeq = 1;
  int _goalSeq = 1;
  int _billSeq = 1;
  int _debtSeq = 1;
  bool _initialized = false;

  @override
  bool get isInMemory => true;

  @override
  Future<void> init() async {
    if (_initialized) {
      return;
    }
    final now = DateTime.now();
    for (final wallet in buildDefaultWallets(now)) {
      _wallets.add(wallet.copyWith(id: _walletSeq++));
    }
    _budgets.add(
      BudgetModel(
        id: _budgetSeq++,
        category: 'GLOBAL',
        monthlyLimit: 3000000,
        monthKey: 'ALL',
        createdAt: now,
      ),
    );
    _initialized = true;
  }

  @override
  Future<List<WalletModel>> getWallets() async {
    final sorted = List<WalletModel>.from(_wallets)
      ..sort((a, b) {
        final cmp = a.sortOrder.compareTo(b.sortOrder);
        return cmp != 0 ? cmp : (a.id ?? 0).compareTo(b.id ?? 0);
      });
    return sorted;
  }

  @override
  Future<WalletModel> addWallet(WalletModel wallet) async {
    final saved = wallet.copyWith(id: _walletSeq++);
    _wallets.add(saved);
    return saved;
  }

  @override
  Future<void> updateWallet(WalletModel wallet) async {
    final idx = _wallets.indexWhere((w) => w.id == wallet.id);
    if (idx >= 0) {
      _wallets[idx] = wallet;
    }
  }

  @override
  Future<void> deleteWallet(int id) async {
    if (_wallets.length <= 1) {
      throw const StorageException('Minimal satu dompet harus tetap aktif.');
    }
    final hasTx = _transactions.any(
      (t) => t.walletId == id || t.toWalletId == id,
    );
    if (hasTx) {
      throw const StorageException(
        'Dompet ini memiliki riwayat transaksi dan tidak bisa dihapus.',
      );
    }
    _wallets.removeWhere((w) => w.id == id);
  }

  @override
  Future<List<TransactionModel>> getTransactions({int? limit}) async {
    final sorted = List<TransactionModel>.from(_transactions)
      ..sort((a, b) {
        final dateCmp = b.transactionDate.compareTo(a.transactionDate);
        return dateCmp != 0 ? dateCmp : (b.id ?? 0).compareTo(a.id ?? 0);
      });
    if (limit != null && sorted.length > limit) {
      return sorted.sublist(0, limit);
    }
    return sorted;
  }

  void _mutateWallet(int walletId, int delta) {
    final idx = _wallets.indexWhere((w) => w.id == walletId);
    if (idx >= 0) {
      final current = _wallets[idx];
      _wallets[idx] = current.copyWith(balance: current.balance + delta);
    }
  }

  void _applyEffect(TransactionModel item, {required int sign}) {
    switch (item.kind) {
      case TransactionKind.expense:
        _mutateWallet(item.walletId, -item.amount * sign);
      case TransactionKind.income:
        _mutateWallet(item.walletId, item.amount * sign);
      case TransactionKind.transfer:
        _mutateWallet(item.walletId, -item.amount * sign);
        if (item.toWalletId != null) {
          _mutateWallet(item.toWalletId!, item.amount * sign);
        }
    }
  }

  @override
  Future<TransactionModel> addTransaction(TransactionModel tx) async {
    final saved = tx.copyWith(id: _txSeq++);
    _transactions.add(saved);
    _applyEffect(saved, sign: 1);
    return saved;
  }

  @override
  Future<void> updateTransaction(TransactionModel updated) async {
    final idx = _transactions.indexWhere((t) => t.id == updated.id);
    if (idx < 0) {
      return;
    }
    final previous = _transactions[idx];
    _applyEffect(previous, sign: -1);
    _transactions[idx] = updated;
    _applyEffect(updated, sign: 1);
  }

  @override
  Future<void> deleteTransaction(int id) async {
    final idx = _transactions.indexWhere((t) => t.id == id);
    if (idx < 0) {
      return;
    }
    final previous = _transactions.removeAt(idx);
    _applyEffect(previous, sign: -1);
  }

  @override
  Future<int> getGlobalMonthlyBudget() async {
    final idx = _budgets.indexWhere((b) => b.category == 'GLOBAL');
    return idx >= 0 ? _budgets[idx].monthlyLimit : 3000000;
  }

  @override
  Future<void> setGlobalMonthlyBudget(int amount) async {
    final idx = _budgets.indexWhere((b) => b.category == 'GLOBAL');
    if (idx >= 0) {
      _budgets[idx] = _budgets[idx].copyWith(monthlyLimit: amount);
    } else {
      _budgets.add(
        BudgetModel(
          id: _budgetSeq++,
          category: 'GLOBAL',
          monthlyLimit: amount,
          monthKey: 'ALL',
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<List<BudgetModel>> getCategoryBudgets() async {
    return _budgets.where((b) => b.category != 'GLOBAL').toList();
  }

  @override
  Future<void> upsertCategoryBudget(String category, int monthlyLimit) async {
    final idx = _budgets.indexWhere((b) => b.category == category);
    if (idx >= 0) {
      _budgets[idx] = _budgets[idx].copyWith(monthlyLimit: monthlyLimit);
    } else {
      _budgets.add(
        BudgetModel(
          id: _budgetSeq++,
          category: category,
          monthlyLimit: monthlyLimit,
          monthKey: 'ALL',
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> deleteCategoryBudget(int id) async {
    _budgets.removeWhere((b) => b.id == id && b.category != 'GLOBAL');
  }

  @override
  Future<List<GoalModel>> getGoals() async {
    final sorted = List<GoalModel>.from(_goals)
      ..sort((a, b) {
        if (a.reachedTarget != b.reachedTarget) {
          return a.reachedTarget ? 1 : -1;
        }
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });
    return sorted;
  }

  @override
  Future<GoalModel> addGoal(GoalModel goal) async {
    final saved = goal.copyWith(id: _goalSeq++);
    _goals.add(saved);
    return saved;
  }

  @override
  Future<void> updateGoal(GoalModel goal) async {
    final idx = _goals.indexWhere((g) => g.id == goal.id);
    if (idx >= 0) {
      _goals[idx] = goal;
    }
  }

  @override
  Future<void> deleteGoal(int id) async {
    _goals.removeWhere((g) => g.id == id);
  }

  @override
  Future<void> addGoalContribution({
    required int goalId,
    required int amount,
    required int walletId,
    required DateTime timestamp,
  }) async {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx < 0) {
      return;
    }
    final goal = _goals[idx];
    final nextAmount = goal.currentAmount + amount;
    _goals[idx] = goal.copyWith(
      currentAmount: nextAmount,
      isCompleted: nextAmount >= goal.targetAmount,
    );
    await addTransaction(
      TransactionModel(
        kind: TransactionKind.expense,
        amount: amount,
        category: 'Tabungan & Target',
        note: 'Tabungan: ${goal.name}',
        walletId: walletId,
        transactionDate: timestamp,
        createdAt: timestamp,
      ),
    );
  }

  @override
  Future<List<BillModel>> getBills() async {
    final sorted = List<BillModel>.from(_bills)
      ..sort((a, b) => a.dueDay.compareTo(b.dueDay));
    return sorted;
  }

  @override
  Future<BillModel> addBill(BillModel bill) async {
    final saved = bill.copyWith(id: _billSeq++);
    _bills.add(saved);
    return saved;
  }

  @override
  Future<void> updateBill(BillModel bill) async {
    final idx = _bills.indexWhere((b) => b.id == bill.id);
    if (idx >= 0) {
      _bills[idx] = bill;
    }
  }

  @override
  Future<void> deleteBill(int id) async {
    _bills.removeWhere((b) => b.id == id);
  }

  @override
  Future<void> payBill({
    required int billId,
    required int walletId,
    required String monthKey,
    required DateTime timestamp,
  }) async {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx < 0) {
      return;
    }
    final bill = _bills[idx];
    await addTransaction(
      TransactionModel(
        kind: TransactionKind.expense,
        amount: bill.amount,
        category: bill.category,
        note: 'Tagihan: ${bill.name}',
        walletId: walletId,
        transactionDate: timestamp,
        createdAt: timestamp,
      ),
    );
    _bills[idx] = bill.copyWith(
      isPaidCurrentCycle: true,
      lastPaidMonth: monthKey,
      walletId: walletId,
    );
  }

  @override
  Future<void> markBillUnpaid(int billId) async {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx >= 0) {
      _bills[idx] = _bills[idx].copyWith(
        isPaidCurrentCycle: false,
        lastPaidMonth: '',
      );
    }
  }

  @override
  Future<List<DebtModel>> getDebts() async {
    final sorted = List<DebtModel>.from(_debts)
      ..sort((a, b) {
        if (a.isSettled != b.isSettled) {
          return a.isSettled ? 1 : -1;
        }
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });
    return sorted;
  }

  @override
  Future<DebtModel> addDebt(DebtModel debt) async {
    final saved = debt.copyWith(id: _debtSeq++);
    _debts.add(saved);
    return saved;
  }

  @override
  Future<void> updateDebt(DebtModel debt) async {
    final idx = _debts.indexWhere((d) => d.id == debt.id);
    if (idx >= 0) {
      _debts[idx] = debt;
    }
  }

  @override
  Future<void> deleteDebt(int id) async {
    _debts.removeWhere((d) => d.id == id);
  }

  @override
  Future<void> recordDebtInstallment({
    required int debtId,
    required int payAmount,
    int? walletId,
    required DateTime timestamp,
  }) async {
    final idx = _debts.indexWhere((d) => d.id == debtId);
    if (idx < 0) {
      return;
    }
    final debt = _debts[idx];
    final effective = payAmount > debt.remainingAmount
        ? debt.remainingAmount
        : payAmount;
    if (effective <= 0) {
      return;
    }
    final nextRemaining = debt.remainingAmount - effective;
    _debts[idx] = debt.copyWith(
      remainingAmount: nextRemaining,
      status: nextRemaining <= 0 ? 'paid' : 'open',
    );
    if (walletId != null) {
      await addTransaction(
        debt.isReceivable
            ? TransactionModel(
                kind: TransactionKind.income,
                amount: effective,
                category: 'Pemasukan Lain',
                note: 'Pelunasan piutang: ${debt.personName}',
                walletId: walletId,
                transactionDate: timestamp,
                createdAt: timestamp,
              )
            : TransactionModel(
                kind: TransactionKind.expense,
                amount: effective,
                category: 'Tagihan & Utilitas',
                note: 'Cicilan hutang: ${debt.personName}',
                walletId: walletId,
                transactionDate: timestamp,
                createdAt: timestamp,
              ),
      );
    }
  }

  @override
  Future<String?> getSetting(String key) async => _settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  Future<Map<String, Object?>> exportSnapshot() async {
    final wallets = await getWallets();
    final transactions = await getTransactions();
    final globalBudget = await getGlobalMonthlyBudget();
    final categoryBudgets = await getCategoryBudgets();
    final goals = await getGoals();
    final bills = await getBills();
    final debts = await getDebts();

    return <String, Object?>{
      'app': 'saku_pro',
      'schema_version': 3,
      'exported_at': DateTime.now().toIso8601String(),
      'global_budget': globalBudget,
      'wallets': wallets.map((w) => w.toMap()).toList(),
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'category_budgets': categoryBudgets.map((b) => b.toMap()).toList(),
      'goals': goals.map((g) => g.toMap()).toList(),
      'bills': bills.map((b) => b.toMap()).toList(),
      'debts': debts.map((d) => d.toMap()).toList(),
    };
  }

  @override
  Future<void> restoreSnapshot(Map<String, Object?> snapshot) async {
    final rawWallets = (snapshot['wallets'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => WalletModel.fromMap(Map<String, Object?>.from(e as Map)))
        .toList();
    if (rawWallets.isEmpty) {
      throw const StorageException(
        'Backup tidak memiliki daftar dompet yang valid.',
      );
    }

    final rawTx = (snapshot['transactions'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (e) => TransactionModel.fromMap(Map<String, Object?>.from(e as Map)),
        )
        .toList();
    final rawCatBudgets =
        (snapshot['category_budgets'] as List<dynamic>? ?? <dynamic>[])
            .map(
              (e) => BudgetModel.fromMap(Map<String, Object?>.from(e as Map)),
            )
            .toList();
    final rawGoals = (snapshot['goals'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => GoalModel.fromMap(Map<String, Object?>.from(e as Map)))
        .toList();
    final rawBills = (snapshot['bills'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => BillModel.fromMap(Map<String, Object?>.from(e as Map)))
        .toList();
    final rawDebts = (snapshot['debts'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => DebtModel.fromMap(Map<String, Object?>.from(e as Map)))
        .toList();
    final globalBudget =
        (snapshot['global_budget'] as num?)?.toInt() ?? 3000000;

    _wallets
      ..clear()
      ..addAll(rawWallets);
    _transactions
      ..clear()
      ..addAll(rawTx);
    _budgets
      ..clear()
      ..add(
        BudgetModel(
          id: 1,
          category: 'GLOBAL',
          monthlyLimit: globalBudget,
          monthKey: 'ALL',
          createdAt: DateTime.now(),
        ),
      );
    var bSeq = 2;
    for (final b in rawCatBudgets) {
      if (b.category != 'GLOBAL') {
        _budgets.add(b.copyWith(id: bSeq++));
      }
    }
    _goals
      ..clear()
      ..addAll(rawGoals);
    _bills
      ..clear()
      ..addAll(rawBills);
    _debts
      ..clear()
      ..addAll(rawDebts);

    _walletSeq =
        (_wallets.fold<int>(0, (m, w) => (w.id ?? 0) > m ? w.id! : m)) + 1;
    _txSeq =
        (_transactions.fold<int>(0, (m, t) => (t.id ?? 0) > m ? t.id! : m)) + 1;
    _budgetSeq = bSeq;
    _goalSeq =
        (_goals.fold<int>(0, (m, g) => (g.id ?? 0) > m ? g.id! : m)) + 1;
    _billSeq =
        (_bills.fold<int>(0, (m, b) => (b.id ?? 0) > m ? b.id! : m)) + 1;
    _debtSeq =
        (_debts.fold<int>(0, (m, d) => (d.id ?? 0) > m ? d.id! : m)) + 1;
  }
}

class DatabaseHelper {
  DatabaseHelper._();

  static Future<SakuStore> openPreferredStore() async {
    if (kIsWeb) {
      final memory = InMemorySakuStore();
      await memory.init();
      return memory;
    }

    try {
      final sqlite = SqliteSakuStore();
      await sqlite.init();
      return sqlite;
    } catch (_) {
      // Fallback keeps desktop/headless previews working without sqflite FFI.
      final memory = InMemorySakuStore();
      await memory.init();
      return memory;
    }
  }
}

enum TransactionKind {
  expense('expense', 'Pengeluaran'),
  income('income', 'Pemasukan'),
  transfer('transfer', 'Transfer');

  const TransactionKind(this.code, this.label);

  final String code;
  final String label;

  static TransactionKind fromCode(String? raw) {
    for (final item in TransactionKind.values) {
      if (item.code == raw) {
        return item;
      }
    }
    return TransactionKind.expense;
  }
}

class TransactionModel {
  const TransactionModel({
    this.id,
    required this.kind,
    required this.amount,
    required this.category,
    required this.note,
    required this.walletId,
    this.toWalletId,
    required this.transactionDate,
    required this.createdAt,
  });

  final int? id;
  final TransactionKind kind;
  final int amount;
  final String category;
  final String note;
  final int walletId;
  final int? toWalletId;
  final DateTime transactionDate;
  final DateTime createdAt;

  String get displayTitle => note.trim().isNotEmpty ? note.trim() : category;

  TransactionModel copyWith({
    int? id,
    TransactionKind? kind,
    int? amount,
    String? category,
    String? note,
    int? walletId,
    int? toWalletId,
    bool clearToWallet = false,
    DateTime? transactionDate,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      walletId: walletId ?? this.walletId,
      toWalletId: clearToWallet ? null : (toWalletId ?? this.toWalletId),
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'type': kind.code,
      'amount': amount,
      'category': category,
      'note': note,
      'wallet_id': walletId,
      'to_wallet_id': kind == TransactionKind.transfer ? toWalletId : null,
      'transaction_date': transactionDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, Object?> map) {
    return TransactionModel(
      id: map['id'] as int?,
      kind: TransactionKind.fromCode(map['type'] as String?),
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      category: (map['category'] as String?) ?? 'Lainnya',
      note: (map['note'] as String?) ?? '',
      walletId: (map['wallet_id'] as num?)?.toInt() ?? 1,
      toWalletId: (map['to_wallet_id'] as num?)?.toInt(),
      transactionDate:
          DateTime.tryParse((map['transaction_date'] as String?) ?? '') ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

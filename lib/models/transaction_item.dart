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
    this.receiptDetail = '',
    this.receiptImagePath = '',
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
  final String receiptDetail;
  final String receiptImagePath;

  String get displayTitle => note.trim().isNotEmpty ? note.trim() : category;

  bool get hasReceiptDetail => receiptDetail.trim().isNotEmpty;

  bool get hasReceiptImage => receiptImagePath.trim().isNotEmpty;

  bool get hasReceiptInfo => hasReceiptDetail || hasReceiptImage;

  String get receiptDetailInline {
    if (!hasReceiptDetail) {
      return '';
    }
    return receiptDetail
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join(' | ');
  }

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
    String? receiptDetail,
    String? receiptImagePath,
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
      receiptDetail: receiptDetail ?? this.receiptDetail,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
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
      'receipt_detail': receiptDetail,
      'receipt_image_path': receiptImagePath,
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
      receiptDetail: (map['receipt_detail'] as String?) ?? '',
      receiptImagePath: (map['receipt_image_path'] as String?) ?? '',
    );
  }
}

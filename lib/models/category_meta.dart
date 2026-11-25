import 'package:material_ui/material_ui.dart';

import 'transaction_item.dart';

class CategoryMeta {
  const CategoryMeta({
    required this.name,
    required this.kind,
    required this.icon,
    required this.color,
  });

  final String name;
  final TransactionKind kind;
  final IconData icon;
  final Color color;
}

class CategoryCatalog {
  CategoryCatalog._();

  static const List<CategoryMeta> expenseCategories = <CategoryMeta>[
    CategoryMeta(
      name: 'Makan & Minum',
      kind: TransactionKind.expense,
      icon: Icons.restaurant_outlined,
      color: Color(0xFFD97706),
    ),
    CategoryMeta(
      name: 'Ngopi',
      kind: TransactionKind.expense,
      icon: Icons.local_cafe_outlined,
      color: Color(0xFF92400E),
    ),
    CategoryMeta(
      name: 'Transportasi',
      kind: TransactionKind.expense,
      icon: Icons.directions_car_outlined,
      color: Color(0xFF0284C7),
    ),
    CategoryMeta(
      name: 'Belanja',
      kind: TransactionKind.expense,
      icon: Icons.shopping_bag_outlined,
      color: Color(0xFF0F766E),
    ),
    CategoryMeta(
      name: 'Tagihan & Utilitas',
      kind: TransactionKind.expense,
      icon: Icons.receipt_long_outlined,
      color: Color(0xFFBE123C),
    ),
    CategoryMeta(
      name: 'Hiburan',
      kind: TransactionKind.expense,
      icon: Icons.movie_outlined,
      color: Color(0xFF7C3AED),
    ),
    CategoryMeta(
      name: 'Kesehatan',
      kind: TransactionKind.expense,
      icon: Icons.medical_services_outlined,
      color: Color(0xFF059669),
    ),
    CategoryMeta(
      name: 'Pendidikan & Kerja',
      kind: TransactionKind.expense,
      icon: Icons.menu_book_outlined,
      color: Color(0xFF1D4ED8),
    ),
    CategoryMeta(
      name: 'Keluarga & Sosial',
      kind: TransactionKind.expense,
      icon: Icons.people_outline_rounded,
      color: Color(0xFF9333EA),
    ),
    CategoryMeta(
      name: 'Tabungan & Target',
      kind: TransactionKind.expense,
      icon: Icons.savings_outlined,
      color: Color(0xFF0F766E),
    ),
    CategoryMeta(
      name: 'Lainnya',
      kind: TransactionKind.expense,
      icon: Icons.category_outlined,
      color: Color(0xFF475569),
    ),
  ];

  static const List<CategoryMeta> incomeCategories = <CategoryMeta>[
    CategoryMeta(
      name: 'Gaji',
      kind: TransactionKind.income,
      icon: Icons.payments_outlined,
      color: Color(0xFF047857),
    ),
    CategoryMeta(
      name: 'Bonus & THR',
      kind: TransactionKind.income,
      icon: Icons.card_giftcard_outlined,
      color: Color(0xFF0F766E),
    ),
    CategoryMeta(
      name: 'Bisnis & Freelance',
      kind: TransactionKind.income,
      icon: Icons.storefront_outlined,
      color: Color(0xFF0284C7),
    ),
    CategoryMeta(
      name: 'Investasi & Bunga',
      kind: TransactionKind.income,
      icon: Icons.trending_up_rounded,
      color: Color(0xFF1D4ED8),
    ),
    CategoryMeta(
      name: 'Cashback & Refund',
      kind: TransactionKind.income,
      icon: Icons.replay_rounded,
      color: Color(0xFFD97706),
    ),
    CategoryMeta(
      name: 'Pemasukan Lain',
      kind: TransactionKind.income,
      icon: Icons.add_card_outlined,
      color: Color(0xFF475569),
    ),
  ];

  static const CategoryMeta transferMeta = CategoryMeta(
    name: 'Transfer Dompet',
    kind: TransactionKind.transfer,
    icon: Icons.swap_horiz_rounded,
    color: Color(0xFF0369A1),
  );

  static List<CategoryMeta> forKind(TransactionKind kind) {
    switch (kind) {
      case TransactionKind.expense:
        return expenseCategories;
      case TransactionKind.income:
        return incomeCategories;
      case TransactionKind.transfer:
        return const <CategoryMeta>[transferMeta];
    }
  }

  static CategoryMeta resolve(TransactionKind kind, String categoryName) {
    if (kind == TransactionKind.transfer) {
      return transferMeta;
    }
    final list = forKind(kind);
    for (final item in list) {
      if (item.name.toLowerCase() == categoryName.toLowerCase()) {
        return item;
      }
    }
    return list.last;
  }
}

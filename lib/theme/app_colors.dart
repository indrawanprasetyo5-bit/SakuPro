import 'package:material_ui/material_ui.dart';

@immutable
class SakuColors extends ThemeExtension<SakuColors> {
  const SakuColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brandPrimary,
    required this.brandInteractive,
    required this.brandOnPrimary,
    required this.brandSoft,
    required this.heroStart,
    required this.heroEnd,
    required this.heroMutedText,
    required this.income,
    required this.incomeSoft,
    required this.expense,
    required this.expenseSoft,
    required this.warning,
    required this.warningSoft,
    required this.transfer,
    required this.transferSoft,
    required this.cardShadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color brandPrimary;
  final Color brandInteractive;
  final Color brandOnPrimary;
  final Color brandSoft;
  final Color heroStart;
  final Color heroEnd;
  final Color heroMutedText;
  final Color income;
  final Color incomeSoft;
  final Color expense;
  final Color expenseSoft;
  final Color warning;
  final Color warningSoft;
  final Color transfer;
  final Color transferSoft;
  final Color cardShadow;

  static const SakuColors light = SakuColors(
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F5F9),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF334155),
    textMuted: Color(0xFF64748B),
    brandPrimary: Color(0xFF0F766E),
    brandInteractive: Color(0xFF0F766E),
    brandOnPrimary: Color(0xFFFFFFFF),
    brandSoft: Color(0xFFCCFBF1),
    heroStart: Color(0xFF0F766E),
    heroEnd: Color(0xFF115E59),
    heroMutedText: Color(0xFFCCFBF1),
    income: Color(0xFF047857),
    incomeSoft: Color(0xFFECFDF5),
    expense: Color(0xFFBE123C),
    expenseSoft: Color(0xFFFFF1F2),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFFFBEB),
    transfer: Color(0xFF0369A1),
    transferSoft: Color(0xFFF0F9FF),
    cardShadow: Color(0x0A0F172A),
  );

  static const SakuColors dark = SakuColors(
    background: Color(0xFF0B1120),
    surface: Color(0xFF111827),
    surfaceMuted: Color(0xFF1E293B),
    surfaceElevated: Color(0xFF172033),
    border: Color(0xFF1E293B),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFCBD5E1),
    textMuted: Color(0xFF94A3B8),
    brandPrimary: Color(0xFF0F766E),
    brandInteractive: Color(0xFF2DD4BF),
    brandOnPrimary: Color(0xFFFFFFFF),
    brandSoft: Color(0xFF134E4A),
    heroStart: Color(0xFF0F766E),
    heroEnd: Color(0xFF0D4F4B),
    heroMutedText: Color(0xFFCCFBF1),
    income: Color(0xFF34D399),
    incomeSoft: Color(0xFF064E3B),
    expense: Color(0xFFFB7185),
    expenseSoft: Color(0xFF4C0519),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF451A03),
    transfer: Color(0xFF38BDF8),
    transferSoft: Color(0xFF0C4A6E),
    cardShadow: Color(0x33000000),
  );

  @override
  SakuColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceElevated,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? brandPrimary,
    Color? brandInteractive,
    Color? brandOnPrimary,
    Color? brandSoft,
    Color? heroStart,
    Color? heroEnd,
    Color? heroMutedText,
    Color? income,
    Color? incomeSoft,
    Color? expense,
    Color? expenseSoft,
    Color? warning,
    Color? warningSoft,
    Color? transfer,
    Color? transferSoft,
    Color? cardShadow,
  }) {
    return SakuColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandInteractive: brandInteractive ?? this.brandInteractive,
      brandOnPrimary: brandOnPrimary ?? this.brandOnPrimary,
      brandSoft: brandSoft ?? this.brandSoft,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      heroMutedText: heroMutedText ?? this.heroMutedText,
      income: income ?? this.income,
      incomeSoft: incomeSoft ?? this.incomeSoft,
      expense: expense ?? this.expense,
      expenseSoft: expenseSoft ?? this.expenseSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      transfer: transfer ?? this.transfer,
      transferSoft: transferSoft ?? this.transferSoft,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  SakuColors lerp(ThemeExtension<SakuColors>? other, double t) {
    if (other is! SakuColors) {
      return this;
    }
    return SakuColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandInteractive: Color.lerp(brandInteractive, other.brandInteractive, t)!,
      brandOnPrimary: Color.lerp(brandOnPrimary, other.brandOnPrimary, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      heroMutedText: Color.lerp(heroMutedText, other.heroMutedText, t)!,
      income: Color.lerp(income, other.income, t)!,
      incomeSoft: Color.lerp(incomeSoft, other.incomeSoft, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseSoft: Color.lerp(expenseSoft, other.expenseSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      transferSoft: Color.lerp(transferSoft, other.transferSoft, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
    );
  }
}

extension SakuThemeContext on BuildContext {
  SakuColors get saku =>
      Theme.of(this).extension<SakuColors>() ?? SakuColors.light;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

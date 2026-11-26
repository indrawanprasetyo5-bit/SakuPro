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
    required this.goldAccent,
    required this.goldSoft,
    required this.heroStart,
    required this.heroMid,
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
  final Color goldAccent;
  final Color goldSoft;
  final Color heroStart;
  final Color heroMid;
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
    background: Color(0xFFF6F8F7),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEEF3F1),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFE1E8E6),
    textPrimary: Color(0xFF0A1715),
    textSecondary: Color(0xFF334744),
    textMuted: Color(0xFF5D706C),
    brandPrimary: Color(0xFF0F766E),
    brandInteractive: Color(0xFF0F766E),
    brandOnPrimary: Color(0xFFFFFFFF),
    brandSoft: Color(0xFFD6F5EF),
    goldAccent: Color(0xFFC59D47),
    goldSoft: Color(0xFFFCF6E6),
    heroStart: Color(0xFF082F2E),
    heroMid: Color(0xFF0E5E58),
    heroEnd: Color(0xFF072526),
    heroMutedText: Color(0xFFC7ECE7),
    income: Color(0xFF047857),
    incomeSoft: Color(0xFFECFDF5),
    expense: Color(0xFFBE123C),
    expenseSoft: Color(0xFFFFF1F2),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFFFBEB),
    transfer: Color(0xFF0369A1),
    transferSoft: Color(0xFFF0F9FF),
    cardShadow: Color(0x0D0A1715),
  );

  static const SakuColors dark = SakuColors(
    background: Color(0xFF070C15),
    surface: Color(0xFF0E1624),
    surfaceMuted: Color(0xFF162235),
    surfaceElevated: Color(0xFF131E30),
    border: Color(0xFF1E2D42),
    textPrimary: Color(0xFFF3F7F6),
    textSecondary: Color(0xFFC6D3D1),
    textMuted: Color(0xFF8FA3A0),
    brandPrimary: Color(0xFF0F766E),
    brandInteractive: Color(0xFF2DD4BF),
    brandOnPrimary: Color(0xFFFFFFFF),
    brandSoft: Color(0xFF123B38),
    goldAccent: Color(0xFFDFB969),
    goldSoft: Color(0xFF2A2315),
    heroStart: Color(0xFF083534),
    heroMid: Color(0xFF0F6B64),
    heroEnd: Color(0xFF061F22),
    heroMutedText: Color(0xFFC7ECE7),
    income: Color(0xFF34D399),
    incomeSoft: Color(0xFF07382B),
    expense: Color(0xFFFB7185),
    expenseSoft: Color(0xFF3E0B18),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF3A1C07),
    transfer: Color(0xFF38BDF8),
    transferSoft: Color(0xFF0B3552),
    cardShadow: Color(0x4D000000),
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
    Color? goldAccent,
    Color? goldSoft,
    Color? heroStart,
    Color? heroMid,
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
      goldAccent: goldAccent ?? this.goldAccent,
      goldSoft: goldSoft ?? this.goldSoft,
      heroStart: heroStart ?? this.heroStart,
      heroMid: heroMid ?? this.heroMid,
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
      goldAccent: Color.lerp(goldAccent, other.goldAccent, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroMid: Color.lerp(heroMid, other.heroMid, t)!,
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

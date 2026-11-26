import 'package:material_ui/material_ui.dart';

@immutable
class SakuColors extends ThemeExtension<SakuColors> {
  const SakuColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.border,
    required this.borderStrong,
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
  final Color borderStrong;
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
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF4F4F5),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0x1409090B),
    borderStrong: Color(0x2409090B),
    textPrimary: Color(0xFF09090B),
    textSecondary: Color(0xFF52525B),
    textMuted: Color(0xFF63636E),
    brandPrimary: Color(0xFF047857),
    brandInteractive: Color(0xFF047857),
    brandOnPrimary: Color(0xFFFFFFFF),
    brandSoft: Color(0xFFECFDF5),
    goldAccent: Color(0xFFB45309),
    goldSoft: Color(0xFFFFFBEB),
    heroStart: Color(0xFF18181B),
    heroMid: Color(0xFF121216),
    heroEnd: Color(0xFF09090B),
    heroMutedText: Color(0xFFA1A1AA),
    income: Color(0xFF047857),
    incomeSoft: Color(0xFFECFDF5),
    expense: Color(0xFFE11D48),
    expenseSoft: Color(0xFFFFF1F2),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFFFBEB),
    transfer: Color(0xFF0284C7),
    transferSoft: Color(0xFFF0F9FF),
    cardShadow: Color(0x0D09090B),
  );

  // Obsidian Dark tokens: #09090B canvas, #18181B card, #27272A elevated,
  // 1px rgba(255,255,255,0.08) hairline border, and WCAG AA semantic accents.
  static const SakuColors dark = SakuColors(
    background: Color(0xFF09090B),
    surface: Color(0xFF18181B),
    surfaceMuted: Color(0xFF27272A),
    surfaceElevated: Color(0xFF27272A),
    border: Color(0x14FFFFFF),
    borderStrong: Color(0x24FFFFFF),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF9A9AA6),
    brandPrimary: Color(0xFF10B981),
    brandInteractive: Color(0xFF10B981),
    brandOnPrimary: Color(0xFF09090B),
    brandSoft: Color(0xFF0B2920),
    goldAccent: Color(0xFFF59E0B),
    goldSoft: Color(0xFF2B1F0A),
    heroStart: Color(0xFF1E1E24),
    heroMid: Color(0xFF141418),
    heroEnd: Color(0xFF0B0B0E),
    heroMutedText: Color(0xFFA1A1AA),
    income: Color(0xFF10B981),
    incomeSoft: Color(0xFF0B2920),
    expense: Color(0xFFF43F5E),
    expenseSoft: Color(0xFF240F15),
    warning: Color(0xFFF59E0B),
    warningSoft: Color(0xFF2B1F0A),
    transfer: Color(0xFF38BDF8),
    transferSoft: Color(0xFF0C2538),
    cardShadow: Color(0x66000000),
  );

  @override
  SakuColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceElevated,
    Color? border,
    Color? borderStrong,
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
      borderStrong: borderStrong ?? this.borderStrong,
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
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
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
      Theme.of(this).extension<SakuColors>() ?? SakuColors.dark;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

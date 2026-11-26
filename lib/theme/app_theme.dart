import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Manrope';

  static const List<FontFeature> tabularNums = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static ThemeData light() => _build(Brightness.light, SakuColors.light);

  static ThemeData dark() => _build(Brightness.dark, SakuColors.dark);

  static ThemeData _build(Brightness brightness, SakuColors palette) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.brandInteractive,
      onPrimary: isDark ? const Color(0xFF042F2E) : palette.brandOnPrimary,
      primaryContainer: palette.brandSoft,
      onPrimaryContainer: isDark
          ? const Color(0xFFCCFBF1)
          : const Color(0xFF0F766E),
      secondary: palette.brandPrimary,
      onSecondary: palette.brandOnPrimary,
      secondaryContainer: palette.surfaceMuted,
      onSecondaryContainer: palette.textPrimary,
      error: palette.expense,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.border,
      outlineVariant: palette.border,
    );

    final baseText = Typography.material2021().black.apply(
      fontFamily: fontFamily,
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      extensions: <ThemeExtension<dynamic>>[palette],
      textTheme: baseText.copyWith(
        displaySmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          height: 1.15,
          color: palette.textPrimary,
          fontFeatures: tabularNums,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: 1.2,
          color: palette.textPrimary,
          fontFeatures: tabularNums,
        ),
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 17.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.3,
          color: palette.textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.15,
          height: 1.35,
          color: palette.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          height: 1.48,
          color: palette.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.48,
          color: palette.textSecondary,
        ),
        labelLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
          height: 1.2,
          color: palette.textPrimary,
        ),
        labelSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: palette.textMuted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: palette.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceMuted,
        selectedColor: palette.brandSoft,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 14,
        ),
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          color: palette.textMuted,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: palette.textSecondary,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.brandInteractive, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.expense),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF162235)
            : const Color(0xFF0A1715),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Color(0xFFF3F7F6),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: 0.56),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.border),
        ),
      ),
    );
  }
}

extension TabularTextExtension on TextStyle {
  TextStyle get tabular => copyWith(fontFeatures: AppTheme.tabularNums);
}

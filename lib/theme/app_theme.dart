import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

abstract final class SakuRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;
}

abstract final class SakuSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class SakuMotion {
  static const Duration press = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration emphasis = Duration(milliseconds: 360);

  static const Curve curveOut = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.easeOutBack;

  static const SpringDescription springTactile = SpringDescription(
    mass: 1.0,
    stiffness: 420.0,
    damping: 28.0,
  );

  static const SpringDescription springFluid = SpringDescription(
    mass: 1.0,
    stiffness: 220.0,
    damping: 26.0,
  );

  static const AnimationStyle sheetStyle = AnimationStyle(
    duration: Duration(milliseconds: 320),
    reverseDuration: Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
}

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
      onPrimary: palette.brandOnPrimary,
      primaryContainer: palette.brandSoft,
      onPrimaryContainer: palette.brandInteractive,
      secondary: palette.transfer,
      onSecondary: isDark ? const Color(0xFF09090B) : Colors.white,
      secondaryContainer: palette.surfaceMuted,
      onSecondaryContainer: palette.textPrimary,
      tertiary: palette.warning,
      onTertiary: const Color(0xFF09090B),
      tertiaryContainer: palette.warningSoft,
      onTertiaryContainer: palette.warning,
      error: palette.expense,
      onError: Colors.white,
      errorContainer: palette.expenseSoft,
      onErrorContainer: palette.expense,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      surfaceContainerLowest: palette.background,
      surfaceContainerLow: palette.surface,
      surfaceContainer: palette.surface,
      surfaceContainerHigh: palette.surfaceElevated,
      surfaceContainerHighest: palette.surfaceMuted,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.borderStrong,
      outlineVariant: palette.border,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );

    final baseText =
        (isDark
                ? Typography.material2021().white
                : Typography.material2021().black)
            .apply(
              fontFamily: fontFamily,
              bodyColor: palette.textPrimary,
              displayColor: palette.textPrimary,
            );

    // Tabular figures are enabled across the global type scale so currency,
    // percentages, and counters align cleanly without horizontal jitter.
    final textTheme = baseText.copyWith(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
        height: 1.08,
        color: palette.textPrimary,
        fontFeatures: tabularNums,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        height: 1.1,
        color: palette.textPrimary,
        fontFeatures: tabularNums,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.12,
        color: palette.textPrimary,
        fontFeatures: tabularNums,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.16,
        color: palette.textPrimary,
        fontFeatures: tabularNums,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.18,
        color: palette.textPrimary,
        fontFeatures: tabularNums,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.22,
        color: palette.textPrimary,
        fontFeatures: tabularNums,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.28,
        color: palette.textPrimary,
        fontFeatures: tabularNums,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.32,
        color: palette.textPrimary,
        fontFeatures: tabularNums,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        height: 1.32,
        color: palette.textPrimary,
        fontFeatures: tabularNums,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: palette.textPrimary,
        fontFeatures: tabularNums,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: palette.textSecondary,
        fontFeatures: tabularNums,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: palette.textMuted,
        fontFeatures: tabularNums,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        height: 1.2,
        color: palette.textPrimary,
        fontFeatures: tabularNums,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: palette.textSecondary,
        fontFeatures: tabularNums,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: palette.textMuted,
        fontFeatures: tabularNums,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[palette],
      textTheme: textTheme,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.brandInteractive,
        selectionColor: palette.brandInteractive.withValues(alpha: 0.24),
        selectionHandleColor: palette.brandInteractive,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: palette.textPrimary,
          fontFeatures: tabularNums,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SakuRadius.lg),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceMuted,
        selectedColor: palette.brandSoft,
        side: BorderSide(color: palette.border, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SakuRadius.sm),
        ),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
          fontFeatures: tabularNums,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SakuSpace.lg,
          vertical: 14,
        ),
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          color: palette.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFeatures: tabularNums,
        ),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: palette.textSecondary,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SakuRadius.md),
          borderSide: BorderSide(color: palette.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SakuRadius.md),
          borderSide: BorderSide(color: palette.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SakuRadius.md),
          borderSide: BorderSide(color: palette.brandInteractive, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SakuRadius.md),
          borderSide: BorderSide(color: palette.expense, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SakuRadius.md),
          borderSide: BorderSide(color: palette.expense, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.brandPrimary,
          foregroundColor: palette.brandOnPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SakuRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
            fontFeatures: tabularNums,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          side: BorderSide(color: palette.borderStrong, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SakuRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            fontFeatures: tabularNums,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.brandInteractive,
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            fontFeatures: tabularNums,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.brandOnPrimary;
          }
          return palette.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.brandInteractive;
          }
          return palette.surfaceMuted;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return palette.borderStrong;
        }),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: palette.brandInteractive,
        labelColor: palette.textPrimary,
        unselectedLabelColor: palette.textMuted,
        dividerColor: palette.border,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          fontFeatures: tabularNums,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          fontFeatures: tabularNums,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        backgroundColor: isDark
            ? palette.surfaceElevated
            : const Color(0xFF18181B),
        actionTextColor: const Color(0xFF10B981),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Color(0xFFFAFAFA),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFeatures: tabularNums,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SakuRadius.md),
          side: BorderSide(
            color: isDark ? palette.border : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: palette.borderStrong,
        dragHandleSize: const Size(38, 4),
        clipBehavior: Clip.antiAlias,
        modalBarrierColor: Colors.black.withValues(alpha: isDark ? 0.72 : 0.48),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SakuRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SakuRadius.xl),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SakuRadius.md),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
    );
  }
}

extension TabularTextExtension on TextStyle {
  TextStyle get tabular => copyWith(fontFeatures: AppTheme.tabularNums);
}

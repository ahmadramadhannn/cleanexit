import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// CleanExit visual language — "dark & secure".
/// Charcoal surfaces, teal accent, monospace numerics.
abstract final class CeColors {
  static const Color bg = Color(0xFF14181D);
  static const Color surface = Color(0xFF1C2128);
  static const Color surfaceHigh = Color(0xFF232A33);
  static const Color border = Color(0xFF2A313A);
  static const Color textPrimary = Color(0xFFE6EAEE);
  static const Color textSecondary = Color(0xFF8B95A1);
  static const Color accent = Color(0xFF2DD4BF);
  static const Color accentDim = Color(0xFF17453F);
  static const Color danger = Color(0xFFF87171);
  static const Color dangerDim = Color(0xFF4A2325);
  static const Color warning = Color(0xFFFBBF24);
  static const Color success = Color(0xFF34D399);
}

/// Monospace style for numbers, sizes and paths (falls back gracefully
/// to whatever monospace face the OS ships — no bundled font needed).
abstract final class CeText {
  static const List<String> _monoFallback = [
    'JetBrains Mono',
    'Consolas',
    'DejaVu Sans Mono',
    'Courier New',
    'monospace',
  ];

  static TextStyle mono({
    double? size,
    FontWeight? weight,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: _monoFallback.first,
      fontFamilyFallback: _monoFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}

ThemeData buildCleanExitTheme() {
  const scheme = ColorScheme.dark(
    primary: CeColors.accent,
    onPrimary: Color(0xFF06201C),
    secondary: CeColors.accent,
    onSecondary: Color(0xFF06201C),
    surface: CeColors.surface,
    onSurface: CeColors.textPrimary,
    error: CeColors.danger,
    onError: Color(0xFF2B0E0E),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: CeColors.bg,
  );

  return base.copyWith(
    dividerColor: CeColors.border,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: CeColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        color: CeColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: CeColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: CeColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: CeColors.border, space: 1),
    textTheme: base.textTheme.apply(
      bodyColor: CeColors.textPrimary,
      displayColor: CeColors.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CeColors.surfaceHigh,
      hintStyle: const TextStyle(color: CeColors.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: CeColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: CeColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: CeColors.accent, width: 1.4),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return CeColors.accent;
        return Colors.transparent;
      }),
      side: const BorderSide(color: CeColors.textSecondary, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? CeColors.bg : CeColors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? CeColors.accent : CeColors.surfaceHigh,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: CeColors.surfaceHigh,
      side: const BorderSide(color: CeColors.border),
      labelStyle: const TextStyle(color: CeColors.textPrimary, fontSize: 12.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CeColors.accent,
        foregroundColor: const Color(0xFF06201C),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CeColors.textPrimary,
        side: const BorderSide(color: CeColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CeColors.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: CeColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: CeColors.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: CeColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: CeColors.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CeColors.accent,
      linearTrackColor: CeColors.surfaceHigh,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: CeColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CeColors.border),
      ),
      textStyle: const TextStyle(color: CeColors.textPrimary, fontSize: 12),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: CeColors.bg,
      indicatorColor: CeColors.accentDim,
      selectedIconTheme: const IconThemeData(color: CeColors.accent),
      unselectedIconTheme: const IconThemeData(color: CeColors.textSecondary),
      selectedLabelTextStyle: const TextStyle(
        color: CeColors.accent,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: CeColors.textSecondary,
        fontSize: 12,
      ),
    ),
  );
}

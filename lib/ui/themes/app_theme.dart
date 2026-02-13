import 'package:flutter/material.dart';
import '../design_system/app_theme_extensions.dart';
import '../design_system/app_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppTokens.accent,
      onPrimary: Colors.white,
      secondary: AppTokens.ink,
      onSecondary: Colors.white,
      error: AppTokens.danger,
      onError: Colors.white,
      surface: AppTokens.paper,
      onSurface: AppTokens.ink,
      tertiary: AppTokens.warning,
      onTertiary: Colors.white,
      primaryContainer: AppTokens.accentSoft,
      onPrimaryContainer: AppTokens.accent,
      secondaryContainer: AppTokens.paperAlt,
      onSecondaryContainer: AppTokens.ink,
      errorContainer: AppTokens.danger.withValues(alpha: 0.08),
      onErrorContainer: AppTokens.danger,
      surfaceContainerHighest: AppTokens.paperAlt,
      onSurfaceVariant: AppTokens.mutedText,
      outline: AppTokens.line,
      outlineVariant: AppTokens.lineStrong,
      shadow: Colors.transparent,
      scrim: AppTokens.ink.withValues(alpha: 0.4),
      inverseSurface: AppTokens.ink,
      onInverseSurface: Colors.white,
      inversePrimary: AppTokens.accentSoft,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppTokens.paper,
      fontFamily: 'SpaceGrotesk',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkRipple.splashFactory,
      shadowColor: Colors.transparent,
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.3,
      ),
      displayMedium: base.textTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
      ),
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppTokens.mutedText,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      extensions: const [AppThemeExtras.light],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppTokens.paper,
        foregroundColor: AppTokens.ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppTokens.ink,
          fontWeight: FontWeight.w800,
        ),
        toolbarHeight: 54,
        shape: const Border(
          bottom: BorderSide(color: AppTokens.line, width: AppTokens.border),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppTokens.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          side: const BorderSide(color: AppTokens.line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppTokens.line,
        thickness: AppTokens.border,
        space: AppTokens.border,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.paperAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppTokens.mutedText),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppTokens.mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          borderSide: const BorderSide(color: AppTokens.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          borderSide: const BorderSide(color: AppTokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          borderSide: const BorderSide(
              color: AppTokens.accent, width: AppTokens.borderStrong),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          borderSide: const BorderSide(color: AppTokens.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          borderSide: const BorderSide(
              color: AppTokens.danger, width: AppTokens.borderStrong),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: AppTokens.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.ink,
          side: const BorderSide(color: AppTokens.line),
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusM),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppTokens.accent,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusS),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        backgroundColor: AppTokens.accent,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTokens.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          side: const BorderSide(color: AppTokens.lineStrong),
        ),
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        iconColor: AppTokens.ink,
        textColor: AppTokens.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppTokens.accent,
        linearTrackColor: AppTokens.paperAlt,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppTokens.accent;
          return AppTokens.paper;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return AppTokens.accentSoft;
          return AppTokens.line;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: AppTokens.lineStrong),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppTokens.accent;
          return AppTokens.paper;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppTokens.accent;
          return AppTokens.lineStrong;
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppTokens.paper,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          side: const BorderSide(color: AppTokens.line),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppTokens.accent, width: 2),
        ),
        labelColor: AppTokens.accent,
        unselectedLabelColor: AppTokens.mutedText,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: AppTokens.paper,
        indicatorColor: AppTokens.accentSoft,
        height: 62,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? AppTokens.accent : AppTokens.mutedText,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: AppTokens.paper,
        indicatorColor: AppTokens.accentSoft,
        selectedIconTheme:
            const IconThemeData(color: AppTokens.accent, size: 22),
        unselectedIconTheme:
            const IconThemeData(color: AppTokens.mutedText, size: 21),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AppTokens.accent,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AppTokens.mutedText,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: AppTokens.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusL),
          ),
          side: BorderSide(color: AppTokens.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: AppTokens.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusL),
          side: const BorderSide(color: AppTokens.line),
        ),
      ),
    );
  }
}

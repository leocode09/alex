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
      errorContainer: const Color(0x14C62828),
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

    return _buildTheme(
      scheme: scheme,
      extras: AppThemeExtras.light,
    );
  }

  static ThemeData get darkTheme {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppTokens.accent,
      onPrimary: const Color(0xFF120900),
      secondary: const Color(0xFFE9E9E9),
      onSecondary: const Color(0xFF121212),
      error: const Color(0xFFFF7878),
      onError: const Color(0xFF260000),
      surface: const Color(0xFF101010),
      onSurface: const Color(0xFFF1F1F1),
      tertiary: const Color(0xFFFFAE4C),
      onTertiary: const Color(0xFF2A1600),
      primaryContainer: const Color(0xFF4A2A10),
      onPrimaryContainer: const Color(0xFFFFCDA2),
      secondaryContainer: const Color(0xFF1D1D1D),
      onSecondaryContainer: const Color(0xFFF1F1F1),
      errorContainer: const Color(0xFF5A2626),
      onErrorContainer: const Color(0xFFFFD2D2),
      surfaceContainerHighest: const Color(0xFF1F1F1F),
      onSurfaceVariant: const Color(0xFFB8B8B8),
      outline: const Color(0xFF343434),
      outlineVariant: const Color(0xFF5C5C5C),
      shadow: Colors.transparent,
      scrim: Colors.black.withValues(alpha: 0.6),
      inverseSurface: const Color(0xFFEDEDED),
      onInverseSurface: const Color(0xFF111111),
      inversePrimary: const Color(0xFFFF9B4D),
      surfaceTint: Colors.transparent,
    );

    return _buildTheme(
      scheme: scheme,
      extras: AppThemeExtras.dark,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required AppThemeExtras extras,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
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
        color: scheme.onSurfaceVariant,
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
      extensions: [extras],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        toolbarHeight: 54,
        shape: Border(
          bottom: BorderSide(color: extras.border, width: AppTokens.border),
        ),
      ),
      cardTheme: CardThemeData(
        color: extras.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          side: BorderSide(color: extras.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: extras.border,
        thickness: AppTokens.border,
        space: AppTokens.border,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: extras.panelAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          borderSide: BorderSide(color: extras.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          borderSide: BorderSide(color: extras.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          borderSide: BorderSide(
            color: scheme.primary,
            width: AppTokens.borderStrong,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          borderSide: BorderSide(
            color: scheme.error,
            width: AppTokens.borderStrong,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
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
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: extras.border),
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
          foregroundColor: scheme.primary,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusS),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          side: BorderSide(color: extras.borderStrong),
        ),
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        iconColor: scheme.onSurface,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: extras.panelAlt,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return extras.panel;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return extras.accentSoft;
          }
          return extras.border;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: extras.borderStrong),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return extras.panel;
        }),
        checkColor: WidgetStatePropertyAll<Color>(scheme.onPrimary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return extras.borderStrong;
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: extras.panel,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusM),
          side: BorderSide(color: extras.border),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: scheme.surface,
        indicatorColor: extras.accentSoft,
        height: 62,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: extras.accentSoft,
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 22),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 21,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusL),
          ),
          side: BorderSide(color: extras.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusL),
          side: BorderSide(color: extras.border),
        ),
      ),
    );
  }
}

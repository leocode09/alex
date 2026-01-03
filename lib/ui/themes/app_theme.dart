import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors - Using ONLY Amber SAE and Green Pantone
  static const Color amberSae = Color(0xFFFC8019); // Primary brand color
  static const Color greenPantone = Color(0xFF09AA29); // Success/secondary color
  
  // Derived colors for beautiful UI
  static const Color amberLight = Color(0xFFFFF3E0);
  static const Color amberDark = Color(0xFFE65100);
  static const Color greenLight = Color(0xFFE8F5E9);
  static const Color greenDark = Color(0xFF087F23);
  
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: amberSae,
      onPrimary: Colors.white,
      primaryContainer: amberLight,
      onPrimaryContainer: amberDark,
      
      secondary: greenPantone,
      onSecondary: Colors.white,
      secondaryContainer: greenLight,
      onSecondaryContainer: greenDark,
      
      tertiary: amberSae,
      onTertiary: Colors.white,
      
      error: amberDark,
      onError: Colors.white,
      errorContainer: amberLight,
      onErrorContainer: amberDark,
      
      background: Colors.white,
      onBackground: const Color(0xFF1C1B1F),
      
      surface: Colors.white,
      onSurface: const Color(0xFF1C1B1F),
      surfaceVariant: const Color(0xFFF5F5F5),
      onSurfaceVariant: const Color(0xFF49454F),
      
      outline: const Color(0xFFCAC4D0),
      outlineVariant: const Color(0xFFE7E0EC),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1C1B1F),
        surfaceTintColor: Colors.transparent,
      ),
      
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: amberSae,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: greenPantone,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: amberSae,
          side: const BorderSide(color: amberSae, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: amberSae,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      chipTheme: ChipThemeData(
        backgroundColor: amberLight,
        labelStyle: const TextStyle(color: amberDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: amberSae, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      dividerTheme: const DividerThemeData(
        space: 1,
        thickness: 1,
        color: Color(0xFFE7E0EC),
      ),
      
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: amberLight,
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: amberSae);
          }
          return const IconThemeData(color: Color(0xFF49454F));
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: amberSae, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: Color(0xFF49454F));
        }),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: amberSae,
      onPrimary: Colors.white,
      primaryContainer: amberDark,
      onPrimaryContainer: amberLight,
      
      secondary: greenPantone,
      onSecondary: Colors.white,
      secondaryContainer: greenDark,
      onSecondaryContainer: greenLight,
      
      tertiary: amberSae,
      onTertiary: Colors.white,
      
      error: amberSae,
      onError: Colors.white,
      errorContainer: amberDark,
      onErrorContainer: amberLight,
      
      background: const Color(0xFF1C1B1F),
      onBackground: const Color(0xFFE6E1E5),
      
      surface: const Color(0xFF1C1B1F),
      onSurface: const Color(0xFFE6E1E5),
      surfaceVariant: const Color(0xFF49454F),
      onSurfaceVariant: const Color(0xFFCAC4D0),
      
      outline: const Color(0xFF938F99),
      outlineVariant: const Color(0xFF49454F),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF1C1B1F),
      
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFF1C1B1F),
        foregroundColor: Color(0xFFE6E1E5),
        surfaceTintColor: Colors.transparent,
      ),
      
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: const Color(0xFF2B2930),
        surfaceTintColor: Colors.transparent,
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: amberSae,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: greenPantone,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: amberSae,
          side: const BorderSide(color: amberSae, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: amberSae,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      chipTheme: ChipThemeData(
        backgroundColor: amberDark,
        labelStyle: const TextStyle(color: amberLight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2B2930),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: amberSae, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      dividerTheme: const DividerThemeData(
        space: 1,
        thickness: 1,
        color: Color(0xFF49454F),
      ),
      
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1C1B1F),
        indicatorColor: amberDark,
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: amberSae);
          }
          return const IconThemeData(color: Color(0xFFCAC4D0));
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: amberSae, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: Color(0xFFCAC4D0));
        }),
      ),
    );
  }
}

// Extension for easy access to brand colors
extension CustomColors on ColorScheme {
  Color get amber => AppTheme.amberSae;
  Color get green => AppTheme.greenPantone;
  Color get success => AppTheme.greenPantone;
  Color get warning => AppTheme.amberSae;
  
  Color get amberLight => AppTheme.amberLight;
  Color get amberDark => AppTheme.amberDark;
  Color get greenLight => AppTheme.greenLight;
  Color get greenDark => AppTheme.greenDark;
  
  // Container colors for compatibility
  Color get successContainer => AppTheme.greenLight;
  Color get warningContainer => AppTheme.amberLight;
  Color get errorContainer => AppTheme.amberLight;
  
  Color get onSuccess => Colors.white;
  Color get onWarning => Colors.white;
}

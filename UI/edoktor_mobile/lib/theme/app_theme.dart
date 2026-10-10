import 'dart:ui';
import 'package:flutter/material.dart';

/// Light-green palette shared by every screen of the patient app.
class AppColors {
  static const primary = Color(0xFF2E7D32);
  static const primaryMid = Color(0xFF388E3C);
  static const primaryLight = Color(0xFF4CAF50);
  static const deep = Color(0xFF1B5E20);
  static const mint = Color(0xFFB9F6CA);
  static const mintLight = Color(0xFFDCFCE4);
  static const tint = Color(0xFFE3F4E5);
  static const tint2 = Color(0xFFF0F9F1);
  static const bg = Color(0xFFF1F6F2);
  static const ink = Color(0xFF1D2433);
  static const muted = Color(0xFF6B7385);
  static const line = Color(0xFFE4EBE6);
  static const star = Color(0xFFF5B301);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primaryMid, primary],
    stops: [0, 0.55, 1],
  );

  static const softShadow = [BoxShadow(color: Color(0x0F142346), blurRadius: 14, offset: Offset(0, 4))];
  static const glowShadow = [BoxShadow(color: Color(0x552E7D32), blurRadius: 20, offset: Offset(0, 8))];
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary, surface: Colors.white);
  final rounded14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  OutlineInputBorder border(Color c, [double w = 1.5]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        shape: rounded14,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.line, width: 1.5),
        shape: rounded14,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.primary)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.primary),
      errorBorder: border(Colors.red.shade300),
      focusedErrorBorder: border(Colors.red),
      prefixIconColor: AppColors.muted,
    ),
    tabBarTheme: const TabBarThemeData(labelColor: Colors.white, unselectedLabelColor: Colors.white70, indicatorColor: AppColors.mint),
    dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Lets horizontal lists (days, chips) be dragged with a mouse too, which matters when testing in Chrome.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

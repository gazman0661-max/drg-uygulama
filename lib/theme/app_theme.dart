import 'package:flutter/material.dart';

/// ==========================================================
/// TASARIM TOKENLARI
/// Orijinal HTML'deki :root { --ink, --deep, --gold ... } CSS
/// değişkenlerinin birebir Flutter karşılığıdır.
/// ==========================================================
class AppColors {
  AppColors._();

  static const ink = Color(0xFF123A34); // koyu zümrüt - başlıklar, metin
  static const deep = Color(0xFF0D2B27); // en koyu zümrüt - üst bar, gece zemin
  static const gold = Color(0xFFC7A24B); // pirinç/altın - vurgu
  static const goldSoft = Color(0xFFE8D9AE); // soluk altın - ince çizgiler
  static const ivory = Color(0xFFF7F2E7); // sedef - kart zeminleri
  static const paper = Color(0xFFFBF8F1); // sayfa zemini
  static const danger = Color(0xFF7A2E2E);
}

class AppRadius {
  AppRadius._();
  static const card = 16.0;
}

/// Fontlar (Amiri: başlıklar, Cormorant Garamond: Hicri tarih, Inter: gövde)
/// assets/fonts/ içinde paketlidir ve pubspec.yaml'daki `fonts:` bloğundan
/// yüklenir; internet gerektirmez.
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      primary: AppColors.ink,
      secondary: AppColors.gold,
      surface: AppColors.paper,
    ),
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.deep,
      foregroundColor: AppColors.ivory,
      elevation: 4,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Amiri',
        fontSize: 24,
        color: AppColors.ivory,
        letterSpacing: 0.5,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.deep : null),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.gold : null),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.deep,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: AppColors.goldSoft,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.deep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
  );
}

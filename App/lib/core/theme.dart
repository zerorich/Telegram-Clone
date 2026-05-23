import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const teal = Color(0xFF2AABEE);
  static const tealDark = Color(0xFF229ED9);
  static const tealLight = Color(0xFF5DC8F5);
  static const unreadBadge = Color(0xFF2AABEE);

  // Telegram-accurate dark navy theme
  static const darkBg = Color(0xFF0E1621);
  static const darkList = Color(0xFF0E1621);
  static const darkAppBar = Color(0xFF17212B);
  static const darkChatBg = Color(0xFF0E1621);
  static const darkDrawer = Color(0xFF17212B);
  static const darkDrawerHeader = Color(0xFF1A2638);
  static const darkBubbleReceived = Color(0xFF182533);
  static const darkBubbleMine = Color(0xFF2B5278);
  static const darkInput = Color(0xFF17212B);
  static const dateChipBg = Color(0xFF182533);
  static const darkSubtitle = Color(0xFF708499);
  static const darkDivider = Color(0xFF0A1520);
  static const darkTileHighlight = Color(0xFF17212B);
  static const darkTileActive = Color(0xFF1E2E40);

  static const lightBg = Color(0xFFFFFFFF);
  static const lightAppBar = Color(0xFF5288C1);
  static const lightBubbleReceived = Color(0xFFE8E8E8);
}

class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.teal,
        secondary: AppColors.teal,
        surface: AppColors.darkAppBar,
        onSurface: Colors.white,
        onSurfaceVariant: AppColors.darkSubtitle,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkAppBar,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.darkDrawer,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        minVerticalPadding: 10,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 0.5,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkTileHighlight,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInput,
        hintStyle: const TextStyle(color: AppColors.darkSubtitle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.darkSubtitle, fontSize: 15),
        titleMedium: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      splashColor: AppColors.teal.withValues(alpha: 0.08),
      highlightColor: AppColors.teal.withValues(alpha: 0.05),
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightAppBar,
        secondary: AppColors.teal,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightAppBar,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.teal,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

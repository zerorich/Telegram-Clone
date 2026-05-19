import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const teal = Color(0xFF2AABEE);
  static const tealDark = Color(0xFF229ED9);
  static const unreadBadge = Color(0xFF2AABEE);

  static const darkBg = Color(0xFF000000);
  static const darkList = Color(0xFF000000);
  static const darkAppBar = Color(0xFF000000);
  static const darkChatBg = Color(0xFF000000);
  static const darkDrawer = Color(0xFF000000);
  static const darkDrawerHeader = Color(0xFF1A1A2E);
  static const darkBubbleReceived = Color(0xFF20212B);
  static const darkBubbleMine = Color(0xFF8FA8E8);
  static const darkInput = Color(0xFF1C1C1E);
  static const dateChipBg = Color(0xFF2A2A2E);
  static const darkSubtitle = Color(0xFF8B9BAB);
  static const darkDivider = Color(0xFF1E2C3A);
  static const darkTileHighlight = Color(0xFF17212B);

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
        systemOverlayStyle: SystemUiOverlayStyle.light,
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
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInput,
        hintStyle: const TextStyle(color: AppColors.darkSubtitle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
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

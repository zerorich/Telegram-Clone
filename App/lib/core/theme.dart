import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'generated/tokens.dart';

export 'generated/tokens.dart' show AppColors, AppTokens;

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
        onSurface: AppColors.darkText,
        onSurfaceVariant: AppColors.darkSubtitle,
        error: AppTokens.danger,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkAppBar,
        foregroundColor: AppColors.darkText,
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
      cardTheme: CardThemeData(
        color: AppColors.darkAppBar,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkAppBar,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.darkText,
          fontSize: AppTokens.fontSizeLg,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.darkSubtitle,
          fontSize: AppTokens.fontSizeMd,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppTokens.listTileHorizontal,
          vertical: AppTokens.listTileVertical,
        ),
        minVerticalPadding: AppTokens.listTileMinVertical,
        iconColor: AppColors.darkSubtitle,
        textColor: AppColors.darkText,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: AppTokens.dividerThickness,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkTileHighlight,
        contentTextStyle: const TextStyle(color: AppColors.darkText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInput,
        hintStyle: const TextStyle(color: AppColors.darkSubtitle),
        labelStyle: const TextStyle(color: AppColors.darkSubtitle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInput),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInput),
          borderSide: const BorderSide(color: AppTokens.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInput),
          borderSide: const BorderSide(color: AppTokens.danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.inputHorizontal,
          vertical: AppTokens.inputVertical,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: AppColors.darkText,
          fontSize: AppTokens.fontSizeLg,
        ),
        bodyMedium: TextStyle(
          color: AppColors.darkSubtitle,
          fontSize: AppTokens.fontSizeMd,
        ),
        titleMedium: TextStyle(
          color: AppColors.darkText,
          fontSize: AppTokens.fontSizeLg,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: TextStyle(
          color: AppColors.darkText,
          fontSize: AppTokens.fontSizeMd,
          fontWeight: FontWeight.w500,
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
        surface: AppTokens.lightBgElev,
        onSurface: AppColors.lightText,
        onSurfaceVariant: AppColors.lightSubtitle,
        error: AppTokens.danger,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightAppBar,
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
        backgroundColor: AppColors.lightBg,
      ),
      cardTheme: CardThemeData(
        color: AppTokens.lightBgElev2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: const BorderSide(color: AppTokens.lightBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightBg,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.lightText,
          fontSize: AppTokens.fontSizeLg,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.lightSubtitle,
          fontSize: AppTokens.fontSizeMd,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppTokens.listTileHorizontal,
          vertical: AppTokens.listTileVertical,
        ),
        minVerticalPadding: AppTokens.listTileMinVertical,
        iconColor: AppColors.lightSubtitle,
        textColor: AppColors.lightText,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: AppTokens.dividerThickness,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightText,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightInput,
        hintStyle: const TextStyle(color: AppColors.lightSubtitle),
        labelStyle: const TextStyle(color: AppColors.lightSubtitle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInput),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInput),
          borderSide: const BorderSide(color: AppTokens.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInput),
          borderSide: const BorderSide(color: AppTokens.danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.inputHorizontal,
          vertical: AppTokens.inputVertical,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: AppColors.lightText,
          fontSize: AppTokens.fontSizeLg,
        ),
        bodyMedium: TextStyle(
          color: AppColors.lightSubtitle,
          fontSize: AppTokens.fontSizeMd,
        ),
        titleMedium: TextStyle(
          color: AppColors.lightText,
          fontSize: AppTokens.fontSizeLg,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: TextStyle(
          color: AppColors.lightText,
          fontSize: AppTokens.fontSizeMd,
          fontWeight: FontWeight.w500,
        ),
      ),
      splashColor: AppColors.teal.withValues(alpha: 0.10),
      highlightColor: AppColors.teal.withValues(alpha: 0.06),
    );
  }
}

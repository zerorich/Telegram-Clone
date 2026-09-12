import 'package:flutter/material.dart';
import 'package:telegramclone/core/theme.dart';

/// Theme-adaptive colors for widgets. Prefer this over hardcoded [AppColors.dark*].
extension AppThemeContext on BuildContext {
  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;

  ColorScheme get appColors => Theme.of(this).colorScheme;

  Color get scaffoldBg => Theme.of(this).scaffoldBackgroundColor;

  Color get appBarBg =>
      Theme.of(this).appBarTheme.backgroundColor ??
      (isDarkTheme ? AppColors.darkAppBar : AppColors.lightAppBar);

  Color get chatBg => isDarkTheme ? AppColors.darkChatBg : AppColors.lightBg;

  Color get tileHighlight =>
      isDarkTheme ? AppColors.darkTileHighlight : AppTokens.lightBgElev2;

  Color get inputFill =>
      isDarkTheme ? AppColors.darkInput : AppColors.lightInput;

  Color get subtitleColor => appColors.onSurfaceVariant;

  Color get dividerColor =>
      Theme.of(this).dividerTheme.color ??
      (isDarkTheme ? AppColors.darkDivider : AppColors.lightDivider);

  Color get primaryText => appColors.onSurface;

  Color get bubbleReceived =>
      isDarkTheme ? AppColors.darkBubbleReceived : AppColors.lightBubbleReceived;

  Color get bubbleMine =>
      isDarkTheme ? AppColors.darkBubbleMine : AppColors.lightBubbleMine;

  Color bubbleForeground({required bool isMine}) => isDarkTheme
      ? Colors.white
      : (isMine ? AppTokens.lightBubbleMineFg : AppTokens.lightBubbleOtherFg);

  Color get drawerBg =>
      isDarkTheme ? AppColors.darkDrawer : AppColors.lightBg;

  Color get tileActive =>
      isDarkTheme ? AppColors.darkTileActive : AppColors.lightTileActive;

  Color get mutedBadgeFill =>
      subtitleColor.withValues(alpha: isDarkTheme ? 0.4 : 0.35);
}

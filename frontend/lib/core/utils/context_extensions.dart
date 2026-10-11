import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  bool get isCompact => screenSize.width < 600;

  EdgeInsets get pagePadding => EdgeInsets.symmetric(
    horizontal: isCompact ? AppSpacing.md : AppSpacing.xl,
    vertical: AppSpacing.lg,
  );

  Color get mutedColor => AppColors.muted;
}

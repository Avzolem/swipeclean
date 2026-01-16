import 'package:flutter/material.dart';

/// Paleta de colores centralizada para SwipeClean
/// Mantiene coherencia entre modo oscuro y claro
class AppColors {
  // Colores de acento (iguales en ambos temas)
  static const Color primary = Color(0xFF6C63FF); // Púrpura principal
  static const Color primaryLight = Color(0xFF9D97FF); // Púrpura claro
  static const Color primaryDark = Color(0xFF4A42D4); // Púrpura oscuro

  static const Color success = Color(0xFF00C851); // Verde - conservar
  static const Color successLight = Color(0xFF5AFF8A);
  static const Color successDark = Color(0xFF009624);

  static const Color danger = Color(0xFFFF5252); // Rojo - eliminar
  static const Color dangerLight = Color(0xFFFF867F);
  static const Color dangerDark = Color(0xFFC50E29);

  static const Color warning = Color(0xFFFFAB00); // Ámbar - duplicados/pendientes
  static const Color warningLight = Color(0xFFFFDD4B);
  static const Color warningDark = Color(0xFFC67C00);

  static const Color info = Color(0xFF2196F3); // Azul - información

  // Tema Oscuro
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color darkSurface = Color(0xFF16213E);
  static const Color darkCard = Color(0xFF16213E);
  static const Color darkDivider = Color(0xFF2D3A5C);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xB3FFFFFF); // 70% opacity
  static const Color darkTextTertiary = Color(0x80FFFFFF); // 50% opacity
  static const Color darkOverlay = Color(0x99000000); // 60% black

  // Tema Claro
  static const Color lightBackground = Color(0xFFF5F5F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xB31A1A2E); // 70% opacity
  static const Color lightTextTertiary = Color(0x801A1A2E); // 50% opacity
  static const Color lightOverlay = Color(0x99FFFFFF); // 60% white
}

/// Clase helper para obtener colores según el tema actual
class ThemeColors {
  final bool isDark;

  ThemeColors({required this.isDark});

  Color get background =>
      isDark ? AppColors.darkBackground : AppColors.lightBackground;
  Color get surface => isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get card => isDark ? AppColors.darkCard : AppColors.lightCard;
  Color get divider => isDark ? AppColors.darkDivider : AppColors.lightDivider;
  Color get textPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get textTertiary =>
      isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
  Color get overlay => isDark ? AppColors.darkOverlay : AppColors.lightOverlay;

  // Colores de acento (igual en ambos temas)
  Color get primary => AppColors.primary;
  Color get success => AppColors.success;
  Color get danger => AppColors.danger;
  Color get warning => AppColors.warning;
  Color get info => AppColors.info;

  // Helpers para opacidades
  Color primaryWithOpacity(double opacity) =>
      AppColors.primary.withOpacity(opacity);
  Color successWithOpacity(double opacity) =>
      AppColors.success.withOpacity(opacity);
  Color dangerWithOpacity(double opacity) =>
      AppColors.danger.withOpacity(opacity);
  Color warningWithOpacity(double opacity) =>
      AppColors.warning.withOpacity(opacity);
  Color textPrimaryWithOpacity(double opacity) =>
      textPrimary.withOpacity(opacity);
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true; // Oscuro por defecto
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;

  /// Obtiene los colores según el tema actual
  ThemeColors get colors => ThemeColors(isDark: _isDarkMode);

  /// Obtiene el ThemeMode para MaterialApp
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// Inicializa con el valor guardado
  void initialize(String? savedTheme) {
    if (savedTheme != null) {
      _isDarkMode = savedTheme != 'light'; // Solo 'light' activa modo claro
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Alterna entre claro y oscuro
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  /// Nombre legible del tema actual
  String get themeName => _isDarkMode ? 'Oscuro' : 'Claro';

  /// Icono del tema actual
  IconData get themeIcon => _isDarkMode ? Icons.dark_mode : Icons.light_mode;

  /// String para guardar en storage
  String get themeString => _isDarkMode ? 'dark' : 'light';

  /// Tema claro para MaterialApp
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.lightBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lightBackground,
          foregroundColor: AppColors.lightTextPrimary,
          elevation: 0,
        ),
        cardColor: AppColors.lightCard,
        dividerColor: AppColors.lightDivider,
      );

  /// Tema oscuro para MaterialApp
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppColors.darkBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkBackground,
          foregroundColor: AppColors.darkTextPrimary,
          elevation: 0,
        ),
        cardColor: AppColors.darkCard,
        dividerColor: AppColors.darkDivider,
      );
}

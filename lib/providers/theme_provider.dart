import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/app_colors.dart';

enum ThemeOption { system, light, dark }

class ThemeProvider extends ChangeNotifier {
  ThemeOption _themeOption = ThemeOption.system;
  bool _isInitialized = false;

  ThemeOption get themeOption => _themeOption;
  bool get isInitialized => _isInitialized;

  /// Determina si el tema actual es oscuro
  bool get isDarkMode {
    switch (_themeOption) {
      case ThemeOption.dark:
        return true;
      case ThemeOption.light:
        return false;
      case ThemeOption.system:
        // Usar el brillo del sistema
        final brightness =
            SchedulerBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark;
    }
  }

  /// Obtiene los colores según el tema actual
  ThemeColors get colors => ThemeColors(isDark: isDarkMode);

  /// Obtiene el ThemeMode para MaterialApp
  ThemeMode get themeMode {
    switch (_themeOption) {
      case ThemeOption.dark:
        return ThemeMode.dark;
      case ThemeOption.light:
        return ThemeMode.light;
      case ThemeOption.system:
        return ThemeMode.system;
    }
  }

  /// Inicializa con el valor guardado
  void initialize(String? savedTheme) {
    if (savedTheme != null) {
      switch (savedTheme) {
        case 'light':
          _themeOption = ThemeOption.light;
          break;
        case 'dark':
          _themeOption = ThemeOption.dark;
          break;
        default:
          _themeOption = ThemeOption.system;
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Cambia el tema
  void setTheme(ThemeOption option) {
    if (_themeOption != option) {
      _themeOption = option;
      notifyListeners();
    }
  }

  /// Cicla entre los temas: system -> light -> dark -> system
  void cycleTheme() {
    switch (_themeOption) {
      case ThemeOption.system:
        _themeOption = ThemeOption.light;
        break;
      case ThemeOption.light:
        _themeOption = ThemeOption.dark;
        break;
      case ThemeOption.dark:
        _themeOption = ThemeOption.system;
        break;
    }
    notifyListeners();
  }

  /// Nombre legible del tema actual
  String get themeName {
    switch (_themeOption) {
      case ThemeOption.system:
        return 'Sistema';
      case ThemeOption.light:
        return 'Claro';
      case ThemeOption.dark:
        return 'Oscuro';
    }
  }

  /// Icono del tema actual
  IconData get themeIcon {
    switch (_themeOption) {
      case ThemeOption.system:
        return Icons.brightness_auto;
      case ThemeOption.light:
        return Icons.light_mode;
      case ThemeOption.dark:
        return Icons.dark_mode;
    }
  }

  /// String para guardar en storage
  String get themeString {
    switch (_themeOption) {
      case ThemeOption.system:
        return 'system';
      case ThemeOption.light:
        return 'light';
      case ThemeOption.dark:
        return 'dark';
    }
  }

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

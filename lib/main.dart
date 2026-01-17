import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/photo_provider.dart';
import 'providers/trash_provider.dart';
import 'providers/theme_provider.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar barra de estado inmediatamente
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Mostrar app inmediatamente con pantalla de carga
  runApp(const SwipeCleanApp());
}

/// Inicializa servicios en background
Future<void> _initializeServices() async {
  await StorageService().init();
}

class SwipeCleanApp extends StatefulWidget {
  const SwipeCleanApp({super.key});

  @override
  State<SwipeCleanApp> createState() => _SwipeCleanAppState();
}

class _SwipeCleanAppState extends State<SwipeCleanApp> {
  bool _isInitialized = false;
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _initializeServices();

    // Cargar tema guardado
    final savedTheme = StorageService().getTheme();
    _themeProvider.initialize(savedTheme);

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PhotoProvider()),
        ChangeNotifierProvider(create: (_) => TrashProvider()),
        ChangeNotifierProvider.value(value: _themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          // Actualizar barra de estado según el tema
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: themeProvider.isDarkMode
                  ? Brightness.light
                  : Brightness.dark,
            ),
          );

          return MaterialApp(
            title: 'SwipeClean',
            debugShowCheckedModeBanner: false,
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: _isInitialized ? const HomeScreen() : const _LoadingScreen(),
          );
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cleaning_services_rounded,
              size: 80,
              color: AppColors.primary,
            ),
            SizedBox(height: 24),
            Text(
              'SwipeClean',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

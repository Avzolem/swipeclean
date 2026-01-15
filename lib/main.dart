import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/photo_provider.dart';
import 'providers/trash_provider.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _initializeServices();
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
      ],
      child: MaterialApp(
        title: 'SwipeClean',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C63FF),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A1A2E),
            elevation: 0,
          ),
        ),
        home: _isInitialized ? const HomeScreen() : const _LoadingScreen(),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cleaning_services_rounded,
              size: 80,
              color: Color(0xFF6C63FF),
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
              color: Color(0xFF6C63FF),
            ),
          ],
        ),
      ),
    );
  }
}

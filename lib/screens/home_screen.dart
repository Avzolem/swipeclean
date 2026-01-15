import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/photo_provider.dart';
import '../providers/trash_provider.dart';
import 'swipe_screen.dart';
import 'trash_screen.dart';
import 'albums_screen.dart';
import 'duplicates_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cuando la app regresa al primer plano (después de dar permisos en settings)
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndLoad();
    }
  }

  Future<void> _checkPermissionAndLoad() async {
    final photoProvider = context.read<PhotoProvider>();
    final trashProvider = context.read<TrashProvider>();

    if (!photoProvider.hasPermission) {
      final hasPermission = await photoProvider.checkAndRequestPermission();
      if (hasPermission) {
        trashProvider.loadTrash();
      }
    }
  }

  Future<void> _initializeApp() async {
    final photoProvider = context.read<PhotoProvider>();
    final trashProvider = context.read<TrashProvider>();

    // Verificación rápida primero (sin mostrar diálogo de permisos)
    final hasPermission = await photoProvider.quickCheckPermission();

    if (hasPermission) {
      // Ya tenemos permiso, cargar fotos directamente
      if (photoProvider.photos.isEmpty) {
        await photoProvider.loadPhotos();
      }
      trashProvider.loadTrash();
    }
    // Si no tiene permiso, el UI mostrará la pantalla de solicitud
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Consumer2<PhotoProvider, TrashProvider>(
          builder: (context, photoProvider, trashProvider, _) {
            if (!photoProvider.hasPermission) {
              return _buildPermissionRequest(photoProvider);
            }

            if (photoProvider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            return _buildHomeContent(photoProvider, trashProvider);
          },
        ),
      ),
    );
  }

  Widget _buildPermissionRequest(PhotoProvider photoProvider) {
    final size = MediaQuery.of(context).size;
    return SingleChildScrollView(
      padding: EdgeInsets.all(size.width * 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: size.height * 0.1),
          Icon(
            Icons.photo_library_outlined,
            size: size.width * 0.2,
            color: Colors.white54,
          ),
          SizedBox(height: size.height * 0.03),
          Text(
            'SwipeClean necesita acceso a tus fotos',
            style: TextStyle(
              color: Colors.white,
              fontSize: size.width * 0.05,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: size.height * 0.015),
          Text(
            'Para poder ayudarte a limpiar tu galería, necesitamos permiso para ver tus fotos.',
            style: TextStyle(color: Colors.white70, fontSize: size.width * 0.04),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: size.height * 0.04),

          // Botón principal para dar permiso
          ElevatedButton(
            onPressed: () async {
              final photoProvider = context.read<PhotoProvider>();
              final trashProvider = context.read<TrashProvider>();

              // Solicitar permiso explícitamente
              final hasPermission = await photoProvider.requestPermission();

              if (hasPermission) {
                // Esperar un momento para que MIUI procese
                await Future.delayed(const Duration(milliseconds: 500));
                await photoProvider.loadPhotos();
                trashProvider.loadTrash();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.08,
                vertical: size.height * 0.018,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Dar permiso',
              style: TextStyle(fontSize: size.width * 0.045, color: Colors.white),
            ),
          ),

          SizedBox(height: size.height * 0.02),

          // Botón secundario para abrir configuración
          TextButton.icon(
            onPressed: () async {
              await openAppSettings();
            },
            icon: Icon(
              Icons.settings,
              color: Colors.white.withOpacity(0.7),
              size: size.width * 0.05,
            ),
            label: Text(
              'Abrir Configuración',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: size.width * 0.035,
              ),
            ),
          ),

          SizedBox(height: size.height * 0.04),

          // Instrucciones para Xiaomi/MIUI
          Container(
            padding: EdgeInsets.all(size.width * 0.04),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: size.width * 0.05,
                    ),
                    SizedBox(width: size.width * 0.02),
                    Text(
                      '¿Xiaomi/MIUI?',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: size.width * 0.04,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: size.height * 0.01),
                Text(
                  'Si el permiso no funciona, abre Configuración → Permisos → Fotos y videos → Permitir',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: size.width * 0.032,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(PhotoProvider photoProvider, TrashProvider trashProvider) {
    final size = MediaQuery.of(context).size;
    final padding = size.width * 0.05;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SwipeClean',
            style: TextStyle(
              color: Colors.white,
              fontSize: size.width * 0.07,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: size.height * 0.005),
          Text(
            'Limpia tu galería con swipes',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: size.width * 0.035,
            ),
          ),
          SizedBox(height: size.height * 0.025),

          // Stats cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Fotos',
                  photoProvider.totalPhotos.toString(),
                  Icons.photo_library,
                  const Color(0xFF6C63FF),
                  size,
                ),
              ),
              SizedBox(width: size.width * 0.03),
              Expanded(
                child: _buildStatCard(
                  'Revisadas',
                  trashProvider.reviewedCount.toString(),
                  Icons.check_circle,
                  const Color(0xFF00C851),
                  size,
                ),
              ),
            ],
          ),
          SizedBox(height: size.height * 0.015),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'En papelera',
                  trashProvider.trashCount.toString(),
                  Icons.delete,
                  const Color(0xFFFF5252),
                  size,
                ),
              ),
              SizedBox(width: size.width * 0.03),
              Expanded(
                child: _buildStatCard(
                  'Pendientes',
                  photoProvider.remainingPhotos.toString(),
                  Icons.pending,
                  const Color(0xFFFFAB00),
                  size,
                ),
              ),
            ],
          ),

          SizedBox(height: size.height * 0.03),

          // Action buttons
          _buildActionButton(
            'Empezar a limpiar',
            Icons.swipe,
            const Color(0xFF6C63FF),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SwipeScreen()),
            ),
            size,
          ),
          SizedBox(height: size.height * 0.012),
          _buildActionButton(
            'Ver papelera (${trashProvider.trashCount})',
            Icons.delete_outline,
            const Color(0xFFFF5252),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrashScreen()),
            ),
            size,
          ),
          SizedBox(height: size.height * 0.012),
          _buildActionButton(
            'Álbumes',
            Icons.folder_outlined,
            const Color(0xFF00C851),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlbumsScreen()),
            ),
            size,
          ),
          SizedBox(height: size.height * 0.012),
          _buildActionButton(
            'Duplicadas',
            Icons.compare,
            const Color(0xFFFFAB00),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DuplicatesScreen()),
            ),
            size,
          ),
          SizedBox(height: size.height * 0.03),

          // Botón de reiniciar si ya revisó fotos
          if (trashProvider.reviewedCount > 0)
            _buildActionButton(
              'Reiniciar limpieza',
              Icons.refresh,
              Colors.grey,
              () => _showResetDialog(context, size, photoProvider, trashProvider),
              size,
            ),

          SizedBox(height: size.height * 0.03),
          Center(
            child: Text(
              'Powered by avsolem.com',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: size.width * 0.03,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          SizedBox(height: size.height * 0.02),
        ],
      ),
    );
  }

  void _showResetDialog(
    BuildContext context,
    Size size,
    PhotoProvider photoProvider,
    TrashProvider trashProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reiniciar limpieza',
          style: TextStyle(color: Colors.white, fontSize: size.width * 0.045),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Qué deseas reiniciar?',
              style: TextStyle(color: Colors.white70, fontSize: size.width * 0.035),
            ),
            SizedBox(height: size.height * 0.015),
            Text(
              '• ${trashProvider.reviewedCount} fotos revisadas',
              style: TextStyle(color: Colors.white60, fontSize: size.width * 0.03),
            ),
            Text(
              '• ${trashProvider.trashCount} fotos en papelera',
              style: TextStyle(color: Colors.white60, fontSize: size.width * 0.03),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await trashProvider.resetReviewProgress();
              photoProvider.refresh();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Progreso reiniciado (papelera conservada)'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
            },
            child: Text(
              'Solo revisadas',
              style: TextStyle(fontSize: size.width * 0.032),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await trashProvider.resetAll();
              photoProvider.refresh();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Todo reiniciado'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(
              'Todo',
              style: TextStyle(fontSize: size.width * 0.032, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, Size size) {
    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: size.width * 0.06),
          SizedBox(height: size.height * 0.01),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: size.width * 0.06,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: size.height * 0.003),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: size.width * 0.03,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
    Size size,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.04,
            vertical: size.height * 0.018,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(size.width * 0.02),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: size.width * 0.05),
              ),
              SizedBox(width: size.width * 0.03),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size.width * 0.038,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.5),
                size: size.width * 0.04,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

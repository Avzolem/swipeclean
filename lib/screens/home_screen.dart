import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/photo_provider.dart';
import '../providers/trash_provider.dart';
import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
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

  void _toggleTheme() {
    final themeProvider = context.read<ThemeProvider>();
    themeProvider.toggleTheme();
    // Guardar preferencia
    StorageService().saveTheme(themeProvider.themeString);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final colors = themeProvider.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Consumer2<PhotoProvider, TrashProvider>(
          builder: (context, photoProvider, trashProvider, _) {
            if (!photoProvider.hasPermission) {
              return _buildPermissionRequest(photoProvider, colors);
            }

            if (photoProvider.isLoading) {
              return Center(
                child: CircularProgressIndicator(color: colors.primary),
              );
            }

            return _buildHomeContent(photoProvider, trashProvider, colors);
          },
        ),
      ),
    );
  }

  Widget _buildPermissionRequest(PhotoProvider photoProvider, ThemeColors colors) {
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
            color: colors.textTertiary,
          ),
          SizedBox(height: size.height * 0.03),
          Text(
            'SwipeClean necesita acceso a tus fotos',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: size.width * 0.05,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: size.height * 0.015),
          Text(
            'Para poder ayudarte a limpiar tu galería, necesitamos permiso para ver tus fotos.',
            style: TextStyle(color: colors.textSecondary, fontSize: size.width * 0.04),
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
              backgroundColor: colors.primary,
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
              color: colors.textSecondary,
              size: size.width * 0.05,
            ),
            label: Text(
              'Abrir Configuración',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: size.width * 0.035,
              ),
            ),
          ),

          SizedBox(height: size.height * 0.04),

          // Instrucciones para Xiaomi/MIUI
          Container(
            padding: EdgeInsets.all(size.width * 0.04),
            decoration: BoxDecoration(
              color: colors.warningWithOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.warningWithOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colors.warning,
                      size: size.width * 0.05,
                    ),
                    SizedBox(width: size.width * 0.02),
                    Text(
                      '¿Xiaomi/MIUI?',
                      style: TextStyle(
                        color: colors.warning,
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
                    color: colors.textSecondary,
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

  Widget _buildHomeContent(
    PhotoProvider photoProvider,
    TrashProvider trashProvider,
    ThemeColors colors,
  ) {
    final size = MediaQuery.of(context).size;
    final padding = size.width * 0.05;
    final themeProvider = context.watch<ThemeProvider>();

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con título y botón de tema
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SwipeClean',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: size.width * 0.07,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: size.height * 0.005),
                  Text(
                    'Limpia tu galería con swipes',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: size.width * 0.035,
                    ),
                  ),
                ],
              ),
              // Botón de tema
              _buildThemeButton(themeProvider, colors, size),
            ],
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
                  colors.primary,
                  colors,
                  size,
                ),
              ),
              SizedBox(width: size.width * 0.03),
              Expanded(
                child: _buildStatCard(
                  'Revisadas',
                  trashProvider.reviewedCount.toString(),
                  Icons.check_circle,
                  colors.success,
                  colors,
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
                  colors.danger,
                  colors,
                  size,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TrashScreen()),
                  ),
                  extraInfo: trashProvider.trashCount > 0 && !trashProvider.isCalculatingSpace
                      ? '~${TrashProvider.formatBytes(trashProvider.estimatedSpaceBytes)} a liberar'
                      : null,
                ),
              ),
              SizedBox(width: size.width * 0.03),
              Expanded(
                child: _buildStatCard(
                  'Pendientes',
                  photoProvider.remainingPhotos.toString(),
                  Icons.pending,
                  colors.warning,
                  colors,
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
            colors.primary,
            colors,
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
            colors.danger,
            colors,
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
            colors.success,
            colors,
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
            colors.warning,
            colors,
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
              colors.textTertiary,
              colors,
              () => _showResetDialog(context, size, photoProvider, trashProvider, colors),
              size,
            ),

          SizedBox(height: size.height * 0.03),
          Center(
            child: Text(
              'Powered by avsolem.com',
              style: TextStyle(
                color: colors.textTertiary,
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

  Widget _buildThemeButton(ThemeProvider themeProvider, ThemeColors colors, Size size) {
    return GestureDetector(
      onTap: _toggleTheme,
      child: Container(
        padding: EdgeInsets.all(size.width * 0.03),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              themeProvider.themeIcon,
              color: colors.primary,
              size: size.width * 0.05,
            ),
            SizedBox(width: size.width * 0.02),
            Text(
              themeProvider.themeName,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: size.width * 0.032,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(
    BuildContext context,
    Size size,
    PhotoProvider photoProvider,
    TrashProvider trashProvider,
    ThemeColors colors,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reiniciar limpieza',
          style: TextStyle(color: colors.textPrimary, fontSize: size.width * 0.05),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Qué deseas reiniciar?',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: size.width * 0.042,
              ),
            ),
            SizedBox(height: size.height * 0.02),
            Text(
              '• ${trashProvider.reviewedCount} fotos revisadas',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: size.width * 0.038,
              ),
            ),
            SizedBox(height: size.height * 0.008),
            Text(
              '• ${trashProvider.trashCount} fotos en papelera',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: size.width * 0.038,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding: EdgeInsets.only(
          left: size.width * 0.04,
          right: size.width * 0.04,
          bottom: size.height * 0.02,
        ),
        actions: [
          // Botón Cancelar - fondo rojo claro
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.danger.withOpacity(0.1),
              side: BorderSide(color: colors.danger.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.04,
                vertical: size.height * 0.012,
              ),
            ),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: colors.danger,
                fontSize: size.width * 0.035,
              ),
            ),
          ),
          // Botón Solo revisadas - fondo verde claro
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(context);
              await trashProvider.resetReviewProgress();
              photoProvider.refresh();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Progreso reiniciado (papelera conservada)'),
                    backgroundColor: colors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.success.withOpacity(0.1),
              side: BorderSide(color: colors.success.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.04,
                vertical: size.height * 0.012,
              ),
            ),
            child: Text(
              'Solo revisadas',
              style: TextStyle(
                color: colors.success,
                fontSize: size.width * 0.035,
              ),
            ),
          ),
          // Botón Todo - fondo warning sólido
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await trashProvider.resetAll();
              photoProvider.refresh();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Todo reiniciado'),
                    backgroundColor: colors.warning,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.warning,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.05,
                vertical: size.height * 0.012,
              ),
            ),
            child: Text(
              'Todo',
              style: TextStyle(
                fontSize: size.width * 0.035,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeColors colors,
    Size size, {
    VoidCallback? onTap,
    String? extraInfo,
  }) {
    final content = Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono y número en línea
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: size.width * 0.06),
              SizedBox(width: size.width * 0.025),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: size.width * 0.065,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: size.height * 0.005),
          // Label abajo
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: size.width * 0.03,
                  ),
                ),
              ),
              // Indicador sutil si es clickeable
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  color: colors.textTertiary,
                  size: size.width * 0.03,
                ),
            ],
          ),
          // Info extra (ej: espacio a liberar)
          if (extraInfo != null) ...[
            SizedBox(height: size.height * 0.003),
            Text(
              extraInfo,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: size.width * 0.025,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    ThemeColors colors,
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
            color: colors.surface,
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
                    color: colors.textPrimary,
                    fontSize: size.width * 0.038,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: colors.textTertiary,
                size: size.width * 0.04,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

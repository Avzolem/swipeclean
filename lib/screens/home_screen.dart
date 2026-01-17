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
    // Cuando la app regresa al primer plano
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    final photoProvider = context.read<PhotoProvider>();
    final trashProvider = context.read<TrashProvider>();

    if (!photoProvider.hasPermission) {
      // Si no tiene permisos, verificar si los dio en settings
      final hasPermission = await photoProvider.checkAndRequestPermission();
      if (hasPermission) {
        trashProvider.loadTrash();
      }
    } else {
      // Ya tiene permisos, verificar si hay fotos nuevas
      await photoProvider.checkForNewPhotos();
    }
  }

  /// Refresca los datos (para pull-to-refresh)
  Future<void> _onRefresh() async {
    final photoProvider = context.read<PhotoProvider>();
    final trashProvider = context.read<TrashProvider>();

    if (photoProvider.hasPermission) {
      await photoProvider.forceReload();
      trashProvider.loadTrash();
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

    // Calcular stats
    final totalPhotos = photoProvider.totalPhotos;
    final reviewedCount = trashProvider.reviewedCount;
    final pendingPhotos = photoProvider.remainingPhotos;
    final progressPercent = totalPhotos > 0 ? (reviewedCount / totalPhotos * 100) : 0.0;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: colors.primary,
      backgroundColor: colors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Logo + Theme switcher
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
                        fontSize: size.width * 0.08,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: size.height * 0.003),
                    Text(
                      'Limpia tu galería con swipes',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: size.width * 0.032,
                      ),
                    ),
                  ],
                ),
                _buildThemeButton(themeProvider, colors, size),
              ],
            ),
            SizedBox(height: size.height * 0.025),

            // Fila superior: Álbumes y Duplicadas
            Row(
              children: [
                Expanded(
                  child: _buildSquareButton(
                    'Álbumes',
                    Icons.folder_rounded,
                    colors.success,
                    colors,
                    size,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AlbumsScreen()),
                    ),
                  ),
                ),
                SizedBox(width: size.width * 0.04),
                Expanded(
                  child: _buildSquareButton(
                    'Duplicadas',
                    Icons.compare_rounded,
                    colors.warning,
                    colors,
                    size,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DuplicatesScreen()),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: size.height * 0.02),

            // Barra de progreso (encima del botón Limpiar)
            _buildProgressBar(colors, size, pendingPhotos, progressPercent),
            SizedBox(height: size.height * 0.015),

            // Botón grande central: Limpiar
            _buildMainCleanButton(
              photoProvider,
              trashProvider,
              colors,
              size,
              reviewedCount,
              totalPhotos,
            ),
            SizedBox(height: size.height * 0.02),

            // Fila inferior: Papelera + Reiniciar
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTrashButton(trashProvider, colors, size),
                  ),
                  SizedBox(width: size.width * 0.04),
                  Expanded(
                    flex: 2,
                    child: _buildResetButton(photoProvider, trashProvider, colors, size),
                  ),
                ],
              ),
            ),
            SizedBox(height: size.height * 0.04),

            // Footer
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
      ),
    );
  }

  /// Botón de tema (solo icono)
  Widget _buildThemeButton(ThemeProvider themeProvider, ThemeColors colors, Size size) {
    return GestureDetector(
      onTap: _toggleTheme,
      child: Container(
        padding: EdgeInsets.all(size.width * 0.035),
        decoration: BoxDecoration(
          color: colors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          themeProvider.themeIcon,
          color: colors.primary,
          size: size.width * 0.06,
        ),
      ),
    );
  }

  /// Botones cuadrados (Álbumes, Duplicadas)
  Widget _buildSquareButton(
    String label,
    IconData icon,
    Color color,
    ThemeColors colors,
    Size size,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: size.height * 0.025),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: size.width * 0.12,
              ),
              SizedBox(height: size.height * 0.01),
              Text(
                label,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: size.width * 0.04,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Botón principal grande (Limpiar)
  Widget _buildMainCleanButton(
    PhotoProvider photoProvider,
    TrashProvider trashProvider,
    ThemeColors colors,
    Size size,
    int reviewedCount,
    int totalPhotos,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SwipeScreen()),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: size.height * 0.035,
            horizontal: size.width * 0.06,
          ),
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Icono de swipe grande
              Icon(
                Icons.swipe_rounded,
                color: colors.primary,
                size: size.width * 0.16,
              ),
              SizedBox(height: size.height * 0.012),
              // Texto "Limpiar"
              Text(
                'Limpiar',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: size.width * 0.055,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: size.height * 0.02),
              // Stats: ✓ Revisadas / Fotos totales
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: colors.success,
                    size: size.width * 0.05,
                  ),
                  SizedBox(width: size.width * 0.015),
                  Text(
                    '$reviewedCount',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: size.width * 0.05,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ' Revisadas',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: size.width * 0.035,
                    ),
                  ),
                  SizedBox(width: size.width * 0.04),
                  Text(
                    '/',
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: size.width * 0.05,
                    ),
                  ),
                  SizedBox(width: size.width * 0.04),
                  Text(
                    '$totalPhotos',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: size.width * 0.05,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: size.width * 0.015),
                  Icon(
                    Icons.photo_library,
                    color: colors.primary,
                    size: size.width * 0.05,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra de progreso
  Widget _buildProgressBar(
    ThemeColors colors,
    Size size,
    int pendingPhotos,
    double progressPercent,
  ) {
    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: colors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$pendingPhotos Fotos Pendientes de Revisar',
            style: TextStyle(
              color: colors.info,
              fontSize: size.width * 0.035,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: size.height * 0.012),
          // Barra de progreso
          Stack(
            children: [
              // Fondo
              Container(
                height: size.height * 0.025,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              // Progreso
              FractionallySizedBox(
                widthFactor: progressPercent / 100,
                child: Container(
                  height: size.height * 0.025,
                  decoration: BoxDecoration(
                    color: colors.success,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      '${progressPercent.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size.width * 0.028,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Botón de papelera
  Widget _buildTrashButton(
    TrashProvider trashProvider,
    ThemeColors colors,
    Size size,
  ) {
    final hasSpace = trashProvider.trashCount > 0 && !trashProvider.isCalculatingSpace;
    final spaceText = hasSpace
        ? '~${TrashProvider.formatBytes(trashProvider.estimatedSpaceBytes)}'
        : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TrashScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: size.height * 0.015,
            horizontal: size.width * 0.04,
          ),
          decoration: BoxDecoration(
            color: colors.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delete_rounded,
                color: colors.danger,
                size: size.width * 0.08,
              ),
              SizedBox(width: size.width * 0.025),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Papelera',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: size.width * 0.038,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${trashProvider.trashCount} fotos',
                        style: TextStyle(
                          color: colors.danger,
                          fontSize: size.width * 0.03,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (spaceText.isNotEmpty) ...[
                        Text(
                          ' · $spaceText',
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: size.width * 0.028,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Botón de reiniciar
  Widget _buildResetButton(
    PhotoProvider photoProvider,
    TrashProvider trashProvider,
    ThemeColors colors,
    Size size,
  ) {
    final isDisabled = trashProvider.reviewedCount == 0;
    final iconColor = isDisabled ? colors.textTertiary.withOpacity(0.4) : colors.textSecondary;
    final textColor = isDisabled ? colors.textTertiary.withOpacity(0.4) : colors.textSecondary;
    final subtextColor = isDisabled ? colors.textTertiary.withOpacity(0.3) : colors.textTertiary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled
            ? null
            : () => _showResetDialog(context, size, photoProvider, trashProvider, colors),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: size.height * 0.02,
            horizontal: size.width * 0.03,
          ),
          decoration: BoxDecoration(
            color: colors.textTertiary.withOpacity(isDisabled ? 0.04 : 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.refresh_rounded,
                color: iconColor,
                size: size.width * 0.1,
              ),
              SizedBox(height: size.height * 0.005),
              Text(
                'Reiniciar',
                style: TextStyle(
                  color: textColor,
                  fontSize: size.width * 0.03,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Limpieza',
                style: TextStyle(
                  color: subtextColor,
                  fontSize: size.width * 0.028,
                ),
              ),
            ],
          ),
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
        actionsPadding: EdgeInsets.only(
          left: size.width * 0.04,
          right: size.width * 0.04,
          bottom: size.height * 0.02,
        ),
        actions: [
          // Columna para que los botones tengan el mismo ancho
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                // Botón Cancelar - fondo rojo claro
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.danger.withOpacity(0.1),
                      side: BorderSide(color: colors.danger.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: size.height * 0.015,
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: colors.danger,
                        fontSize: size.width * 0.038,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.01),
                // Botón Solo conservadas - fondo verde claro
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await trashProvider.resetKeptPhotosOnly();
                      photoProvider.refresh();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Fotos conservadas reiniciadas (papelera intacta)'),
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
                        vertical: size.height * 0.015,
                      ),
                    ),
                    child: Text(
                      'Conservadas',
                      style: TextStyle(
                        color: colors.success,
                        fontSize: size.width * 0.038,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.01),
                // Botón Todo - fondo warning outlined
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
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
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.warning.withOpacity(0.1),
                      side: BorderSide(color: colors.warning.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: size.height * 0.015,
                      ),
                    ),
                    child: Text(
                      'Todo (Incluyendo papelera)',
                      style: TextStyle(
                        color: colors.warning,
                        fontSize: size.width * 0.038,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

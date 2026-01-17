import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trash_provider.dart';
import '../providers/photo_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/trash_thumbnail.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  @override
  void initState() {
    super.initState();
    // Recalcular espacio al entrar (por si cambió)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TrashProvider>().calculateSpace();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final themeProvider = context.watch<ThemeProvider>();
    final colors = themeProvider.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Consumer<TrashProvider>(
          builder: (context, provider, _) => Text(
            'Papelera (${provider.trashCount})',
            style: TextStyle(color: colors.textPrimary),
          ),
        ),
        actions: [
          Consumer<TrashProvider>(
            builder: (context, provider, _) {
              if (provider.trashCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () {
                  if (provider.hasSelection) {
                    provider.clearSelection();
                  } else {
                    provider.selectAll();
                  }
                },
                child: Text(
                  provider.hasSelection ? 'Deseleccionar' : 'Seleccionar todos',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: size.width * 0.032,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<TrashProvider>(
        builder: (context, trashProvider, _) {
          if (trashProvider.trashCount == 0) {
            return _buildEmptyState(size, colors);
          }

          return Column(
            children: [
              // Header con estadísticas
              Container(
                padding: EdgeInsets.all(size.width * 0.04),
                color: colors.surface,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_sweep,
                      color: colors.danger.withOpacity(0.8),
                      size: size.width * 0.06,
                    ),
                    SizedBox(width: size.width * 0.03),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${trashProvider.trashCount} fotos en papelera',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: size.width * 0.038,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Selecciona para restaurar o eliminar',
                            style: TextStyle(
                              color: colors.textTertiary,
                              fontSize: size.width * 0.03,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: size.width * 0.025,
                        vertical: size.height * 0.008,
                      ),
                      decoration: BoxDecoration(
                        color: colors.successWithOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          if (trashProvider.isCalculatingSpace)
                            SizedBox(
                              width: size.width * 0.04,
                              height: size.width * 0.04,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.success,
                              ),
                            )
                          else
                            Text(
                              '~${TrashProvider.formatBytes(trashProvider.estimatedSpaceBytes)}',
                              style: TextStyle(
                                color: colors.success,
                                fontSize: size.width * 0.035,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Text(
                            'a liberar',
                            style: TextStyle(
                              color: colors.success.withOpacity(0.7),
                              fontSize: size.width * 0.025,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Grid de fotos
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.all(size.width * 0.03),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: trashProvider.trashItems.length,
                  cacheExtent: 500,
                  itemBuilder: (context, index) {
                    final item = trashProvider.trashItems[index];
                    final isSelected = trashProvider.selectedItems.contains(item.photoId);

                    return GestureDetector(
                      onTap: () => trashProvider.toggleSelection(item.photoId),
                      onLongPress: () => _showItemOptions(context, item.photoId, trashProvider, colors),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          TrashThumbnail(
                            photoId: item.photoId,
                            size: (size.width * 0.35).toInt(),
                            fit: BoxFit.cover,
                          ),

                          // Selection overlay
                          if (isSelected)
                            Container(
                              color: colors.dangerWithOpacity(0.4),
                              child: Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: size.width * 0.1,
                                ),
                              ),
                            ),

                          // Selection indicator
                          Positioned(
                            top: size.width * 0.02,
                            right: size.width * 0.02,
                            child: Container(
                              width: size.width * 0.06,
                              height: size.width * 0.06,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? colors.danger : colors.textTertiary,
                                border: Border.all(color: Colors.white, width: size.width * 0.005),
                              ),
                              child: isSelected
                                  ? Icon(Icons.check, color: Colors.white, size: size.width * 0.04)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom action bar
              if (trashProvider.trashCount > 0)
                _buildBottomBar(context, trashProvider, size, colors),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, TrashProvider trashProvider, Size size, ThemeColors colors) {
    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trashProvider.hasSelection
                        ? '${trashProvider.selectedCount} seleccionadas'
                        : 'Selecciona fotos',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: size.width * 0.035,
                    ),
                  ),
                ),
                if (trashProvider.hasSelection && !trashProvider.isCalculatingSpace)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.02,
                      vertical: size.height * 0.005,
                    ),
                    decoration: BoxDecoration(
                      color: colors.successWithOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '~${TrashProvider.formatBytes(trashProvider.calculateSelectedSpace())}',
                      style: TextStyle(
                        color: colors.success,
                        fontSize: size.width * 0.03,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (trashProvider.hasSelection)
              Padding(
                padding: EdgeInsets.only(top: size.height * 0.015),
                child: Row(
                  children: [
                    // Botón Restaurar
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: trashProvider.isDeleting
                            ? null
                            : () => _confirmRestore(context, trashProvider, colors),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.success,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(vertical: size.height * 0.015),
                        ),
                        icon: const Icon(Icons.restore, color: Colors.white),
                        label: Text(
                          'Restaurar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size.width * 0.035,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: size.width * 0.03),
                    // Botón Eliminar
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: trashProvider.isDeleting
                            ? null
                            : () => _confirmDelete(context, trashProvider, colors),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.danger,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(vertical: size.height * 0.015),
                        ),
                        icon: trashProvider.isDeleting
                            ? SizedBox(
                                width: size.width * 0.04,
                                height: size.width * 0.04,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_forever, color: Colors.white),
                        label: Text(
                          'Eliminar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size.width * 0.035,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildEmptyState(Size size, ThemeColors colors) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(size.width * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline,
              size: size.width * 0.2,
              color: colors.textTertiary,
            ),
            SizedBox(height: size.height * 0.02),
            Text(
              'Papelera vacía',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: size.width * 0.05,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: size.height * 0.01),
            Text(
              'Las fotos que marques para eliminar aparecerán aquí',
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: size.width * 0.035,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showItemOptions(BuildContext context, String photoId, TrashProvider provider, ThemeColors colors) {
    final size = MediaQuery.of(context).size;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.all(size.width * 0.05),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.restore, color: colors.success),
              title: Text('Restaurar', style: TextStyle(color: colors.textPrimary)),
              subtitle: Text(
                'Devolver a la galería',
                style: TextStyle(color: colors.textTertiary),
              ),
              onTap: () {
                provider.restoreFromTrash(photoId);
                context.read<PhotoProvider>().refresh();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever, color: colors.danger),
              title: Text('Eliminar', style: TextStyle(color: colors.textPrimary)),
              subtitle: Text(
                'Borrar permanentemente',
                style: TextStyle(color: colors.textTertiary),
              ),
              onTap: () {
                provider.toggleSelection(photoId);
                Navigator.pop(context);
                _confirmDelete(context, provider, colors);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRestore(BuildContext context, TrashProvider provider, ThemeColors colors) {
    final size = MediaQuery.of(context).size;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Restaurar fotos?',
          style: TextStyle(color: colors.textPrimary, fontSize: size.width * 0.045),
        ),
        content: Text(
          'Se restaurarán ${provider.selectedCount} fotos y volverán a aparecer en la cola de revisión.',
          style: TextStyle(color: colors.textSecondary, fontSize: size.width * 0.035),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final restoredCount = await provider.restoreSelected();
              if (context.mounted) {
                context.read<PhotoProvider>().refresh();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$restoredCount fotos restauradas'),
                    backgroundColor: colors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: colors.success),
            child: const Text('Restaurar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, TrashProvider provider, ThemeColors colors) {
    final size = MediaQuery.of(context).size;
    final spaceToFree = provider.calculateSelectedSpace();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Eliminar fotos?',
          style: TextStyle(color: colors.textPrimary, fontSize: size.width * 0.045),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se eliminarán ${provider.selectedCount} fotos permanentemente de tu dispositivo.',
              style: TextStyle(color: colors.textSecondary, fontSize: size.width * 0.035),
            ),
            SizedBox(height: size.height * 0.015),
            Container(
              padding: EdgeInsets.all(size.width * 0.03),
              decoration: BoxDecoration(
                color: colors.successWithOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.successWithOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.storage, color: colors.success, size: size.width * 0.05),
                  SizedBox(width: size.width * 0.02),
                  Text(
                    'Liberarás ~${TrashProvider.formatBytes(spaceToFree)}',
                    style: TextStyle(
                      color: colors.success,
                      fontSize: size.width * 0.035,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: size.height * 0.01),
            Text(
              'Esta acción no se puede deshacer.',
              style: TextStyle(
                color: colors.danger.withOpacity(0.8),
                fontSize: size.width * 0.03,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.deleteSelected();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Fotos eliminadas - ${TrashProvider.formatBytes(spaceToFree)} liberados'
                          : 'Error al eliminar',
                    ),
                    backgroundColor: success ? colors.success : colors.danger,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: colors.danger),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

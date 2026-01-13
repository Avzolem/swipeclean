import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../providers/trash_provider.dart';
import '../providers/photo_provider.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Consumer<TrashProvider>(
          builder: (context, provider, _) => Text(
            'Papelera (${provider.trashCount})',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        actions: [
          Consumer<TrashProvider>(
            builder: (context, provider, _) {
              if (provider.trashCount == 0) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(
                  provider.hasSelection ? Icons.deselect : Icons.select_all,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (provider.hasSelection) {
                    provider.clearSelection();
                  } else {
                    provider.selectAll();
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<TrashProvider>(
        builder: (context, trashProvider, _) {
          if (trashProvider.trashCount == 0) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: trashProvider.trashItems.length,
                  itemBuilder: (context, index) {
                    final item = trashProvider.trashItems[index];
                    final isSelected = trashProvider.selectedItems.contains(item.photoId);

                    return FutureBuilder<AssetEntity?>(
                      future: AssetEntity.fromId(item.photoId),
                      builder: (context, snapshot) {
                        return GestureDetector(
                          onTap: () => trashProvider.toggleSelection(item.photoId),
                          onLongPress: () => _showItemOptions(context, item.photoId, trashProvider),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (snapshot.hasData && snapshot.data != null)
                                FutureBuilder<Uint8List?>(
                                  future: snapshot.data!.thumbnailDataWithSize(
                                    const ThumbnailSize(300, 300),
                                  ),
                                  builder: (context, thumbSnapshot) {
                                    if (thumbSnapshot.hasData) {
                                      return Image.memory(
                                        thumbSnapshot.data!,
                                        fit: BoxFit.cover,
                                      );
                                    }
                                    return Container(color: Colors.grey[800]);
                                  },
                                )
                              else
                                Container(
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.white54,
                                  ),
                                ),

                              // Selection overlay
                              if (isSelected)
                                Container(
                                  color: Colors.red.withOpacity(0.4),
                                  child: const Center(
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),

                              // Selection indicator
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? Colors.red : Colors.white.withOpacity(0.5),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Bottom action bar
              if (trashProvider.trashCount > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
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
                                    : 'Selecciona fotos para restaurar o eliminar',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                        if (trashProvider.hasSelection)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                // Botón Restaurar
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: trashProvider.isDeleting
                                        ? null
                                        : () => _confirmRestore(context, trashProvider),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    icon: const Icon(Icons.restore, color: Colors.white),
                                    label: const Text(
                                      'Restaurar',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Botón Eliminar
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: trashProvider.isDeleting
                                        ? null
                                        : () => _confirmDelete(context, trashProvider),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    icon: trashProvider.isDeleting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.delete_forever, color: Colors.white),
                                    label: const Text(
                                      'Eliminar',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_outline,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Papelera vacía',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las fotos que marques para eliminar aparecerán aquí',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showItemOptions(BuildContext context, String photoId, TrashProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.green),
              title: const Text('Restaurar', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                'Devolver a la galería',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              onTap: () {
                provider.restoreFromTrash(photoId);
                context.read<PhotoProvider>().refresh();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Eliminar', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                'Borrar permanentemente',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              onTap: () {
                provider.toggleSelection(photoId);
                Navigator.pop(context);
                _confirmDelete(context, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRestore(BuildContext context, TrashProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Restaurar fotos?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Se restaurarán ${provider.selectedCount} fotos y volverán a aparecer en la cola de revisión.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
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
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Restaurar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, TrashProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Eliminar fotos?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Se eliminarán ${provider.selectedCount} fotos permanentemente de tu dispositivo. Esta acción no se puede deshacer.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.deleteSelected();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Fotos eliminadas' : 'Error al eliminar',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../providers/photo_provider.dart';
import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import 'swipe_screen.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  final StorageService _storageService = StorageService();
  bool _isLoadingAlbum = false;
  String? _loadingAlbumId;

  // Cola de carga escalonada
  final Map<String, _AlbumInfo> _albumInfoCache = {};
  final List<String> _loadQueue = [];
  bool _isProcessingQueue = false;

  Future<void> _onAlbumTap(AssetPathEntity album, PhotoProvider provider) async {
    if (_isLoadingAlbum) return;

    setState(() {
      _isLoadingAlbum = true;
      _loadingAlbumId = album.id;
    });

    try {
      await provider.loadPhotosFromAlbum(album);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SwipeScreen()),
        ).then((_) {
          provider.clearAlbumFilter();
          // Recalcular solo el estado de completado (sin recargar thumbnails)
          if (mounted) {
            _recalculateCompletedStatus();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAlbum = false;
          _loadingAlbumId = null;
        });
      }
    }
  }

  /// Encola un álbum para cargar su info
  void _enqueueAlbumLoad(AssetPathEntity album) {
    if (_albumInfoCache.containsKey(album.id)) return;
    if (_loadQueue.contains(album.id)) return;

    _loadQueue.add(album.id);
    _processQueue();
  }

  /// Recalcula solo el estado de completado sin recargar thumbnails
  Future<void> _recalculateCompletedStatus() async {
    final provider = context.read<PhotoProvider>();

    for (final album in provider.albums) {
      final existingInfo = _albumInfoCache[album.id];
      if (existingInfo == null) continue;

      try {
        final assets = await album.getAssetListRange(start: 0, end: existingInfo.count);
        int reviewedCount = 0;

        for (final asset in assets) {
          if (_storageService.isReviewed(asset.id) ||
              _storageService.isInTrash(asset.id)) {
            reviewedCount++;
          }
        }

        // Solo actualizar si cambió el reviewedCount
        if (existingInfo.reviewedCount != reviewedCount && mounted) {
          setState(() {
            _albumInfoCache[album.id] = _AlbumInfo(
              count: existingInfo.count,
              thumbnail: existingInfo.thumbnail,
              reviewedCount: reviewedCount,
            );
          });
        }
      } catch (e) {
        // Ignorar errores
      }
    }
  }

  /// Procesa la cola de carga de forma escalonada
  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    // Capturar provider antes del loop async
    final provider = context.read<PhotoProvider>();

    while (_loadQueue.isNotEmpty && mounted) {
      final albumId = _loadQueue.removeAt(0);

      // Buscar el álbum
      final album = provider.albums.firstWhere(
        (a) => a.id == albumId,
        orElse: () => provider.albums.first,
      );

      if (album.id != albumId) continue;

      try {
        final count = await album.assetCountAsync;
        Uint8List? thumbnail;
        int reviewedCount = 0;

        if (count > 0) {
          final assets = await album.getAssetListRange(start: 0, end: count);

          // Obtener thumbnail del primer asset
          if (assets.isNotEmpty) {
            thumbnail = await assets.first.thumbnailDataWithSize(
              const ThumbnailSize(200, 200),
            );
          }

          // Contar cuántas fotos están revisadas (en reviewed o en trash)
          for (final asset in assets) {
            if (_storageService.isReviewed(asset.id) ||
                _storageService.isInTrash(asset.id)) {
              reviewedCount++;
            }
          }
        }

        if (mounted) {
          setState(() {
            _albumInfoCache[albumId] = _AlbumInfo(
              count: count,
              thumbnail: thumbnail,
              reviewedCount: reviewedCount,
            );
          });
        }
      } catch (e) {
        // Ignorar errores silenciosamente
      }

      // Pequeño delay entre cargas para no saturar
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _isProcessingQueue = false;
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
          onPressed: _isLoadingAlbum ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Álbumes',
          style: TextStyle(color: colors.textPrimary),
        ),
      ),
      body: Consumer<PhotoProvider>(
        builder: (context, provider, _) {
          final albums = provider.albums;

          if (albums.isEmpty) {
            return Center(
              child: CircularProgressIndicator(color: colors.primary),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(size.width * 0.04),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];

              // Encolar carga cuando el tile se construye
              _enqueueAlbumLoad(album);

              final info = _albumInfoCache[album.id];

              return _AlbumTile(
                album: album,
                colors: colors,
                size: size,
                isLoading: _loadingAlbumId == album.id,
                isDisabled: _isLoadingAlbum && _loadingAlbumId != album.id,
                onTap: () => _onAlbumTap(album, provider),
                cachedInfo: info,
                isCompleted: info?.isCompleted ?? false,
              );
            },
          );
        },
      ),
    );
  }
}

/// Info cacheada de un álbum
class _AlbumInfo {
  final int count;
  final Uint8List? thumbnail;
  final int reviewedCount; // Cuántas fotos están revisadas

  _AlbumInfo({required this.count, this.thumbnail, this.reviewedCount = 0});

  /// El álbum está completo si todas sus fotos fueron revisadas
  bool get isCompleted => count > 0 && reviewedCount >= count;
}

class _AlbumTile extends StatelessWidget {
  final AssetPathEntity album;
  final ThemeColors colors;
  final Size size;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isDisabled;
  final _AlbumInfo? cachedInfo;
  final bool isCompleted;

  const _AlbumTile({
    required this.album,
    required this.colors,
    required this.size,
    required this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
    this.cachedInfo,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final count = cachedInfo?.count ?? 0;
    final thumbnail = cachedInfo?.thumbnail;
    final isInfoLoaded = cachedInfo != null;

    // Habilitado si tiene fotos y no está en otro estado de carga
    final isEnabled = (isInfoLoaded ? count > 0 : true) && !isDisabled && !isLoading;
    final thumbnailSize = size.width * 0.18;

    return Padding(
      padding: EdgeInsets.only(bottom: size.height * 0.015),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onTap : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(size.width * 0.03),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLoading
                      ? colors.primaryWithOpacity(0.5)
                      : colors.divider,
                  width: isLoading ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Album thumbnail
                  Container(
                    width: thumbnailSize,
                    height: thumbnailSize,
                    decoration: BoxDecoration(
                      color: colors.primaryWithOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: thumbnail != null
                        ? Image.memory(thumbnail, fit: BoxFit.cover)
                        : Icon(
                            Icons.photo_album,
                            color: colors.textTertiary,
                            size: size.width * 0.08,
                          ),
                  ),
                  SizedBox(width: size.width * 0.04),

                  // Album info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.name.isEmpty ? 'Sin nombre' : album.name,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: size.width * 0.04,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: size.height * 0.005),
                        Text(
                          isLoading
                              ? 'Cargando...'
                              : isInfoLoaded
                                  ? '$count fotos'
                                  : '...',
                          style: TextStyle(
                            color: isLoading
                                ? colors.primary
                                : colors.textTertiary,
                            fontSize: size.width * 0.035,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Check icon if completed
                  if (isCompleted && !isLoading)
                    Padding(
                      padding: EdgeInsets.only(right: size.width * 0.02),
                      child: Icon(
                        Icons.check_circle,
                        color: colors.success,
                        size: size.width * 0.055,
                      ),
                    ),

                  // Arrow or loading indicator
                  if (isLoading)
                    SizedBox(
                      width: size.width * 0.045,
                      height: size.width * 0.045,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios,
                      color: colors.textTertiary,
                      size: size.width * 0.045,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

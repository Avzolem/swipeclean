import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/storage_service.dart';

/// Info cacheada de un álbum
class AlbumInfo {
  final int count;
  final Uint8List? thumbnail;
  final int reviewedCount;

  AlbumInfo({
    required this.count,
    this.thumbnail,
    this.reviewedCount = 0,
  });

  /// El álbum está completo si todas sus fotos fueron revisadas
  bool get isCompleted => count > 0 && reviewedCount >= count;

  /// Crea una copia con reviewedCount actualizado
  AlbumInfo copyWithReviewedCount(int newReviewedCount) {
    return AlbumInfo(
      count: count,
      thumbnail: thumbnail,
      reviewedCount: newReviewedCount,
    );
  }
}

/// Provider que mantiene el cache de álbumes durante toda la sesión
class AlbumsProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  final Map<String, AlbumInfo> _cache = {};
  final Set<String> _loadingIds = {};
  bool _isProcessingQueue = false;
  final List<AssetPathEntity> _loadQueue = [];

  /// Obtiene la info de un álbum del cache
  AlbumInfo? getAlbumInfo(String albumId) => _cache[albumId];

  /// Verifica si un álbum está en cache
  bool hasAlbumInfo(String albumId) => _cache.containsKey(albumId);

  /// Verifica si un álbum está cargando
  bool isLoading(String albumId) => _loadingIds.contains(albumId);

  /// Encola un álbum para cargar su info
  void enqueueAlbumLoad(AssetPathEntity album) {
    if (_cache.containsKey(album.id)) return;
    if (_loadingIds.contains(album.id)) return;
    if (_loadQueue.any((a) => a.id == album.id)) return;

    _loadQueue.add(album);
    _processQueue();
  }

  /// Procesa la cola de carga de forma escalonada
  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_loadQueue.isNotEmpty) {
      final album = _loadQueue.removeAt(0);

      if (_cache.containsKey(album.id)) continue;

      _loadingIds.add(album.id);
      notifyListeners();

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

        _cache[album.id] = AlbumInfo(
          count: count,
          thumbnail: thumbnail,
          reviewedCount: reviewedCount,
        );
      } catch (e) {
        // Ignorar errores silenciosamente
      }

      _loadingIds.remove(album.id);
      notifyListeners();

      // Pequeño delay entre cargas para no saturar
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _isProcessingQueue = false;
  }

  /// Recalcula solo el estado de completado sin recargar thumbnails
  Future<void> recalculateCompletedStatus(List<AssetPathEntity> albums) async {
    for (final album in albums) {
      final existingInfo = _cache[album.id];
      if (existingInfo == null) continue;

      try {
        final assets = await album.getAssetListRange(
          start: 0,
          end: existingInfo.count,
        );
        int reviewedCount = 0;

        for (final asset in assets) {
          if (_storageService.isReviewed(asset.id) ||
              _storageService.isInTrash(asset.id)) {
            reviewedCount++;
          }
        }

        // Solo actualizar si cambió el reviewedCount
        if (existingInfo.reviewedCount != reviewedCount) {
          _cache[album.id] = existingInfo.copyWithReviewedCount(reviewedCount);
          notifyListeners();
        }
      } catch (e) {
        // Ignorar errores
      }
    }
  }

  /// Limpia el cache (útil si se necesita recargar todo)
  void clearCache() {
    _cache.clear();
    _loadQueue.clear();
    _loadingIds.clear();
    notifyListeners();
  }
}

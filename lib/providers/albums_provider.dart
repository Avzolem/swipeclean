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
          // Obtener assets para thumbnail y cálculo de reviewedCount
          // Limitamos a los primeros 100 para balance entre precisión y rendimiento
          final assetsToCheck = count > 100 ? 100 : count;
          final assets = await album.getAssetListRange(start: 0, end: assetsToCheck);

          if (assets.isNotEmpty) {
            // Obtener thumbnail del primer asset
            thumbnail = await assets.first.thumbnailDataWithSize(
              const ThumbnailSize(200, 200),
            );

            // Calcular reviewedCount (extrapolando si hay más de 100)
            int reviewed = 0;
            for (final asset in assets) {
              if (_storageService.isReviewed(asset.id) ||
                  _storageService.isInTrash(asset.id)) {
                reviewed++;
              }
            }

            // Si tenemos menos de 100 fotos, es el conteo exacto
            // Si tenemos más, extrapolamos proporcionalmente
            if (count <= 100) {
              reviewedCount = reviewed;
            } else {
              reviewedCount = (reviewed * count / assetsToCheck).round();
            }
          }
        }

        // Guardar en cache con reviewedCount calculado
        _cache[album.id] = AlbumInfo(
          count: count,
          thumbnail: thumbnail,
          reviewedCount: reviewedCount,
        );
      } catch (e) {
        // Error al cargar álbum (permisos, álbum eliminado, etc.)
      }

      _loadingIds.remove(album.id);
      notifyListeners();

      // Pequeño delay entre cargas para no saturar
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _isProcessingQueue = false;
  }

  /// Recalcula solo el estado de completado sin recargar thumbnails
  /// Optimizado: solo notifica una vez al final para evitar múltiples rebuilds
  Future<void> recalculateCompletedStatus(List<AssetPathEntity> albums) async {
    bool hasChanges = false;

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
          hasChanges = true;
        }
      } catch (e) {
        // Ignorar errores - el álbum puede no existir
      }
    }

    // Notificar solo una vez al final si hubo cambios
    if (hasChanges) {
      notifyListeners();
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

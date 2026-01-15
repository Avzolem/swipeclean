import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';
import '../models/photo.dart';
import 'storage_service.dart';

/// Detector de fotos duplicadas optimizado
/// Usa dHash (Difference Hash) + pre-filtro por tamaño + Isolate para procesamiento
class DuplicateDetector {
  static const int _threshold = 10; // Hamming distance threshold
  static const int _batchSize = 10; // Procesar en lotes pequeños
  static const int _maxPhotosToCheck = 2000; // Límite
  static const double _sizeTolerancePercent = 0.30; // 30% tolerancia de tamaño

  final StorageService _storageService = StorageService();
  bool _isCancelled = false;

  // Caché en memoria para la sesión actual
  final Map<String, int> _sessionHashCache = {};
  final Map<String, int> _sizeCache = {};

  /// Cancela la búsqueda en progreso
  void cancel() {
    _isCancelled = true;
  }

  /// Resetea el estado de cancelación
  void reset() {
    _isCancelled = false;
  }

  /// Encuentra grupos de fotos duplicadas
  Future<List<List<Photo>>> findDuplicates(
    List<Photo> photos, {
    Function(double progress, String status)? onProgress,
  }) async {
    if (photos.length < 2) return [];
    _isCancelled = false;

    // Cargar hashes persistentes al caché de sesión
    final persistentHashes = _storageService.getAllHashes();
    for (final entry in persistentHashes.entries) {
      _sessionHashCache[entry.key] = entry.value.hash;
      _sizeCache[entry.key] = entry.value.size;
    }

    // Limitar fotos para rendimiento
    final photosToCheck = photos.length > _maxPhotosToCheck
        ? photos.sublist(0, _maxPhotosToCheck)
        : photos;

    onProgress?.call(0.0, 'Obteniendo tamaños de archivos...');

    // Fase 1: Obtener tamaños de archivo (muy rápido)
    final List<_PhotoWithSize> photosWithSize = [];
    for (int i = 0; i < photosToCheck.length; i++) {
      if (_isCancelled) return [];

      final photo = photosToCheck[i];
      int size;

      if (_sizeCache.containsKey(photo.id)) {
        size = _sizeCache[photo.id]!;
      } else {
        size = (photo.asset.size.width * photo.asset.size.height).toInt();
        _sizeCache[photo.id] = size;
      }

      photosWithSize.add(_PhotoWithSize(photo, size));

      if (i % 20 == 0 || i == photosToCheck.length - 1) {
        onProgress?.call(
          (i / photosToCheck.length) * 0.1,
          'Analizando tamaños: ${i + 1}/${photosToCheck.length}',
        );
        await Future.delayed(Duration.zero);
      }
    }

    if (_isCancelled) return [];

    // Fase 2: Agrupar por rangos de tamaño similar
    onProgress?.call(0.1, 'Agrupando por tamaño...');
    photosWithSize.sort((a, b) => a.size.compareTo(b.size));

    final List<List<_PhotoWithSize>> sizeGroups = _groupBySimilarSize(photosWithSize);

    if (_isCancelled) return [];

    // Fase 3: Calcular hashes con Isolate para grupos potencialmente duplicados
    onProgress?.call(0.15, 'Calculando hashes...');
    final List<_PhotoHash> allHashes = [];
    int processedPhotos = 0;
    int totalPhotosInGroups = sizeGroups.fold(0, (sum, g) => sum + g.length);

    for (final group in sizeGroups) {
      if (_isCancelled) return [];

      if (group.length < 2) {
        processedPhotos += group.length;
        continue;
      }

      // Procesar en lotes dentro del grupo
      for (int i = 0; i < group.length; i += _batchSize) {
        if (_isCancelled) return [];

        final end = (i + _batchSize > group.length) ? group.length : i + _batchSize;
        final batch = group.sublist(i, end);

        // Calcular hashes en paralelo usando Isolates
        final futures = batch.map((pw) => _calculateDHashWithIsolate(pw.photo));
        final results = await Future.wait(futures);

        for (int j = 0; j < results.length; j++) {
          if (results[j] != null) {
            allHashes.add(_PhotoHash(batch[j].photo, results[j]!, batch[j].size));
          }
        }

        processedPhotos += batch.length;
        onProgress?.call(
          0.15 + (processedPhotos / totalPhotosInGroups) * 0.55,
          'Analizando fotos: $processedPhotos/$totalPhotosInGroups',
        );

        await Future.delayed(Duration.zero);
      }
    }

    if (_isCancelled) return [];

    // Fase 4: Comparar hashes y encontrar duplicados
    onProgress?.call(0.7, 'Comparando similitud...');
    final List<List<Photo>> duplicateGroups = await _findSimilarPhotos(
      allHashes,
      onProgress: (p) {
        if (!_isCancelled) {
          onProgress?.call(0.7 + p * 0.3, 'Agrupando duplicados...');
        }
      },
    );

    if (_isCancelled) return [];

    // Guardar resultados para modo offline
    final groupIds = duplicateGroups.map((g) => g.map((p) => p.id).toList()).toList();
    await _storageService.saveDuplicateResult(groupIds, photosToCheck.length);

    onProgress?.call(1.0, '¡Completado!');
    return duplicateGroups;
  }

  /// Agrupa fotos por tamaño similar
  List<List<_PhotoWithSize>> _groupBySimilarSize(List<_PhotoWithSize> sorted) {
    if (sorted.isEmpty) return [];

    final List<List<_PhotoWithSize>> groups = [];
    List<_PhotoWithSize> currentGroup = [sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      final current = sorted[i];
      final groupFirst = currentGroup.first;

      final sizeDiff = (current.size - groupFirst.size).abs();
      final tolerance = groupFirst.size * _sizeTolerancePercent;

      if (sizeDiff <= tolerance) {
        currentGroup.add(current);
      } else {
        if (currentGroup.length >= 2) {
          groups.add(currentGroup);
        }
        currentGroup = [current];
      }
    }

    if (currentGroup.length >= 2) {
      groups.add(currentGroup);
    }

    return groups;
  }

  /// Calcula el dHash usando Isolate para no bloquear el hilo principal
  Future<int?> _calculateDHashWithIsolate(Photo photo) async {
    // Verificar caché primero
    if (_sessionHashCache.containsKey(photo.id)) {
      return _sessionHashCache[photo.id];
    }

    // Verificar caché persistente
    final persistentHash = _storageService.getHash(photo.id);
    if (persistentHash != null) {
      _sessionHashCache[photo.id] = persistentHash.hash;
      return persistentHash.hash;
    }

    try {
      // Obtener thumbnail
      final Uint8List? thumbData = await photo.asset.thumbnailDataWithSize(
        const ThumbnailSize(64, 64),
        quality: 50,
      );

      if (thumbData == null) return null;

      // Calcular hash en Isolate
      final hash = await Isolate.run(() => _computeDHash(thumbData));

      if (hash != null) {
        // Guardar en caché de sesión
        _sessionHashCache[photo.id] = hash;

        // Guardar persistente (asíncrono)
        final size = (photo.asset.size.width * photo.asset.size.height).toInt();
        _storageService.saveHash(photo.id, hash, size);
      }

      return hash;
    } catch (e) {
      return null;
    }
  }

  /// Función estática para ejecutar en Isolate
  static int? _computeDHash(Uint8List imageData) {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return null;

      // Redimensionar a 9x8 para dHash
      final resized = img.copyResize(image, width: 9, height: 8);
      final grayscale = img.grayscale(resized);

      // Calcular dHash: comparar cada pixel con el de su derecha
      int hash = 0;
      int bitIndex = 0;

      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final leftPixel = grayscale.getPixel(x, y);
          final rightPixel = grayscale.getPixel(x + 1, y);

          final leftLum = img.getLuminance(leftPixel);
          final rightLum = img.getLuminance(rightPixel);

          if (leftLum > rightLum) {
            hash |= (1 << bitIndex);
          }
          bitIndex++;
        }
      }

      return hash;
    } catch (e) {
      return null;
    }
  }

  /// Encuentra fotos similares basándose en la distancia de Hamming
  Future<List<List<Photo>>> _findSimilarPhotos(
    List<_PhotoHash> hashes, {
    Function(double)? onProgress,
  }) async {
    final List<List<Photo>> groups = [];
    final Set<String> processed = {};

    for (int i = 0; i < hashes.length; i++) {
      if (_isCancelled) return [];
      if (processed.contains(hashes[i].photo.id)) continue;

      final List<Photo> group = [hashes[i].photo];
      processed.add(hashes[i].photo.id);

      for (int j = i + 1; j < hashes.length; j++) {
        if (processed.contains(hashes[j].photo.id)) continue;

        final sizeDiff = (hashes[i].size - hashes[j].size).abs();
        if (sizeDiff > hashes[i].size * _sizeTolerancePercent) continue;

        final distance = _hammingDistance(hashes[i].hash, hashes[j].hash);

        if (distance <= _threshold) {
          group.add(hashes[j].photo);
          processed.add(hashes[j].photo.id);
        }
      }

      if (group.length > 1) {
        group.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        groups.add(group);
      }

      if (i % 10 == 0 || i == hashes.length - 1) {
        onProgress?.call(i / hashes.length);
        await Future.delayed(Duration.zero);
      }
    }

    groups.sort((a, b) => b.length.compareTo(a.length));
    return groups;
  }

  /// Calcula la distancia de Hamming entre dos hashes
  int _hammingDistance(int hash1, int hash2) {
    int xor = hash1 ^ hash2;
    int count = 0;
    while (xor != 0) {
      xor &= xor - 1;
      count++;
    }
    return count;
  }

  /// Obtiene los hashes calculados para estadísticas
  int get cachedHashCount => _sessionHashCache.length;

  /// Limpia la caché de sesión (no la persistente)
  void clearSessionCache() {
    _sessionHashCache.clear();
    _sizeCache.clear();
  }
}

class _PhotoWithSize {
  final Photo photo;
  final int size;

  _PhotoWithSize(this.photo, this.size);
}

class _PhotoHash {
  final Photo photo;
  final int hash;
  final int size;

  _PhotoHash(this.photo, this.hash, this.size);
}

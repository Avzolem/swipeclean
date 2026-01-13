import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';
import '../models/photo.dart';

class DuplicateDetector {
  static const int _hashSize = 8;
  static const int _threshold = 5; // Hamming distance threshold
  static const int _batchSize = 50; // Process in batches
  static const int _maxPhotosToCheck = 500; // Limit for performance

  Future<List<List<Photo>>> findDuplicates(
    List<Photo> photos, {
    Function(double)? onProgress,
  }) async {
    if (photos.length < 2) return [];

    // Limit photos for performance
    final photosToCheck = photos.length > _maxPhotosToCheck
        ? photos.sublist(0, _maxPhotosToCheck)
        : photos;

    final List<_PhotoHash> hashList = [];
    int processed = 0;

    // Process in batches for better UI responsiveness
    for (int i = 0; i < photosToCheck.length; i += _batchSize) {
      final end = (i + _batchSize > photosToCheck.length)
          ? photosToCheck.length
          : i + _batchSize;

      final batch = photosToCheck.sublist(i, end);

      // Process batch in parallel
      final futures = batch.map((photo) => _calculateHashFast(photo));
      final results = await Future.wait(futures);

      for (int j = 0; j < results.length; j++) {
        if (results[j] != null) {
          hashList.add(_PhotoHash(batch[j], results[j]!));
        }
      }

      processed += batch.length;
      onProgress?.call(processed / photosToCheck.length * 0.7); // 70% for hashing

      // Yield to UI
      await Future.delayed(Duration.zero);
    }

    // Find duplicates with early exit optimization
    final List<List<Photo>> groups = [];
    final Set<String> processed2 = {};
    final int totalComparisons = hashList.length;

    for (int i = 0; i < hashList.length; i++) {
      if (processed2.contains(hashList[i].photo.id)) continue;

      final List<Photo> group = [hashList[i].photo];
      processed2.add(hashList[i].photo.id);

      for (int j = i + 1; j < hashList.length; j++) {
        if (processed2.contains(hashList[j].photo.id)) continue;

        final distance = _hammingDistanceFast(hashList[i].hash, hashList[j].hash);
        if (distance <= _threshold) {
          group.add(hashList[j].photo);
          processed2.add(hashList[j].photo.id);
        }
      }

      if (group.length > 1) {
        // Sort by date (newest first)
        group.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        groups.add(group);
      }

      onProgress?.call(0.7 + (i / totalComparisons) * 0.3); // 30% for comparison
    }

    return groups;
  }

  Future<int?> _calculateHashFast(Photo photo) async {
    try {
      // Use smaller thumbnail for faster processing
      final Uint8List? thumbData = await photo.asset.thumbnailDataWithSize(
        const ThumbnailSize(32, 32), // Smaller = faster
        quality: 30, // Lower quality = faster
      );

      if (thumbData == null) return null;

      final image = img.decodeImage(thumbData);
      if (image == null) return null;

      // Resize to hash size
      final resized = img.copyResize(image, width: _hashSize, height: _hashSize);

      // Convert to grayscale and calculate hash in one pass
      int sum = 0;
      final List<int> luminances = [];

      for (int y = 0; y < _hashSize; y++) {
        for (int x = 0; x < _hashSize; x++) {
          final pixel = resized.getPixel(x, y);
          final luminance = img.getLuminance(pixel).toInt();
          luminances.add(luminance);
          sum += luminance;
        }
      }

      final average = sum ~/ (_hashSize * _hashSize);

      // Generate hash
      int hash = 0;
      for (int i = 0; i < luminances.length; i++) {
        if (luminances[i] >= average) {
          hash |= (1 << i);
        }
      }

      return hash;
    } catch (e) {
      return null;
    }
  }

  // Optimized Hamming distance using bit operations
  int _hammingDistanceFast(int hash1, int hash2) {
    int xor = hash1 ^ hash2;
    // Brian Kernighan's algorithm - faster for sparse bits
    int count = 0;
    while (xor != 0) {
      xor &= xor - 1;
      count++;
    }
    return count;
  }
}

class _PhotoHash {
  final Photo photo;
  final int hash;

  _PhotoHash(this.photo, this.hash);
}

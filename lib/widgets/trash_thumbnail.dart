import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// Caché global de assets para la papelera
class _TrashAssetCache {
  static final _TrashAssetCache _instance = _TrashAssetCache._internal();
  factory _TrashAssetCache() => _instance;
  _TrashAssetCache._internal();

  final Map<String, AssetEntity?> _assetCache = {};
  final Map<String, Uint8List?> _thumbnailCache = {};
  final Set<String> _loadingAssets = {};
  final Set<String> _loadingThumbnails = {};

  /// Obtiene un asset del caché o lo carga
  Future<AssetEntity?> getAsset(String photoId) async {
    if (_assetCache.containsKey(photoId)) {
      return _assetCache[photoId];
    }

    if (_loadingAssets.contains(photoId)) {
      // Esperar a que termine la carga en progreso
      while (_loadingAssets.contains(photoId)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _assetCache[photoId];
    }

    _loadingAssets.add(photoId);
    try {
      final asset = await AssetEntity.fromId(photoId);
      _assetCache[photoId] = asset;
      return asset;
    } finally {
      _loadingAssets.remove(photoId);
    }
  }

  /// Obtiene un thumbnail del caché o lo carga
  Future<Uint8List?> getThumbnail(String photoId, int size) async {
    if (_thumbnailCache.containsKey(photoId)) {
      return _thumbnailCache[photoId];
    }

    if (_loadingThumbnails.contains(photoId)) {
      while (_loadingThumbnails.contains(photoId)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _thumbnailCache[photoId];
    }

    _loadingThumbnails.add(photoId);
    try {
      final asset = await getAsset(photoId);
      if (asset == null) {
        _thumbnailCache[photoId] = null;
        return null;
      }

      final data = await asset.thumbnailDataWithSize(
        ThumbnailSize(size, size),
        quality: 80,
      );
      _thumbnailCache[photoId] = data;
      return data;
    } finally {
      _loadingThumbnails.remove(photoId);
    }
  }

  /// Limpia el caché de un item específico
  void remove(String photoId) {
    _assetCache.remove(photoId);
    _thumbnailCache.remove(photoId);
  }

  /// Limpia todo el caché
  void clear() {
    _assetCache.clear();
    _thumbnailCache.clear();
  }
}

/// Widget de thumbnail optimizado para la papelera
/// Cachea tanto el asset como el thumbnail para evitar recargas
class TrashThumbnail extends StatefulWidget {
  final String photoId;
  final int size;
  final BoxFit fit;

  const TrashThumbnail({
    super.key,
    required this.photoId,
    this.size = 200,
    this.fit = BoxFit.cover,
  });

  @override
  State<TrashThumbnail> createState() => _TrashThumbnailState();
}

class _TrashThumbnailState extends State<TrashThumbnail> {
  final _TrashAssetCache _cache = _TrashAssetCache();
  Uint8List? _imageData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(TrashThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    setState(() => _isLoading = true);

    try {
      final data = await _cache.getThumbnail(widget.photoId, widget.size);

      if (mounted) {
        setState(() {
          _imageData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (_imageData != null) {
      return Image.memory(
        _imageData!,
        fit: widget.fit,
        gaplessPlayback: true,
      );
    }

    if (_isLoading) {
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: SizedBox(
            width: screenWidth * 0.05,
            height: screenWidth * 0.05,
            child: CircularProgressIndicator(
              strokeWidth: screenWidth * 0.005,
              color: Colors.white30,
            ),
          ),
        ),
      );
    }

    // Error state
    return Container(
      color: Colors.grey[800],
      child: Icon(
        Icons.broken_image,
        color: Colors.white30,
        size: screenWidth * 0.06,
      ),
    );
  }
}

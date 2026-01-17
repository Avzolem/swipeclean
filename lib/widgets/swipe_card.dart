import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../models/photo.dart';
import '../providers/theme_provider.dart';
import '../utils/formatters.dart';

/// Caché global de imágenes precargadas
class ImagePreloadCache {
  static final ImagePreloadCache _instance = ImagePreloadCache._internal();
  factory ImagePreloadCache() => _instance;
  ImagePreloadCache._internal();

  final Map<String, Uint8List> _cache = {};
  final Set<String> _loadingIds = {};
  static const int _maxCacheSize = 10; // Máximo de imágenes en caché

  /// Obtiene una imagen del caché o null si no está
  Uint8List? get(String photoId) => _cache[photoId];

  /// Verifica si una imagen está en caché
  bool has(String photoId) => _cache.containsKey(photoId);

  /// Verifica si una imagen está cargándose
  bool isLoading(String photoId) => _loadingIds.contains(photoId);

  /// Guarda una imagen en el caché
  void put(String photoId, Uint8List data) {
    // Limpiar caché si es muy grande
    if (_cache.length >= _maxCacheSize) {
      final keysToRemove = _cache.keys.take(_cache.length - _maxCacheSize + 1).toList();
      for (final key in keysToRemove) {
        _cache.remove(key);
      }
    }
    _cache[photoId] = data;
    _loadingIds.remove(photoId);
  }

  /// Precarga múltiples fotos
  Future<void> preloadPhotos(List<Photo> photos, {int count = 3}) async {
    for (int i = 0; i < count && i < photos.length; i++) {
      final photo = photos[i];
      if (!has(photo.id) && !isLoading(photo.id)) {
        _loadingIds.add(photo.id);
        _loadPhoto(photo);
      }
    }
  }

  /// Carga una foto individual
  Future<void> _loadPhoto(Photo photo) async {
    try {
      final data = await photo.asset.thumbnailDataWithSize(
        const ThumbnailSize(800, 800),
        quality: 90,
      );
      if (data != null) {
        put(photo.id, data);
      } else {
        _loadingIds.remove(photo.id);
      }
    } catch (e) {
      _loadingIds.remove(photo.id);
    }
  }

  /// Limpia el caché
  void clear() {
    _cache.clear();
    _loadingIds.clear();
  }

  /// Remueve una foto específica del caché
  void remove(String photoId) {
    _cache.remove(photoId);
  }
}

class SwipeCard extends StatefulWidget {
  final Photo photo;
  final double swipeProgress;
  final List<Photo>? nextPhotos; // Fotos siguientes para precargar

  const SwipeCard({
    super.key,
    required this.photo,
    this.swipeProgress = 0,
    this.nextPhotos,
  });

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  final ImagePreloadCache _cache = ImagePreloadCache();
  Uint8List? _imageData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _preloadNextPhotos();
  }

  @override
  void didUpdateWidget(SwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo recargar si cambia la foto
    if (oldWidget.photo.id != widget.photo.id) {
      _loadImage();
      _preloadNextPhotos();
    }
  }

  void _preloadNextPhotos() {
    if (widget.nextPhotos != null && widget.nextPhotos!.isNotEmpty) {
      _cache.preloadPhotos(widget.nextPhotos!, count: 3);
    }
  }

  Future<void> _loadImage() async {
    // Verificar caché primero
    final cachedData = _cache.get(widget.photo.id);
    if (cachedData != null) {
      setState(() {
        _imageData = cachedData;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await widget.photo.asset.thumbnailDataWithSize(
        const ThumbnailSize(800, 800),
        quality: 90,
      );

      if (mounted) {
        if (data != null) {
          _cache.put(widget.photo.id, data);
        }
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

  void _showFullImage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullImageViewer(photo: widget.photo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final themeProvider = context.watch<ThemeProvider>();
    final colors = themeProvider.colors;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size.width * 0.05),
        color: colors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: size.width * 0.05,
            offset: Offset(0, size.height * 0.012),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size.width * 0.05),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo - cacheada para evitar parpadeo
            GestureDetector(
              onTap: () => _showFullImage(context),
              child: Container(
                color: colors.card,
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: colors.textTertiary),
                      )
                    : _imageData != null
                        ? Image.memory(
                            _imageData!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true, // Evita parpadeo
                          )
                        : Center(
                            child: Icon(
                              Icons.broken_image,
                              color: colors.textTertiary,
                              size: size.width * 0.12,
                            ),
                          ),
              ),
            ),

            // Gradient overlay para la info
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: size.height * 0.12,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Swipe indicators
            if (widget.swipeProgress != 0)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size.width * 0.05),
                    border: Border.all(
                      color: widget.swipeProgress < 0 ? colors.danger : colors.success,
                      width: size.width * 0.01,
                    ),
                  ),
                ),
              ),

            // Delete indicator (left swipe)
            if (widget.swipeProgress < -0.1)
              Positioned(
                top: size.height * 0.05,
                right: size.width * 0.05,
                child: Transform.rotate(
                  angle: 0.3,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.04,
                      vertical: size.height * 0.01,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.danger, width: size.width * 0.008),
                      borderRadius: BorderRadius.circular(size.width * 0.02),
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: Text(
                      'ELIMINAR',
                      style: TextStyle(
                        color: colors.danger,
                        fontSize: size.width * 0.06,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            // Keep indicator (right swipe)
            if (widget.swipeProgress > 0.1)
              Positioned(
                top: size.height * 0.05,
                left: size.width * 0.05,
                child: Transform.rotate(
                  angle: -0.3,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.04,
                      vertical: size.height * 0.01,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.success, width: size.width * 0.008),
                      borderRadius: BorderRadius.circular(size.width * 0.02),
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: Text(
                      'CONSERVAR',
                      style: TextStyle(
                        color: colors.success,
                        fontSize: size.width * 0.06,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            // Tap hint icon
            Positioned(
              top: size.height * 0.012,
              right: size.width * 0.025,
              child: Container(
                padding: EdgeInsets.all(size.width * 0.015),
                decoration: BoxDecoration(
                  color: colors.overlay,
                  borderRadius: BorderRadius.circular(size.width * 0.05),
                ),
                child: Icon(
                  Icons.fullscreen,
                  color: colors.textSecondary,
                  size: size.width * 0.05,
                ),
              ),
            ),

            // Photo info
            Positioned(
              left: size.width * 0.05,
              right: size.width * 0.05,
              bottom: size.height * 0.025,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatDate(widget.photo.createdAt),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: size.width * 0.045,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.photo.albumName != null)
                    Text(
                      widget.photo.albumName!,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: size.width * 0.035,
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

}

// Visor de imagen a pantalla completa con zoom
class FullImageViewer extends StatelessWidget {
  final Photo photo;

  const FullImageViewer({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          formatDate(photo.createdAt),
          style: TextStyle(color: Colors.white, fontSize: size.width * 0.04),
        ),
      ),
      body: Center(
        child: FutureBuilder<Uint8List?>(
          future: photo.asset.originBytes,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              );
            }
            // Mientras carga la imagen completa, mostrar thumbnail
            return FutureBuilder<Uint8List?>(
              future: photo.asset.thumbnailDataWithSize(
                const ThumbnailSize(800, 800),
                quality: 90,
              ),
              builder: (context, thumbSnapshot) {
                if (thumbSnapshot.hasData && thumbSnapshot.data != null) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.memory(
                        thumbSnapshot.data!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                      const CircularProgressIndicator(color: Colors.white),
                    ],
                  );
                }
                return const CircularProgressIndicator(color: Colors.white);
              },
            );
          },
        ),
      ),
    );
  }
}

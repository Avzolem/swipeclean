import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo.dart';

class SwipeCard extends StatelessWidget {
  final Photo photo;
  final double swipeProgress;

  const SwipeCard({
    super.key,
    required this.photo,
    this.swipeProgress = 0,
  });

  void _showFullImage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullImageViewer(photo: photo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF16213E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo - ahora con BoxFit.contain para ver completa
            GestureDetector(
              onTap: () => _showFullImage(context),
              child: FutureBuilder<Uint8List?>(
                future: photo.asset.thumbnailDataWithSize(
                  const ThumbnailSize(800, 800),
                  quality: 90,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Container(
                      color: const Color(0xFF16213E),
                      child: Image.memory(
                        snapshot.data!,
                        fit: BoxFit.contain,
                      ),
                    );
                  }
                  return Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                  );
                },
              ),
            ),

            // Gradient overlay para la info
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 100,
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
            if (swipeProgress != 0)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: swipeProgress < 0 ? Colors.red : Colors.green,
                      width: 4,
                    ),
                  ),
                ),
              ),

            // Delete indicator (left swipe)
            if (swipeProgress < -0.1)
              Positioned(
                top: 40,
                right: 20,
                child: Transform.rotate(
                  angle: 0.3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 3),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: const Text(
                      'ELIMINAR',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            // Keep indicator (right swipe)
            if (swipeProgress > 0.1)
              Positioned(
                top: 40,
                left: 20,
                child: Transform.rotate(
                  angle: -0.3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 3),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: const Text(
                      'CONSERVAR',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            // Tap hint icon
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.fullscreen,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ),

            // Photo info
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDate(photo.createdAt),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (photo.albumName != null)
                    Text(
                      photo.albumName!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
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

  String _formatDate(DateTime date) {
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// Visor de imagen a pantalla completa con zoom
class FullImageViewer extends StatelessWidget {
  final Photo photo;

  const FullImageViewer({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
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
          _formatDate(photo.createdAt),
          style: const TextStyle(color: Colors.white, fontSize: 16),
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

  String _formatDate(DateTime date) {
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

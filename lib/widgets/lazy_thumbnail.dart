import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// Widget de thumbnail con lazy loading
/// Solo carga la imagen cuando es visible en pantalla
class LazyThumbnail extends StatefulWidget {
  final AssetEntity asset;
  final int size;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const LazyThumbnail({
    super.key,
    required this.asset,
    this.size = 200,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  State<LazyThumbnail> createState() => _LazyThumbnailState();
}

class _LazyThumbnailState extends State<LazyThumbnail> {
  Uint8List? _imageData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(LazyThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final data = await widget.asset.thumbnailDataWithSize(
        ThumbnailSize(widget.size, widget.size),
        quality: 80,
      );

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
    Widget content;

    if (_imageData != null) {
      content = Image.memory(
        _imageData!,
        fit: widget.fit,
        gaplessPlayback: true,
      );
    } else if (_isLoading) {
      content = Container(
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
    } else {
      content = Container(
        color: Colors.grey[800],
        child: Icon(
          Icons.broken_image,
          color: Colors.white30,
          size: screenWidth * 0.06,
        ),
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }
}

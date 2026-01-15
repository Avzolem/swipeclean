import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../providers/photo_provider.dart';
import 'swipe_screen.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  bool _isLoadingAlbum = false;
  String? _loadingAlbumId;

  Future<void> _onAlbumTap(AssetPathEntity album, PhotoProvider provider) async {
    // Prevenir múltiples taps mientras se carga
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _isLoadingAlbum ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Álbumes',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Consumer<PhotoProvider>(
        builder: (context, provider, _) {
          final albums = provider.albums;

          if (albums.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return _AlbumTile(
                album: album,
                isLoading: _loadingAlbumId == album.id,
                isDisabled: _isLoadingAlbum && _loadingAlbumId != album.id,
                onTap: () => _onAlbumTap(album, provider),
              );
            },
          );
        },
      ),
    );
  }
}

class _AlbumTile extends StatefulWidget {
  final AssetPathEntity album;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isDisabled;

  const _AlbumTile({
    required this.album,
    required this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
  });

  @override
  State<_AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends State<_AlbumTile> {
  int _count = 0;
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    _loadAlbumInfo();
  }

  Future<void> _loadAlbumInfo() async {
    final count = await widget.album.assetCountAsync;

    if (count > 0) {
      final assets = await widget.album.getAssetListRange(start: 0, end: 1);
      if (assets.isNotEmpty) {
        final thumb = await assets.first.thumbnailDataWithSize(
          const ThumbnailSize(200, 200),
        );
        if (mounted) {
          setState(() {
            _count = count;
            _thumbnail = thumb;
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() => _count = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = _count > 0 && !widget.isDisabled && !widget.isLoading;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: widget.isDisabled ? 0.5 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? widget.onTap : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isLoading
                      ? const Color(0xFF6C63FF).withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                  width: widget.isLoading ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Album thumbnail
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _thumbnail != null
                        ? Image.memory(_thumbnail!, fit: BoxFit.cover)
                        : Icon(
                            Icons.photo_album,
                            color: Colors.white.withOpacity(0.3),
                            size: 30,
                          ),
                  ),
                  const SizedBox(width: 16),

                  // Album info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.album.name.isEmpty ? 'Sin nombre' : widget.album.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.isLoading ? 'Cargando...' : '$_count fotos',
                          style: TextStyle(
                            color: widget.isLoading
                                ? const Color(0xFF6C63FF)
                                : Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow or loading indicator
                  if (widget.isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF6C63FF),
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white.withOpacity(0.3),
                      size: 18,
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

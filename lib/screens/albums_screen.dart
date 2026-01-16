import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../providers/photo_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
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
              return _AlbumTile(
                album: album,
                colors: colors,
                size: size,
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
  final ThemeColors colors;
  final Size size;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isDisabled;

  const _AlbumTile({
    required this.album,
    required this.colors,
    required this.size,
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
    final thumbnailSize = widget.size.width * 0.18;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.size.height * 0.015),
      child: Opacity(
        opacity: widget.isDisabled ? 0.5 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? widget.onTap : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(widget.size.width * 0.03),
              decoration: BoxDecoration(
                color: widget.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isLoading
                      ? widget.colors.primaryWithOpacity(0.5)
                      : widget.colors.divider,
                  width: widget.isLoading ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Album thumbnail
                  Container(
                    width: thumbnailSize,
                    height: thumbnailSize,
                    decoration: BoxDecoration(
                      color: widget.colors.primaryWithOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _thumbnail != null
                        ? Image.memory(_thumbnail!, fit: BoxFit.cover)
                        : Icon(
                            Icons.photo_album,
                            color: widget.colors.textTertiary,
                            size: widget.size.width * 0.08,
                          ),
                  ),
                  SizedBox(width: widget.size.width * 0.04),

                  // Album info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.album.name.isEmpty ? 'Sin nombre' : widget.album.name,
                          style: TextStyle(
                            color: widget.colors.textPrimary,
                            fontSize: widget.size.width * 0.04,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: widget.size.height * 0.005),
                        Text(
                          widget.isLoading ? 'Cargando...' : '$_count fotos',
                          style: TextStyle(
                            color: widget.isLoading
                                ? widget.colors.primary
                                : widget.colors.textTertiary,
                            fontSize: widget.size.width * 0.035,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow or loading indicator
                  if (widget.isLoading)
                    SizedBox(
                      width: widget.size.width * 0.045,
                      height: widget.size.width * 0.045,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.colors.primary,
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios,
                      color: widget.colors.textTertiary,
                      size: widget.size.width * 0.045,
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

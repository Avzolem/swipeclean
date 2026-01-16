import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/photo.dart';
import '../models/photo_hash.dart';
import '../providers/photo_provider.dart';
import '../providers/trash_provider.dart';
import '../providers/theme_provider.dart';
import '../services/duplicate_detector.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/lazy_thumbnail.dart';

class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  final DuplicateDetector _detector = DuplicateDetector();
  final StorageService _storageService = StorageService();
  List<List<Photo>> _duplicateGroups = [];
  bool _isLoading = true;
  bool _isUsingCachedResults = false;
  double _progress = 0;
  String _statusText = 'Iniciando...';
  final Set<String> _selectedPhotos = {};
  int _totalPhotosAnalyzed = 0;
  int _estimatedSpaceBytes = 0;
  DateTime? _lastScanDate;

  @override
  void initState() {
    super.initState();
    _checkCachedResults();
  }

  @override
  void dispose() {
    _detector.cancel();
    super.dispose();
  }

  Future<void> _checkCachedResults() async {
    final cachedResult = _storageService.getLastDuplicateResult();

    if (cachedResult != null && cachedResult.groups.isNotEmpty) {
      // Tenemos resultados en caché, preguntar al usuario
      if (mounted) {
        final themeProvider = context.read<ThemeProvider>();
        final colors = themeProvider.colors;
        final useCache = await _showCacheDialog(cachedResult, colors);
        if (useCache == true) {
          await _loadCachedResults(cachedResult);
          return;
        }
      }
    }

    // Si no hay caché o el usuario quiere re-escanear
    _findDuplicates();
  }

  Future<bool?> _showCacheDialog(DuplicateResult cached, ThemeColors colors) {
    final timeSince = DateTime.now().difference(cached.scannedAt);
    String timeText;

    if (timeSince.inMinutes < 60) {
      timeText = 'hace ${timeSince.inMinutes} minutos';
    } else if (timeSince.inHours < 24) {
      timeText = 'hace ${timeSince.inHours} horas';
    } else {
      timeText = 'hace ${timeSince.inDays} días';
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Resultados anteriores',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se encontraron ${cached.groups.length} grupos de duplicados $timeText.',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              '¿Deseas ver esos resultados o hacer un nuevo escaneo?',
              style: TextStyle(color: colors.textTertiary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Nuevo escaneo', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
            ),
            child: const Text('Ver anteriores', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCachedResults(DuplicateResult cached) async {
    setState(() {
      _isLoading = true;
      _statusText = 'Cargando resultados...';
    });

    final photoProvider = context.read<PhotoProvider>();
    final photos = photoProvider.photos;

    // Crear mapa de fotos por ID para búsqueda rápida
    final photoMap = <String, Photo>{};
    for (final photo in photos) {
      photoMap[photo.id] = photo;
    }

    // Reconstruir grupos de fotos desde IDs
    final groups = <List<Photo>>[];
    for (final groupIds in cached.groups) {
      final group = <Photo>[];
      for (final id in groupIds) {
        final photo = photoMap[id];
        if (photo != null) {
          group.add(photo);
        }
      }
      // Solo agregar grupos que aún tengan 2+ fotos
      if (group.length >= 2) {
        groups.add(group);
      }
    }

    _calculateEstimatedSpace(groups);

    if (mounted) {
      setState(() {
        _duplicateGroups = groups;
        _totalPhotosAnalyzed = cached.totalPhotosAnalyzed;
        _lastScanDate = cached.scannedAt;
        _isUsingCachedResults = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _findDuplicates() async {
    setState(() {
      _isLoading = true;
      _isUsingCachedResults = false;
    });

    final photoProvider = context.read<PhotoProvider>();
    final photos = photoProvider.photos;

    if (photos.isEmpty) {
      setState(() {
        _isLoading = false;
        _statusText = 'No hay fotos';
      });
      return;
    }

    _totalPhotosAnalyzed = photos.length;

    final groups = await _detector.findDuplicates(
      photos,
      onProgress: (progress, status) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _statusText = status;
          });
        }
      },
    );

    _calculateEstimatedSpace(groups);

    if (mounted) {
      setState(() {
        _duplicateGroups = groups;
        _lastScanDate = DateTime.now();
        _isLoading = false;
      });
    }
  }

  void _calculateEstimatedSpace(List<List<Photo>> groups) {
    int totalBytes = 0;
    for (final group in groups) {
      // Sumar tamaño de todos excepto el primero (que se conservaría)
      for (int i = 1; i < group.length; i++) {
        // Usar dimensiones como aproximación del tamaño
        final width = group[i].asset.width;
        final height = group[i].asset.height;
        // Aproximación: 3 bytes por pixel para JPEG comprimido
        totalBytes += (width * height * 0.5).toInt();
      }
    }
    _estimatedSpaceBytes = totalBytes;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _cancelSearch() {
    _detector.cancel();
    Navigator.pop(context);
  }

  void _selectAllDuplicates() {
    setState(() {
      _selectedPhotos.clear();
      for (final group in _duplicateGroups) {
        for (int i = 1; i < group.length; i++) {
          _selectedPhotos.add(group[i].id);
        }
      }
    });
  }

  int _calculateSelectedSpace() {
    int bytes = 0;
    for (final group in _duplicateGroups) {
      for (final photo in group) {
        if (_selectedPhotos.contains(photo.id)) {
          final width = photo.asset.width;
          final height = photo.asset.height;
          bytes += (width * height * 0.5).toInt();
        }
      }
    }
    return bytes;
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
          onPressed: _isLoading ? _cancelSearch : () => Navigator.pop(context),
        ),
        title: Text(
          _isLoading ? 'Analizando...' : 'Fotos duplicadas',
          style: TextStyle(color: colors.textPrimary),
        ),
        actions: [
          if (!_isLoading && _duplicateGroups.isNotEmpty) ...[
            if (_isUsingCachedResults)
              IconButton(
                icon: Icon(Icons.refresh, color: colors.textSecondary),
                tooltip: 'Re-escanear',
                onPressed: () {
                  _detector.reset();
                  _findDuplicates();
                },
              ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: colors.textPrimary),
              color: colors.surface,
              onSelected: (value) {
                if (value == 'select_all') {
                  _selectAllDuplicates();
                } else if (value == 'clear') {
                  setState(() => _selectedPhotos.clear());
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'select_all',
                  child: Row(
                    children: [
                      Icon(Icons.select_all, color: colors.textSecondary, size: 20),
                      const SizedBox(width: 8),
                      Text('Seleccionar duplicados',
                          style: TextStyle(color: colors.textPrimary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, color: colors.textSecondary, size: 20),
                      const SizedBox(width: 8),
                      Text('Limpiar selección',
                          style: TextStyle(color: colors.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoading ? _buildLoadingState(size, colors) : _buildContent(size, colors),
      bottomNavigationBar: !_isLoading && _selectedPhotos.isNotEmpty
          ? _buildBottomBar(size, colors)
          : null,
    );
  }

  Widget _buildBottomBar(Size size, ThemeColors colors) {
    final selectedSpace = _calculateSelectedSpace();

    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.divider),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedPhotos.length} fotos seleccionadas',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: size.width * 0.038,
                    ),
                  ),
                  Text(
                    '~${_formatBytes(selectedSpace)} a liberar',
                    style: TextStyle(
                      color: colors.success,
                      fontSize: size.width * 0.032,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _addSelectedToTrash(colors),
              icon: const Icon(Icons.delete, color: Colors.white),
              label: const Text('Mover a papelera',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.danger,
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.04,
                  vertical: size.height * 0.015,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(Size size, ThemeColors colors) {
    final cachedHashes = _storageService.hashCount;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(size.width * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: size.width * 0.2,
              height: size.width * 0.2,
              child: CircularProgressIndicator(
                value: _progress > 0 ? _progress : null,
                color: colors.primary,
                strokeWidth: 4,
              ),
            ),
            SizedBox(height: size.height * 0.04),
            Text(
              'Buscando duplicados',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: size.width * 0.05,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: size.height * 0.015),
            Text(
              _statusText,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: size.width * 0.035,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: size.height * 0.02),
            Text(
              '${(_progress * 100).toStringAsFixed(2)}%',
              style: TextStyle(
                color: colors.primary,
                fontSize: size.width * 0.06,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: size.height * 0.015),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: colors.divider,
                  valueColor: AlwaysStoppedAnimation(colors.primary),
                  minHeight: 8,
                ),
              ),
            ),
            if (cachedHashes > 0) ...[
              SizedBox(height: size.height * 0.02),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.03,
                  vertical: size.height * 0.008,
                ),
                decoration: BoxDecoration(
                  color: colors.successWithOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flash_on,
                      color: colors.success,
                      size: size.width * 0.04,
                    ),
                    SizedBox(width: size.width * 0.01),
                    Text(
                      '$cachedHashes hashes en caché',
                      style: TextStyle(
                        color: colors.success,
                        fontSize: size.width * 0.03,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: size.height * 0.04),
            TextButton.icon(
              onPressed: _cancelSearch,
              icon: Icon(
                Icons.close,
                color: colors.textSecondary,
              ),
              label: Text(
                'Cancelar',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: size.width * 0.04,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Size size, ThemeColors colors) {
    if (_duplicateGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(size.width * 0.08),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: size.width * 0.2,
                color: colors.success.withOpacity(0.7),
              ),
              SizedBox(height: size.height * 0.02),
              Text(
                '¡Sin duplicados!',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: size.width * 0.055,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: size.height * 0.01),
              Text(
                'No se encontraron fotos duplicadas\nen las $_totalPhotosAnalyzed fotos analizadas',
                style: TextStyle(
                  color: colors.textTertiary,
                  fontSize: size.width * 0.035,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: size.height * 0.04),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.08,
                    vertical: size.height * 0.018,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Volver',
                  style: TextStyle(
                    fontSize: size.width * 0.04,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalDuplicates = _duplicateGroups.fold<int>(
      0,
      (sum, group) => sum + group.length - 1,
    );

    return Column(
      children: [
        // Summary header
        Container(
          padding: EdgeInsets.all(size.width * 0.04),
          color: colors.surface,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.content_copy,
                    color: colors.warning,
                    size: size.width * 0.06,
                  ),
                  SizedBox(width: size.width * 0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_duplicateGroups.length} grupos encontrados',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: size.width * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$totalDuplicates fotos duplicadas',
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: size.width * 0.03,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.025,
                      vertical: size.height * 0.008,
                    ),
                    decoration: BoxDecoration(
                      color: colors.successWithOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '~${_formatBytes(_estimatedSpaceBytes)}',
                          style: TextStyle(
                            color: colors.success,
                            fontSize: size.width * 0.035,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'a liberar',
                          style: TextStyle(
                            color: colors.success.withOpacity(0.7),
                            fontSize: size.width * 0.025,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isUsingCachedResults && _lastScanDate != null) ...[
                SizedBox(height: size.height * 0.01),
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: colors.textTertiary,
                      size: size.width * 0.035,
                    ),
                    SizedBox(width: size.width * 0.01),
                    Text(
                      'Resultados del ${_lastScanDate!.day}/${_lastScanDate!.month} ${_lastScanDate!.hour}:${_lastScanDate!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: size.width * 0.028,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Groups list with lazy loading
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(size.width * 0.04),
            itemCount: _duplicateGroups.length,
            cacheExtent: 500, // Precargar items cercanos
            itemBuilder: (context, groupIndex) {
              final group = _duplicateGroups[groupIndex];
              return _buildDuplicateGroup(group, groupIndex, size, colors);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicateGroup(List<Photo> group, int groupIndex, Size size, ThemeColors colors) {
    final selectedInGroup =
        group.where((p) => _selectedPhotos.contains(p.id)).length;

    return Container(
      margin: EdgeInsets.only(bottom: size.height * 0.02),
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedInGroup > 0
              ? colors.dangerWithOpacity(0.5)
              : colors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.02,
                      vertical: size.height * 0.005,
                    ),
                    decoration: BoxDecoration(
                      color: colors.warningWithOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Grupo ${groupIndex + 1}',
                      style: TextStyle(
                        color: colors.warning,
                        fontSize: size.width * 0.03,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: size.width * 0.02),
                  Text(
                    '${group.length} fotos similares',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: size.width * 0.032,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _selectAllExceptFirst(group),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.02,
                  ),
                ),
                child: Text(
                  'Mantener mejor',
                  style: TextStyle(
                    fontSize: size.width * 0.032,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: size.height * 0.015),
          SizedBox(
            height: size.width * 0.3,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: group.length,
              itemBuilder: (context, photoIndex) {
                final photo = group[photoIndex];
                final isSelected = _selectedPhotos.contains(photo.id);
                final isFirst = photoIndex == 0;

                return GestureDetector(
                  onTap: () => _toggleSelection(photo.id),
                  child: Container(
                    width: size.width * 0.25,
                    margin: EdgeInsets.only(right: size.width * 0.02),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? colors.danger
                            : isFirst
                                ? colors.success
                                : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: LazyThumbnail(
                            asset: photo.asset,
                            size: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            decoration: BoxDecoration(
                              color: colors.dangerWithOpacity(0.4),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: size.width * 0.08,
                              ),
                            ),
                          ),
                        if (isFirst && !isSelected)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: size.width * 0.015,
                                vertical: size.height * 0.003,
                              ),
                              decoration: BoxDecoration(
                                color: colors.success,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Mejor',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: size.width * 0.025,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: size.width * 0.06,
                            height: size.width * 0.06,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.danger
                                  : Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: size.width * 0.04,
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(String photoId) {
    setState(() {
      if (_selectedPhotos.contains(photoId)) {
        _selectedPhotos.remove(photoId);
      } else {
        _selectedPhotos.add(photoId);
      }
    });
  }

  void _selectAllExceptFirst(List<Photo> group) {
    setState(() {
      for (int i = 1; i < group.length; i++) {
        _selectedPhotos.add(group[i].id);
      }
    });
  }

  Future<void> _addSelectedToTrash(ThemeColors colors) async {
    final trashProvider = context.read<TrashProvider>();
    final count = _selectedPhotos.length;

    for (final photoId in _selectedPhotos) {
      await trashProvider.addToTrash(photoId);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count fotos movidas a papelera'),
          backgroundColor: colors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      setState(() {
        for (final group in _duplicateGroups) {
          group.removeWhere((photo) => _selectedPhotos.contains(photo.id));
        }
        _duplicateGroups.removeWhere((group) => group.length < 2);
        _calculateEstimatedSpace(_duplicateGroups);
        _selectedPhotos.clear();
      });

      // Actualizar resultados en caché
      final groupIds = _duplicateGroups.map((g) => g.map((p) => p.id).toList()).toList();
      await _storageService.saveDuplicateResult(groupIds, _totalPhotosAnalyzed);
    }
  }
}

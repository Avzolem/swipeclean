import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../models/photo.dart';
import '../providers/photo_provider.dart';
import '../providers/trash_provider.dart';
import '../services/duplicate_detector.dart';

class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  final DuplicateDetector _detector = DuplicateDetector();
  List<List<Photo>> _duplicateGroups = [];
  bool _isLoading = true;
  double _progress = 0;
  Set<String> _selectedPhotos = {};

  @override
  void initState() {
    super.initState();
    _findDuplicates();
  }

  Future<void> _findDuplicates() async {
    final photoProvider = context.read<PhotoProvider>();
    final photos = photoProvider.photos;

    if (photos.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final groups = await _detector.findDuplicates(
      photos,
      onProgress: (progress) {
        if (mounted) {
          setState(() => _progress = progress);
        }
      },
    );

    if (mounted) {
      setState(() {
        _duplicateGroups = groups;
        _isLoading = false;
      });
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Fotos duplicadas',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_selectedPhotos.isNotEmpty)
            TextButton.icon(
              onPressed: _addSelectedToTrash,
              icon: const Icon(Icons.delete, color: Colors.red),
              label: Text(
                '${_selectedPhotos.length}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF6C63FF)),
          const SizedBox(height: 24),
          const Text(
            'Buscando duplicados...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Text(
            '${(_progress * 100).toInt()}%',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_duplicateGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin duplicados',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No se encontraron fotos duplicadas',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _duplicateGroups.length,
      itemBuilder: (context, groupIndex) {
        final group = _duplicateGroups[groupIndex];
        return _buildDuplicateGroup(group, groupIndex);
      },
    );
  }

  Widget _buildDuplicateGroup(List<Photo> group, int groupIndex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grupo ${groupIndex + 1} (${group.length} fotos)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => _selectAllExceptFirst(group),
                child: const Text('Mantener mejor'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
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
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.red
                            : isFirst
                                ? Colors.green
                                : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: FutureBuilder<Uint8List?>(
                            future: photo.asset.thumbnailDataWithSize(
                              const ThumbnailSize(200, 200),
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Container(color: Colors.grey[800]);
                            },
                          ),
                        ),
                        if (isSelected)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        if (isFirst && !isSelected)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Mejor',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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

  Future<void> _addSelectedToTrash() async {
    final trashProvider = context.read<TrashProvider>();

    for (final photoId in _selectedPhotos) {
      await trashProvider.addToTrash(photoId);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedPhotos.length} fotos movidas a papelera'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        // Remover las fotos seleccionadas de los grupos
        for (final group in _duplicateGroups) {
          group.removeWhere((photo) => _selectedPhotos.contains(photo.id));
        }
        // Remover grupos que quedaron con menos de 2 fotos
        _duplicateGroups.removeWhere((group) => group.length < 2);
        _selectedPhotos.clear();
      });
    }
  }
}

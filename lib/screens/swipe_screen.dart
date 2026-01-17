import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/photo_provider.dart';
import '../providers/trash_provider.dart';
import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/swipe_card.dart';
import '../widgets/swipe_tutorial.dart';
import '../models/photo.dart';
import 'duplicates_screen.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final CardSwiperController _controller = CardSwiperController();
  final StorageService _storageService = StorageService();

  // Historial de acciones para poder deshacer correctamente
  final List<_SwipeAction> _actionHistory = [];

  // Índice actual de la foto visible
  int _currentIndex = 0;

  // Estado para compartir
  bool _isSharing = false;

  // Flag para prevenir rebuilds durante la salida
  bool _isExiting = false;

  // Fotos capturadas al momento de salir (para evitar flashazo)
  List<Photo>? _frozenPhotos;

  // Feedback visual para botones
  String? _feedbackMessage;
  Color? _feedbackColor;

  // Tutorial de primer uso
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    _checkTutorial();
  }

  void _checkTutorial() {
    // Verificar si es la primera vez
    if (!_storageService.isTutorialShown()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _showTutorial = true);
        }
      });
    }
  }

  void _dismissTutorial() {
    _storageService.setTutorialShown();
    setState(() => _showTutorial = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Muestra feedback visual temporal
  void _showFeedback(String message, Color color) {
    setState(() {
      _feedbackMessage = message;
      _feedbackColor = color;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _feedbackMessage = null;
          _feedbackColor = null;
        });
      }
    });
  }

  /// Botón eliminar con feedback
  void _onDeletePressed(ThemeColors colors) {
    _showFeedback('ELIMINAR', colors.danger);
    Future.delayed(const Duration(milliseconds: 150), () {
      _controller.swipe(CardSwiperDirection.left);
    });
  }

  /// Botón conservar con feedback
  void _onKeepPressed(ThemeColors colors) {
    _showFeedback('CONSERVAR', colors.success);
    Future.delayed(const Duration(milliseconds: 150), () {
      _controller.swipe(CardSwiperDirection.right);
    });
  }

  /// Botón undo con feedback
  void _onUndoPressed(ThemeColors colors) {
    if (_actionHistory.isEmpty) return;
    _showFeedback('DESHACER', colors.warning);
    Future.delayed(const Duration(milliseconds: 150), () {
      _controller.undo();
    });
  }

  /// Método centralizado para salir de la pantalla sin flashazo
  void _exitScreen() {
    setState(() {
      _isExiting = true;
      _frozenPhotos = context.read<PhotoProvider>().unreviewedPhotos;
    });
    context.read<PhotoProvider>().refresh();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final themeProvider = context.watch<ThemeProvider>();
    final colors = themeProvider.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _exitScreen();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Stack(
            children: [
              Consumer2<PhotoProvider, TrashProvider>(
                builder: (context, photoProvider, trashProvider, _) {
                  // Si estamos saliendo, usar fotos congeladas o mostrar empty state
                  if (_isExiting) {
                    if (_frozenPhotos == null || _frozenPhotos!.isEmpty) {
                      return _buildEmptyState(size, colors);
                    }
                    // Mantener la UI congelada durante la transición de salida
                    return const SizedBox.shrink();
                  }

                  final photos = photoProvider.unreviewedPhotos;

                  if (photos.isEmpty) {
                    return _buildEmptyState(size, colors);
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final buttonHeight = size.height * 0.12;
                      final appBarHeight = size.height * 0.07;
                      final cardHeight = constraints.maxHeight - buttonHeight - appBarHeight;

                      return Column(
                        children: [
                          // Custom App Bar
                          SizedBox(
                            height: appBarHeight,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                                  onPressed: _exitScreen,
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '${photos.length - _currentIndex} fotos restantes',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: size.width * 0.04,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: size.width * 0.12),
                              ],
                            ),
                          ),

                          // Card area con overlay de feedback
                          SizedBox(
                            height: cardHeight,
                            child: Stack(
                              children: [
                                CardSwiper(
                                  controller: _controller,
                                  cardsCount: photos.length,
                                  numberOfCardsDisplayed: photos.length > 2 ? 3 : photos.length,
                                  backCardOffset: const Offset(0, 25),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: size.width * 0.05,
                                    vertical: size.height * 0.01,
                                  ),
                                  // Solo permitir swipes horizontales
                                  allowedSwipeDirection: const AllowedSwipeDirection.only(
                                    left: true,
                                    right: true,
                                    up: false,
                                    down: false,
                                  ),
                                  // Umbral más bajo para swipe más natural
                                  threshold: 50,
                                  onSwipe: (previousIndex, currentIndex, direction) {
                                    final photo = photos[previousIndex];

                                    if (direction == CardSwiperDirection.left) {
                                      // Guardar acción en historial antes de ejecutar
                                      _actionHistory.add(_SwipeAction(
                                        photoId: photo.id,
                                        wasAddedToTrash: true,
                                      ));
                                      trashProvider.addToTrash(
                                        photo.id,
                                        width: photo.asset.width,
                                        height: photo.asset.height,
                                      );
                                    } else if (direction == CardSwiperDirection.right) {
                                      // Guardar acción en historial antes de ejecutar
                                      _actionHistory.add(_SwipeAction(
                                        photoId: photo.id,
                                        wasAddedToTrash: false,
                                      ));
                                      trashProvider.keepPhoto(photo.id);
                                    }

                                    // Actualizar índice actual
                                    setState(() {
                                      _currentIndex = currentIndex ?? 0;
                                    });

                                    return true;
                                  },
                                  onUndo: (previousIndex, currentIndex, direction) {
                                    // Revertir la última acción del historial
                                    if (_actionHistory.isNotEmpty) {
                                      final lastAction = _actionHistory.removeLast();

                                      if (lastAction.wasAddedToTrash) {
                                        // Si fue agregada a papelera, usar método específico para undo
                                        // que no dispara rebuilds prematuros
                                        trashProvider.undoAddToTrash(lastAction.photoId);
                                      } else {
                                        // Si fue marcada como revisada, desmarcarla
                                        trashProvider.undoKeepPhoto(lastAction.photoId);
                                      }

                                      // Actualizar índice actual (volvemos a la tarjeta restaurada)
                                      setState(() {
                                        _currentIndex = currentIndex;
                                      });

                                      // NO llamar refresh() aquí - el CardSwiper ya restauró la tarjeta
                                      // y llamar refresh causaría desincronización
                                    }
                                    return true;
                                  },
                                  onEnd: () {
                                    _showCompletedDialog(context, colors);
                                  },
                                  cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                                    // Preparar lista de fotos siguientes para precargar
                                    final nextPhotos = <Photo>[];
                                    for (int i = index + 1; i < photos.length && nextPhotos.length < 3; i++) {
                                      nextPhotos.add(photos[i]);
                                    }

                                    return SwipeCard(
                                      photo: photos[index],
                                      swipeProgress: percentThresholdX.toDouble(),
                                      nextPhotos: nextPhotos,
                                    );
                                  },
                                ),
                                // Overlay de feedback para botones
                                if (_feedbackMessage != null)
                                  Center(
                                    child: AnimatedOpacity(
                                      opacity: _feedbackMessage != null ? 1.0 : 0.0,
                                      duration: const Duration(milliseconds: 200),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: size.width * 0.08,
                                          vertical: size.height * 0.02,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: _feedbackColor ?? Colors.white,
                                            width: size.width * 0.008,
                                          ),
                                        ),
                                        child: Text(
                                          _feedbackMessage ?? '',
                                          style: TextStyle(
                                            color: _feedbackColor ?? Colors.white,
                                            fontSize: size.width * 0.07,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Action buttons
                          SizedBox(
                            height: buttonHeight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildActionButton(
                                  Icons.close,
                                  colors.danger,
                                  () => _onDeletePressed(colors),
                                  size,
                                ),
                                _buildActionButton(
                                  Icons.undo,
                                  colors.warning,
                                  _actionHistory.isNotEmpty
                                      ? () => _onUndoPressed(colors)
                                      : null,
                                  size,
                                ),
                                _buildActionButton(
                                  Icons.share,
                                  colors.info,
                                  _isSharing || _currentIndex >= photos.length
                                      ? null
                                      : () => _sharePhoto(photos[_currentIndex]),
                                  size,
                                ),
                                _buildActionButton(
                                  Icons.favorite,
                                  colors.success,
                                  () => _onKeepPressed(colors),
                                  size,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              // Tutorial overlay
              if (_showTutorial)
                GestureDetector(
                  onTap: _dismissTutorial,
                  child: SwipeTutorial(onDismiss: _dismissTutorial),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Size size, ThemeColors colors) {
    final trashProvider = context.read<TrashProvider>();
    final hasTrash = trashProvider.trashCount > 0;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(size.width * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: size.width * 0.2,
              color: colors.success,
            ),
            SizedBox(height: size.height * 0.03),
            Text(
              '¡Todo limpio!',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: size.width * 0.07,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: size.height * 0.015),
            Text(
              'Has revisado todas las fotos',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: size.width * 0.04,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasTrash) ...[
              SizedBox(height: size.height * 0.01),
              Text(
                '${trashProvider.trashCount} fotos en papelera',
                style: TextStyle(
                  color: colors.warning.withOpacity(0.8),
                  fontSize: size.width * 0.035,
                ),
              ),
            ],
            SizedBox(height: size.height * 0.04),

            // Botón principal
            ElevatedButton(
              onPressed: _exitScreen,
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
                'Volver al inicio',
                style: TextStyle(fontSize: size.width * 0.04, color: Colors.white),
              ),
            ),

            SizedBox(height: size.height * 0.02),

            // Botón para reiniciar
            TextButton.icon(
              onPressed: () => _showResetDialog(context, size, colors),
              icon: Icon(
                Icons.refresh,
                color: colors.textSecondary,
                size: size.width * 0.05,
              ),
              label: Text(
                'Revisar de nuevo',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: size.width * 0.035,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, Size size, ThemeColors colors) {
    final trashProvider = context.read<TrashProvider>();
    final photoProvider = context.read<PhotoProvider>();
    final selectedAlbum = photoProvider.selectedAlbum;
    final hasAlbum = selectedAlbum != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Revisar de nuevo',
          style: TextStyle(color: colors.textPrimary, fontSize: size.width * 0.045),
        ),
        content: Text(
          hasAlbum
              ? '¿Qué deseas reiniciar del álbum "${selectedAlbum.name}"?'
              : '¿Qué deseas hacer?',
          style: TextStyle(color: colors.textSecondary, fontSize: size.width * 0.035),
        ),
        actions: [
          // Este álbum / Solo conservadas
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (hasAlbum) {
                // Reiniciar solo las fotos del álbum actual
                final albumPhotoIds = photoProvider.photos.map((p) => p.id).toList();
                await trashProvider.resetAlbum(albumPhotoIds);
              } else {
                await trashProvider.resetKeptPhotosOnly();
              }
              photoProvider.refresh();
              setState(() {
                _currentIndex = 0;
                _actionHistory.clear();
                _isExiting = false;
                _frozenPhotos = null;
              });
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colors.primary),
            ),
            child: Text(
              hasAlbum ? 'Este álbum' : 'Conservadas',
              style: TextStyle(fontSize: size.width * 0.032),
            ),
          ),
          // Todo (incluye papelera)
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await trashProvider.resetAll();
              photoProvider.refresh();
              setState(() {
                _currentIndex = 0;
                _actionHistory.clear();
                _isExiting = false;
                _frozenPhotos = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.warning,
            ),
            child: Text(
              'Todo (incluye papelera)',
              style: TextStyle(fontSize: size.width * 0.032, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    Color color,
    VoidCallback? onTap,
    Size size,
  ) {
    // Tamaño uniforme para los 4 botones
    final buttonSize = size.width * 0.15;
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color, size: buttonSize * 0.5),
        ),
      ),
    );
  }

  Future<void> _sharePhoto(Photo photo) async {
    setState(() => _isSharing = true);

    try {
      // Obtener el archivo de la foto
      final file = await photo.asset.file;

      if (file != null && await file.exists()) {
        // Usar el share sheet nativo del sistema
        await Share.shareXFiles(
          [XFile(file.path)],
          text: null, // Sin texto adicional
        );
      } else {
        // Intentar obtener el archivo original
        final originFile = await photo.asset.originFile;
        if (originFile != null && await originFile.exists()) {
          await Share.shareXFiles(
            [XFile(originFile.path)],
            text: null,
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo acceder al archivo de la foto'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _showCompletedDialog(BuildContext context, ThemeColors colors) {
    final size = MediaQuery.of(context).size;
    final duplicateResult = _storageService.getLastDuplicateResult();
    final hasDuplicates = duplicateResult != null && duplicateResult.groups.isNotEmpty;
    final duplicateCount = hasDuplicates
        ? duplicateResult.groups.fold<int>(0, (sum, g) => sum + g.length - 1)
        : 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¡Listo!',
          style: TextStyle(color: colors.textPrimary, fontSize: size.width * 0.05),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Has revisado todas las fotos. Puedes ir a la papelera para eliminar las fotos marcadas.',
              style: TextStyle(color: colors.textSecondary, fontSize: size.width * 0.035),
            ),
            // Notificación de duplicados si hay
            if (hasDuplicates) ...[
              SizedBox(height: size.height * 0.02),
              Container(
                padding: EdgeInsets.all(size.width * 0.03),
                decoration: BoxDecoration(
                  color: colors.warningWithOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.warningWithOpacity(0.3)),
                ),
                child: Row(
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
                            'Fotos duplicadas detectadas',
                            style: TextStyle(
                              color: colors.warning,
                              fontSize: size.width * 0.035,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$duplicateCount fotos similares encontradas',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: size.width * 0.03,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cierra el dialog
              _exitScreen(); // Sale de SwipeScreen sin flashazo
            },
            child: Text('Volver al inicio', style: TextStyle(fontSize: size.width * 0.035)),
          ),
          if (hasDuplicates)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Cierra el dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const DuplicatesScreen()),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: colors.warning),
              child: Text(
                'Ver duplicadas',
                style: TextStyle(fontSize: size.width * 0.035, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// Clase para almacenar el historial de acciones
class _SwipeAction {
  final String photoId;
  final bool wasAddedToTrash;

  _SwipeAction({
    required this.photoId,
    required this.wasAddedToTrash,
  });
}

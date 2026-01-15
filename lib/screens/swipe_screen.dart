import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/photo_provider.dart';
import '../providers/trash_provider.dart';
import '../widgets/swipe_card.dart';
import '../models/photo.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final CardSwiperController _controller = CardSwiperController();

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Consumer2<PhotoProvider, TrashProvider>(
          builder: (context, photoProvider, trashProvider, _) {
            // Si estamos saliendo, usar fotos congeladas o mostrar empty state
            if (_isExiting) {
              if (_frozenPhotos == null || _frozenPhotos!.isEmpty) {
                return _buildEmptyState(size);
              }
              // Mantener la UI congelada durante la transición de salida
              return const SizedBox.shrink();
            }

            final photos = photoProvider.unreviewedPhotos;

            if (photos.isEmpty) {
              return _buildEmptyState(size);
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
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: _exitScreen,
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '${photos.length - _currentIndex} fotos restantes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: size.width * 0.04,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: size.width * 0.12),
                        ],
                      ),
                    ),

                    // Card area
                    SizedBox(
                      height: cardHeight,
                      child: CardSwiper(
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
                            trashProvider.addToTrash(photo.id);
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

                            // Actualizar índice actual (volvemos al anterior)
                            setState(() {
                              _currentIndex = previousIndex ?? 0;
                            });

                            // NO llamar refresh() aquí - el CardSwiper ya restauró la tarjeta
                            // y llamar refresh causaría desincronización
                          }
                          return true;
                        },
                        onEnd: () {
                          _showCompletedDialog(context);
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
                    ),

                    // Action buttons
                    SizedBox(
                      height: buttonHeight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            Icons.close,
                            Colors.red,
                            () => _controller.swipe(CardSwiperDirection.left),
                            size,
                          ),
                          _buildActionButton(
                            Icons.undo,
                            Colors.amber,
                            _actionHistory.isNotEmpty
                                ? () => _controller.undo()
                                : null,
                            size,
                          ),
                          _buildActionButton(
                            Icons.share,
                            Colors.blue,
                            _isSharing || _currentIndex >= photos.length
                                ? null
                                : () => _sharePhoto(photos[_currentIndex]),
                            size,
                          ),
                          _buildActionButton(
                            Icons.favorite,
                            Colors.green,
                            () => _controller.swipe(CardSwiperDirection.right),
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
      ),
    );
  }

  Widget _buildEmptyState(Size size) {
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
              color: Colors.green,
            ),
            SizedBox(height: size.height * 0.03),
            Text(
              '¡Todo limpio!',
              style: TextStyle(
                color: Colors.white,
                fontSize: size.width * 0.07,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: size.height * 0.015),
            Text(
              'Has revisado todas las fotos',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: size.width * 0.04,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasTrash) ...[
              SizedBox(height: size.height * 0.01),
              Text(
                '${trashProvider.trashCount} fotos en papelera',
                style: TextStyle(
                  color: Colors.orange.withOpacity(0.8),
                  fontSize: size.width * 0.035,
                ),
              ),
            ],
            SizedBox(height: size.height * 0.04),

            // Botón principal
            ElevatedButton(
              onPressed: _exitScreen,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
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
              onPressed: () => _showResetDialog(context, size),
              icon: Icon(
                Icons.refresh,
                color: Colors.white.withOpacity(0.7),
                size: size.width * 0.05,
              ),
              label: Text(
                'Revisar de nuevo',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: size.width * 0.035,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, Size size) {
    final trashProvider = context.read<TrashProvider>();
    final photoProvider = context.read<PhotoProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Revisar de nuevo',
          style: TextStyle(color: Colors.white, fontSize: size.width * 0.045),
        ),
        content: Text(
          '¿Qué deseas hacer?',
          style: TextStyle(color: Colors.white70, fontSize: size.width * 0.035),
        ),
        actions: [
          // Solo revisadas (conservadas)
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await trashProvider.resetReviewProgress();
              photoProvider.refresh();
              setState(() {
                _currentIndex = 0;
                _actionHistory.clear();
                _isExiting = false;
                _frozenPhotos = null;
              });
            },
            child: Text(
              'Solo conservadas',
              style: TextStyle(fontSize: size.width * 0.032),
            ),
          ),
          // Todo (conservadas + papelera)
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
              backgroundColor: Colors.orange,
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

  void _showCompletedDialog(BuildContext context) {
    final size = MediaQuery.of(context).size;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¡Listo!',
          style: TextStyle(color: Colors.white, fontSize: size.width * 0.05),
        ),
        content: Text(
          'Has revisado todas las fotos. Puedes ir a la papelera para eliminar las fotos marcadas.',
          style: TextStyle(color: Colors.white70, fontSize: size.width * 0.035),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cierra el dialog
              _exitScreen(); // Sale de SwipeScreen sin flashazo
            },
            child: Text('Volver al inicio', style: TextStyle(fontSize: size.width * 0.035)),
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

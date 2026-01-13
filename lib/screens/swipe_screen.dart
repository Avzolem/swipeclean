import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:provider/provider.dart';
import '../providers/photo_provider.dart';
import '../providers/trash_provider.dart';
import '../widgets/swipe_card.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final CardSwiperController _controller = CardSwiperController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Consumer2<PhotoProvider, TrashProvider>(
          builder: (context, photoProvider, trashProvider, _) {
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
                            onPressed: () {
                              context.read<PhotoProvider>().refresh();
                              Navigator.pop(context);
                            },
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '${photoProvider.remainingPhotos} fotos restantes',
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
                        onSwipe: (previousIndex, currentIndex, direction) {
                          final photo = photos[previousIndex];

                          if (direction == CardSwiperDirection.left) {
                            trashProvider.addToTrash(photo.id);
                          } else if (direction == CardSwiperDirection.right) {
                            trashProvider.keepPhoto(photo.id);
                          }

                          return true;
                        },
                        onEnd: () {
                          _showCompletedDialog(context);
                        },
                        cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                          return SwipeCard(
                            photo: photos[index],
                            swipeProgress: percentThresholdX.toDouble(),
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
                            () => _controller.undo(),
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
            ),
            SizedBox(height: size.height * 0.04),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
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
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    Color color,
    VoidCallback onTap,
    Size size,
  ) {
    final buttonSize = size.width * 0.14;
    return GestureDetector(
      onTap: onTap,
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
    );
  }

  void _showFeedback(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(milliseconds: 500),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Volver al inicio', style: TextStyle(fontSize: size.width * 0.035)),
          ),
        ],
      ),
    );
  }
}

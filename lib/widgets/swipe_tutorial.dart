import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Overlay de tutorial que explica los gestos de swipe
/// Se muestra solo la primera vez que el usuario entra a SwipeScreen
class SwipeTutorial extends StatefulWidget {
  final VoidCallback onDismiss;

  const SwipeTutorial({super.key, required this.onDismiss});

  @override
  State<SwipeTutorial> createState() => _SwipeTutorialState();
}

class _SwipeTutorialState extends State<SwipeTutorial>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            color: Colors.black.withOpacity(0.85),
            child: SafeArea(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Padding(
                  padding: EdgeInsets.all(size.width * 0.06),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Título
                      Text(
                        '¿Cómo funciona?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size.width * 0.07,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: size.height * 0.04),

                      // Instrucciones
                      _buildInstructionRow(
                        icon: Icons.swipe_left,
                        iconColor: AppColors.danger,
                        title: 'Desliza izquierda',
                        subtitle: 'Enviar a papelera',
                        size: size,
                      ),
                      SizedBox(height: size.height * 0.025),

                      _buildInstructionRow(
                        icon: Icons.swipe_right,
                        iconColor: AppColors.success,
                        title: 'Desliza derecha',
                        subtitle: 'Conservar foto',
                        size: size,
                      ),
                      SizedBox(height: size.height * 0.025),

                      _buildInstructionRow(
                        icon: Icons.touch_app,
                        iconColor: AppColors.primary,
                        title: 'Toca la foto',
                        subtitle: 'Ver a pantalla completa',
                        size: size,
                      ),
                      SizedBox(height: size.height * 0.025),

                      _buildInstructionRow(
                        icon: Icons.undo,
                        iconColor: AppColors.warning,
                        title: 'Botón deshacer',
                        subtitle: 'Revertir última acción',
                        size: size,
                      ),

                      SizedBox(height: size.height * 0.05),

                      // Representación visual del gesto
                      _buildSwipeDemo(size),

                      SizedBox(height: size.height * 0.05),

                      // Botón entendido
                      ElevatedButton(
                        onPressed: _dismiss,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(
                            horizontal: size.width * 0.12,
                            vertical: size.height * 0.02,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          '¡Entendido!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size.width * 0.045,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      SizedBox(height: size.height * 0.02),
                      Text(
                        'Toca en cualquier lugar para cerrar',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: size.width * 0.03,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructionRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Size size,
  }) {
    return Row(
      children: [
        Container(
          width: size.width * 0.14,
          height: size.width * 0.14,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: iconColor, width: 2),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: size.width * 0.07,
          ),
        ),
        SizedBox(width: size.width * 0.04),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size.width * 0.042,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: size.width * 0.035,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeDemo(Size size) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.06,
        vertical: size.height * 0.02,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Izquierda - Eliminar
          Column(
            children: [
              Icon(
                Icons.delete,
                color: AppColors.danger,
                size: size.width * 0.08,
              ),
              SizedBox(height: size.height * 0.005),
              Text(
                'ELIMINAR',
                style: TextStyle(
                  color: AppColors.danger,
                  fontSize: size.width * 0.025,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Flechas animadas
          Row(
            children: [
              Icon(
                Icons.arrow_back,
                color: AppColors.danger.withOpacity(0.7),
                size: size.width * 0.05,
              ),
              SizedBox(width: size.width * 0.02),
              Container(
                width: size.width * 0.12,
                height: size.width * 0.12,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Icon(
                  Icons.photo,
                  color: AppColors.primary,
                  size: size.width * 0.06,
                ),
              ),
              SizedBox(width: size.width * 0.02),
              Icon(
                Icons.arrow_forward,
                color: AppColors.success.withOpacity(0.7),
                size: size.width * 0.05,
              ),
            ],
          ),

          // Derecha - Conservar
          Column(
            children: [
              Icon(
                Icons.favorite,
                color: AppColors.success,
                size: size.width * 0.08,
              ),
              SizedBox(height: size.height * 0.005),
              Text(
                'CONSERVAR',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: size.width * 0.025,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

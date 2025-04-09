import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'app_colors.dart';

class LoadingOverlay {
  static OverlayEntry? _overlayEntry;
  
  static void show(BuildContext context, {String message = 'Chargement...'}) {
    // First hide any existing overlay to prevent multiple overlays
    hide();
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? Colors.white : AppColors.primaryGreen;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              _AnimatedLoadingText(
                message: message,
                textStyle: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }
  
  static void hide() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }
}

class _AnimatedLoadingText extends StatefulWidget {
  final String message;
  final TextStyle textStyle;
  
  const _AnimatedLoadingText({
    Key? key,
    required this.message,
    required this.textStyle,
  }) : super(key: key);

  @override
  _AnimatedLoadingTextState createState() => _AnimatedLoadingTextState();
}

class _AnimatedLoadingTextState extends State<_AnimatedLoadingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _dotsAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _dotsAnimation = IntTween(begin: 0, end: 3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        String dots = '';
        for (int i = 0; i < _dotsAnimation.value; i++) {
          dots += '.';
        }
        return Text(
          '${widget.message}$dots',
          style: widget.textStyle,
        );
      },
    );
  }
}

class _HomeTransformationAnimation extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  
  const _HomeTransformationAnimation({
    Key? key,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
  }) : super(key: key);

  @override
  _HomeTransformationAnimationState createState() => _HomeTransformationAnimationState();
}

class _HomeTransformationAnimationState extends State<_HomeTransformationAnimation> 
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _toolsController;
  late AnimationController _fillController;
  late Animation<double> _fillAnimation;
  
  // Service tools that will fall from top to bottom
  final List<IconData> _toolIcons = [
    Icons.plumbing,
    Icons.electrical_services,
    Icons.cleaning_services,
    Icons.handyman,
    Icons.build,
    Icons.brush,
  ];
  
  @override
  void initState() {
    super.initState();
    
    // Main controller for overall animation coordination
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
    
    // Controller for tools falling animation
    _toolsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    
    // Controller for house filling animation
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    
    // House fill animation
    _fillAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fillController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _mainController.dispose();
    _toolsController.dispose();
    _fillController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _toolsController, _fillController]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Glowing background effect
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.primaryColor.withOpacity(0.15),
                    widget.primaryColor.withOpacity(0.05),
                    widget.backgroundColor.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                  radius: 0.8,
                ),
              ),
            ),

            
            // Falling tools animation
            ...List.generate(_toolIcons.length, (index) {
              // Calculate falling position
              final delay = index * 0.15; // Stagger the start of each tool's fall
              final fallProgress = (_toolsController.value - delay) % 1.0;
              
              // Only show tool if it's time for it to fall
              if (fallProgress < 0) return const SizedBox.shrink();
              
              // Calculate horizontal position with slight wobble
              final wobbleAmount = 15.0;
              final wobbleFrequency = 3.0 + index % 3;
              final horizontalOffset = wobbleAmount * math.sin(wobbleFrequency * fallProgress * math.pi);
              
              // Calculate vertical position (top to bottom)
              final verticalPosition = -60 + fallProgress * 180; // Start above, end below
              
              // Calculate tool rotation
              final rotationAmount = 2.0 * math.pi * (index % 3 == 0 ? 1 : -1);
              final rotation = rotationAmount * fallProgress;
              
              // Calculate tool size with slight pulsing
              final basePulse = math.sin(fallProgress * math.pi * 2);
              final toolSize = 18.0 + (basePulse * 2);
              
              // Calculate tool opacity (fade in at start, fade out at end)
              double opacity = 1.0;
              if (fallProgress < 0.1) {
                opacity = fallProgress / 0.1; // Fade in
              } else if (fallProgress > 0.9) {
                opacity = (1.0 - fallProgress) / 0.1; // Fade out
              }
              
              // Calculate tool color
              final colorProgress = (math.sin(fallProgress * math.pi * 2) + 1) / 2;
              final toolColor = Color.lerp(
                widget.secondaryColor, 
                widget.primaryColor,
                colorProgress,
              )!;
              
              return Positioned(
                left: 60 + horizontalOffset,
                top: verticalPosition,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: widget.backgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: toolColor.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                        border: Border.all(
                          color: toolColor.withOpacity(0.2),
                          width: 1.5,
                        ),
                        gradient: RadialGradient(
                          colors: [
                            widget.backgroundColor,
                            Color.lerp(widget.backgroundColor, toolColor, 0.1)!,
                          ],
                          stops: const [0.7, 1.0],
                        ),
                      ),
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              toolColor,
                              Color.lerp(toolColor, Colors.white, 0.3)!,
                            ],
                          ).createShader(bounds);
                        },
                        child: Icon(
                          _toolIcons[index],
                          size: toolSize,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
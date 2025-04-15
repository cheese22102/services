import 'package:flutter/material.dart';

enum SlideDirection {
  leftToRight,
  rightToLeft,
}

class CustomPageTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final SlideDirection direction;

  const CustomPageTransition({
    Key? key,
    required this.child,
    required this.animation,
    required this.direction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOut,
    );

    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) {
        final slideOffset = direction == SlideDirection.leftToRight ? 1.0 : -1.0;
        return Transform.translate(
          offset: Offset(
            (1 - curvedAnimation.value) * slideOffset * MediaQuery.of(context).size.width,
            0.0,
          ),
          child: Opacity(
            opacity: curvedAnimation.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

Map<String, dynamic> getSlideTransitionInfo(SlideDirection direction) {
  return {
    'direction': direction == SlideDirection.leftToRight ? 'leftToRight' : 'rightToLeft',
  };
}
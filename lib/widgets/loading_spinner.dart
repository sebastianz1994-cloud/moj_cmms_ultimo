import 'package:flutter/material.dart';
import 'dart:math' as math;

class LoadingSpinner extends StatefulWidget {
  final double size;
  const LoadingSpinner({super.key, this.size = 100});

  @override
  State<LoadingSpinner> createState() => _LoadingSpinnerState();
}

class _LoadingSpinnerState extends State<LoadingSpinner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
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
        return Transform.rotate(
          // Negative sign for counter-clockwise rotation
          angle: -_controller.value * 2.0 * math.pi,
          child: child,
        );
      },
      child: Image.asset(
        'assets/images/loading_swoosh.png',
        width: widget.size,
        height: widget.size,
        errorBuilder: (context, error, stackTrace) {
          // Fallback if the image is missing
          return Icon(
            Icons.sync,
            size: widget.size,
            color: Colors.blue.shade700,
          );
        },
      ),
    );
  }
}

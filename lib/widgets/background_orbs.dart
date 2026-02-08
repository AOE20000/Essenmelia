import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BackgroundOrbs extends StatelessWidget {
  const BackgroundOrbs({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark background base
        Container(color: const Color(0xFF0F172A)), // slate-900
        // Orb 1 (Purple)
        Positioned(
          top: -100,
          left: -100,
          child:
              Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    duration: 10.seconds,
                    begin: const Offset(1, 1),
                    end: const Offset(1.2, 1.2),
                  )
                  .move(
                    duration: 20.seconds,
                    begin: const Offset(0, 0),
                    end: const Offset(50, 50),
                  ),
        ),

        // Orb 2 (Blue)
        Positioned(
          bottom: -50,
          right: -50,
          child:
              Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    duration: 8.seconds,
                    begin: const Offset(1, 1),
                    end: const Offset(1.3, 1.3),
                  )
                  .move(
                    duration: 15.seconds,
                    begin: const Offset(0, 0),
                    end: const Offset(-30, -30),
                  ),
        ),

        // Blur filter to blend everything
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(color: Colors.transparent),
        ),
      ],
    );
  }
}

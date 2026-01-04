import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SkeletonOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final List<List<double>> sequence;

  const SkeletonOverlay({super.key, required this.controller, required this.sequence});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return CustomPaint(
                painter: SkeletonPainter(
                  currentTime: controller.value.position,
                  totalDuration: controller.value.duration,
                  sequence: sequence,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
      ),
    );
  }
}

class SkeletonPainter extends CustomPainter {
  final Duration currentTime;
  final Duration totalDuration;
  final List<List<double>> sequence;

  SkeletonPainter({required this.currentTime, required this.totalDuration, required this.sequence});

  static const List<List<int>> connections = [
    [0, 1], [0, 2], [1, 3], [2, 4], // Head
    [5, 6], [5, 11], [6, 12], [11, 12], // Torso
    [5, 7], [7, 9], // Left Arm
    [6, 8], [8, 10], // Right Arm
    [11, 13], [13, 15], // Left Leg
    [12, 14], [14, 16], // Right Leg
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (totalDuration.inMilliseconds == 0 || sequence.isEmpty) return;

    final double progress = currentTime.inMilliseconds / totalDuration.inMilliseconds;
    int frameIndex = (progress * (sequence.length - 1)).round();

    if (frameIndex < 0) frameIndex = 0;
    if (frameIndex >= sequence.length) frameIndex = sequence.length - 1;

    final List<double> frameData = sequence[frameIndex];
    final Paint pointPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final Paint linePaint = Paint()
      ..color = Colors.lightGreenAccent
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Helper to get point coordinates
    Offset? getPoint(int index) {
      if (index * 2 + 1 < frameData.length) {
         double x = frameData[index * 2];
         double y = frameData[index * 2 + 1];
         // Simple check for 0,0 which likely means not detected
         if (x == 0 && y == 0) return null;
         return Offset(x * size.width, y * size.height);
      }
      return null;
    }

    // Draw connections
    for (var pair in connections) {
      Offset? p1 = getPoint(pair[0]);
      Offset? p2 = getPoint(pair[1]);

      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, linePaint);
      }
    }

    // Draw points
    for (int i = 0; i < 17; i++) {
        Offset? p = getPoint(i);
        if (p != null) {
            canvas.drawCircle(p, 4.0, pointPaint);
        }
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime;
  }
}

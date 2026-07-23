import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The chat feature (conversation screen + Söhbətlər list) is a
/// deliberate exception to the app's dark theme — a calm, light
/// "messaging" surface, closer to WhatsApp/Telegram than the rest of
/// Meevima. These tokens are shared between both chat screens so they
/// stay pixel-identical; reusing [AppColors] instead would mean
/// fighting a dark-mode palette (white text, dark cards) on what's now
/// a light background.
class ChatLightColors {
  static const ink = Color(0xFF1B2528);
  static const inkSoft = Color(0xFF5B6B70);
  static const inkFaint = Color(0xFF93A2A6);
  static const bg1 = Color(0xFFEEF1F4);
  static const bg2 = Color(0xFFE7ECF1);
  static const bg3 = Color(0xFFEAF3F2);

  /// A step darker/greyer than [bg1]/[bg2] — used where a surface
  /// needs to read as "raised" against the page background (Söhbətlər
  /// search bar, filter chips, chat cards) without an actual shadow.
  static const cardSurface = Color(0xFFDEE3E8);

  static const bubbleTheirs = Colors.white;
  static const bubbleMineStart = Color(0xFFE4FBF7);
  static const composerFill = Color(0xFFE4E8EC);
  static const barTint = Color(0xFFEEF1F4);
  static const onlineGreen = Color(0xFF22A87A);
  static const onlineDot = Color(0xFF2ECC71);
  static const contourLine = Color(0xFF0E3B36);
}

/// Same nested "elevation ring" contour clusters on both chat screens,
/// drawn in a 340x700 reference space and mapped onto the real canvas
/// size per-point (not via `canvas.scale`, which would distort the
/// stroke width unevenly on tall/narrow phone screens).
class ChatContourPainter extends CustomPainter {
  const ChatContourPainter();

  Offset _p(double x, double y, Size size) => Offset(x / 340 * size.width, y / 700 * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = ChatLightColors.contourLine.withValues(alpha: 0.09);

    void closedBlob(List<List<double>> pts) {
      final path = Path()..moveTo(_p(pts[0][0], pts[0][1], size).dx, _p(pts[0][0], pts[0][1], size).dy);
      for (var i = 1; i < pts.length; i += 3) {
        path.cubicTo(
          _p(pts[i][0], pts[i][1], size).dx,
          _p(pts[i][0], pts[i][1], size).dy,
          _p(pts[i + 1][0], pts[i + 1][1], size).dx,
          _p(pts[i + 1][0], pts[i + 1][1], size).dy,
          _p(pts[i + 2][0], pts[i + 2][1], size).dx,
          _p(pts[i + 2][0], pts[i + 2][1], size).dy,
        );
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    void openSweep(List<List<double>> pts) {
      final path = Path()..moveTo(_p(pts[0][0], pts[0][1], size).dx, _p(pts[0][0], pts[0][1], size).dy);
      for (var i = 1; i < pts.length; i += 3) {
        path.cubicTo(
          _p(pts[i][0], pts[i][1], size).dx,
          _p(pts[i][0], pts[i][1], size).dy,
          _p(pts[i + 1][0], pts[i + 1][1], size).dx,
          _p(pts[i + 1][0], pts[i + 1][1], size).dy,
          _p(pts[i + 2][0], pts[i + 2][1], size).dx,
          _p(pts[i + 2][0], pts[i + 2][1], size).dy,
        );
      }
      canvas.drawPath(path, paint);
    }

    // Top-right "peak" cluster — echoes the cyan glow above it.
    closedBlob([
      [260, -10], [200, 40], [190, 120], [250, 170], [320, 220], [400, 190], [410, 100], [415, 20], [350, -30], [260, -10],
    ]);
    closedBlob([
      [255, 20], [215, 55], [210, 110], [255, 145], [305, 180], [365, 155], [370, 90], [373, 35], [320, 5], [255, 20],
    ]);
    closedBlob([
      [250, 50], [225, 72], [222, 105], [253, 128], [288, 152], [330, 135], [333, 92], [335, 55], [298, 40], [250, 50],
    ]);
    closedBlob([
      [245, 78], [230, 92], [228, 110], [248, 124], [270, 138], [296, 128], [298, 100], [299, 78], [275, 71], [245, 78],
    ]);

    // Lower-left "hill" cluster.
    closedBlob([
      [-40, 340], [10, 300], [90, 300], [120, 360], [150, 420], [100, 480], [20, 470], [-50, 462], [-80, 380], [-40, 340],
    ]);
    closedBlob([
      [-20, 355], [20, 325], [80, 325], [103, 370], [128, 415], [90, 460], [30, 452], [-30, 445], [-52, 388], [-20, 355],
    ]);
    closedBlob([
      [0, 372], [30, 350], [70, 350], [88, 382], [108, 415], [80, 448], [38, 442], [-8, 437], [-22, 396], [0, 372],
    ]);

    // Loose sweeps in the lower third, same contour family.
    openSweep([
      [-30, 540], [60, 500], [160, 520], [220, 560], [280, 600], [320, 640], [400, 620],
    ]);
    openSweep([
      [-30, 580], [70, 545], [170, 562], [230, 600], [285, 635], [330, 665], [400, 650],
    ]);
    openSweep([
      [-30, 620], [80, 590], [180, 604], [236, 638], [288, 668], [335, 690], [400, 678],
    ]);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The full premium light background shared by both chat screens: a
/// soft gradient base, two very faint radial "light" glows (cyan
/// top-right, warm white bottom-left), and the topographic contour
/// lines on top — intentionally behind everything else so it never
/// competes with whatever content sits on top of it.
class ChatLightBackground extends StatelessWidget {
  const ChatLightBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ChatLightColors.bg1, ChatLightColors.bg2, ChatLightColors.bg3],
            stops: [0, 0.45, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.8, -0.9),
                    radius: 0.65,
                    colors: [AppColors.primary.withValues(alpha: 0.16), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.9, 0.95),
                    radius: 0.6,
                    colors: [Colors.white.withValues(alpha: 0.9), Colors.transparent],
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: CustomPaint(painter: ChatContourPainter())),
          ],
        ),
      ),
    );
  }
}

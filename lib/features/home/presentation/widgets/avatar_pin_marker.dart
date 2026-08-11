import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';

/// Builds a custom Google Maps marker bitmap: the classic pin silhouette
/// (circle head + downward tail pointing at the exact coordinate), but
/// with a user's live profile photo painted inside the circle instead
/// of a flat color. Nearby-user markers on the Discover map use this so
/// a glance at the map already shows who's around, not just anonymous
/// dots — the photo comes straight from [NearbyUser.photoUrl], which is
/// itself a live Firestore-backed field, so the marker is only ever as
/// stale as that stream already is.
class AvatarPinMarker {
  AvatarPinMarker._();

  /// Renders at 3x the logical [size] so it stays sharp on high-density
  /// screens — Google Maps marker bitmaps are placed at their raw pixel
  /// size with no automatic device-pixel-ratio scaling.
  static Future<BitmapDescriptor> build({
    required String photoUrl,
    double size = 40,
    Color borderColor = AppColors.cyanDark,
  }) async {
    final image = await _loadNetworkImage(photoUrl);
    final scale = 3.0;
    final s = size * scale;
    final circleRadius = s * 0.38;
    final tailLength = s * 0.34;
    final totalHeight = circleRadius * 2 + tailLength + s * 0.04;
    final center = Offset(s / 2, circleRadius + s * 0.02);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final borderPaint = Paint()..color = borderColor;

    // Pin tail — a triangle from the circle's base down to a point,
    // exactly where Google's own default marker anchors (bottom-center).
    final tailPath = Path()
      ..moveTo(center.dx - circleRadius * 0.4, center.dy + circleRadius * 0.85)
      ..lineTo(center.dx + circleRadius * 0.4, center.dy + circleRadius * 0.85)
      ..lineTo(center.dx, center.dy + circleRadius + tailLength)
      ..close();
    canvas.drawPath(tailPath, borderPaint);

    // Border ring, then the photo clipped to the inner circle.
    canvas.drawCircle(center, circleRadius + s * 0.045, borderPaint);
    canvas.drawCircle(center, circleRadius, Paint()..color = const Color(0xFFFFFFFF));
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: circleRadius)));
    paintImage(
      canvas: canvas,
      rect: Rect.fromCircle(center: center, radius: circleRadius),
      image: image,
      fit: BoxFit.cover,
    );
    canvas.restore();

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(s.ceil(), totalHeight.ceil());
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: scale);
  }

  static Future<ui.Image> _loadNetworkImage(String url) {
    final completer = Completer<ui.Image>();
    final stream = NetworkImage(url).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (error, stackTrace) {
        completer.completeError(error, stackTrace);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}

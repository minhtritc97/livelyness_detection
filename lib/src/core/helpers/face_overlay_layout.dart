import 'package:livelyness_detection/index.dart';

/// Single source of truth for the geometry of the face oval.
///
/// Both the overlay painter (mask + border + progress ring) and any hit-testing
/// logic read the oval from here so they always agree.
class FaceOverlayLayout {
  const FaceOverlayLayout._();

  /// Fraction of the available width the oval spans.
  static const double _widthFactor = 0.74;

  /// Height/width ratio of the oval (portrait, slightly taller than a face).
  static const double _aspectRatio = 1.32;

  /// Vertical bias so the oval sits a little above the exact center, leaving
  /// room for the hint text underneath.
  static const double _verticalBias = -0.04;

  /// Computes the oval [Rect] for a given [size] (usually the screen size).
  static Rect ovalRect(Size size) {
    final double width = size.width * _widthFactor;
    final double height = width * _aspectRatio;
    final double left = (size.width - width) / 2;
    final double top =
        (size.height - height) / 2 + size.height * _verticalBias;
    return Rect.fromLTWH(left, top, width, height);
  }
}

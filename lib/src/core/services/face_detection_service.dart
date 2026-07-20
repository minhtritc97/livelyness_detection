import 'package:livelyness_detection/src/_internal.dart';

/// Thin wrapper around ML Kit's [FaceDetector] plus the pure geometry helpers
/// used by the banking flow to reason about a face (distance & pose).
///
/// This class holds no UI or flow state; it only turns pixels into [Face]s and
/// exposes stateless measurements over a [Face].
class FaceDetectionService {
  FaceDetectionService();

  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: true,
      enableTracking: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
      // Keep this small so faces are detected at a comfortable arm's length,
      // not only when they already fill the frame.
      minFaceSize: 0.15,
    ),
  );

  /// Detects all faces in [image].
  Future<List<Face>> detect(InputImage image) => _detector.processImage(image);

  /// Releases the underlying detector. Safe to call more than once.
  Future<void> dispose() => _detector.close();

  /// A **resolution-independent** distance proxy for [face]: the face bounding
  /// box width as a fraction (0..1) of the analysis image's shortest side.
  /// Larger == the face is closer to the camera.
  ///
  /// Normalising by the image size means the same threshold works regardless of
  /// the camera's analysis resolution (which varies per device), so the values
  /// in [DetectionConfig.farThreshold]/[DetectionConfig.nearThreshold] are
  /// fractions, not pixels.
  ///
  /// The bounding box is measured against the image's shortest side so the
  /// value is stable whether the analysis frame is portrait or landscape.
  static double distanceMetric(Face face, Size imageSize) {
    final double reference = imageSize.shortestSide;
    if (reference <= 0) return 0;
    final double faceSize = face.boundingBox.width;
    return faceSize / reference;
  }

  /// Whether [face] is looking roughly straight at the camera within [tolerance]
  /// degrees of yaw (Y) and pitch (X).
  static bool isStraight(Face face, {double tolerance = 12}) {
    final double yaw = (face.headEulerAngleY ?? 0).abs();
    final double pitch = (face.headEulerAngleX ?? 0).abs();
    return yaw <= tolerance && pitch <= tolerance;
  }
}

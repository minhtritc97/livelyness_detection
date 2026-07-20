import 'package:livelyness_detection/index.dart';

class DetectionConfig {
  /// Types of checks to be added while detecting the face.
  final List<LivelynessStepItem> steps;

  /// A boolean value that defines weather the detection should start with a `Info` screen or not.
  /// Default is *false*
  final bool startWithInfoScreen;

  /// Duration in which the face detection should get completed.
  /// Default is *15*
  final int maxSecToDetect;

  /// A boolean value that deinfes whether to allow the user to click the selfie even if the face is not detected.
  final bool allowAfterMaxSec;

  /// A boolean to choose to show or not show facial vertices during detection
  final bool showFacialVertices;

  /// Icon color of the button that will come after the [maxSecToDetect] is completed.
  final Color? captureButtonColor;

  /// Minimum face-distance metric required to capture the *far* face, expressed
  /// as a fraction (0..1) of the analysis image's shortest side (the face
  /// bounding-box width). Below this the face is considered too far/small.
  /// Default *0.28*.
  final double farThreshold;

  /// Minimum face-distance metric required to capture the *near* face (the
  /// "move closer" step), as a fraction (0..1) of the image's shortest side.
  /// Default *0.50*.
  final double nearThreshold;

  /// How long a valid far face must be held steady before it is captured.
  /// Default *2.5s*.
  final Duration farStableDuration;

  /// How long a valid near face must be held steady before it is captured.
  /// Default *2s*.
  final Duration nearStableDuration;

  DetectionConfig({
    required this.steps,
    this.startWithInfoScreen = false,
    this.maxSecToDetect = 15,
    this.allowAfterMaxSec = false,
    this.showFacialVertices = false,
    this.captureButtonColor,
    this.farThreshold = 0.28,
    this.nearThreshold = 0.50,
    this.farStableDuration = const Duration(milliseconds: 2500),
    this.nearStableDuration = const Duration(milliseconds: 2000),
  }) {
    assert(
      steps.isNotEmpty,
      '''
Cannot pass an empty array of [LivelynessStepItem].
      ''',
    );
  }
}

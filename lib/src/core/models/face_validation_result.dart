/// The reason a face is not (yet) acceptable for the current phase.
enum FaceIssue {
  /// The face satisfies every requirement of the current phase.
  none,

  /// No face is visible in the frame.
  noFace,

  /// More than one face is visible.
  multipleFaces,

  /// The face is present but not looking straight at the camera.
  notStraight,

  /// The face is too small / too far from the camera.
  tooFar,

  /// The face is too large / too close to the camera.
  tooClose,
}

/// The outcome of validating the current camera frame against the requirements
/// of the active [FacePhase].
class FaceValidationResult {
  /// Whether the face currently satisfies the active phase requirements.
  final bool isValid;

  /// The dominant reason the face is not acceptable ([FaceIssue.none] if valid).
  final FaceIssue issue;

  /// A distance proxy (larger == closer) derived from facial landmark spread.
  final double metric;

  const FaceValidationResult({
    required this.isValid,
    required this.issue,
    required this.metric,
  });

  /// A convenience result for a valid face.
  const FaceValidationResult.valid(this.metric)
      : isValid = true,
        issue = FaceIssue.none;

  /// A convenience result for an invalid face carrying the blocking [issue].
  const FaceValidationResult.invalid(
    this.issue, {
    this.metric = 0,
  }) : isValid = false;

  @override
  String toString() =>
      'FaceValidationResult(isValid: $isValid, issue: $issue, metric: ${metric.toStringAsFixed(1)})';
}

/// The sequential phases of the banking-style face authentication flow.
///
/// The flow moves top-to-bottom:
/// [initializing] -> [positioningFar] -> [stabilizingFar] (capture far face)
/// -> [moveCloser] -> [stabilizingNear] (capture near face)
/// -> [liveness] (optional blink/smile/turn steps) -> [completed].
enum FacePhase {
  /// Camera is warming up, no analysis yet.
  initializing,

  /// Waiting for a single, straight face at a comfortable distance inside the
  /// oval. Shown as "Đưa khuôn mặt vào khung".
  positioningFar,

  /// A valid far face is held steady while the progress ring fills.
  stabilizingFar,

  /// Far face captured, asking the user to move the phone closer.
  moveCloser,

  /// A valid near face is held steady while the progress ring fills.
  stabilizingNear,

  /// Running the optional liveness challenges (blink/smile/turn) from config.
  liveness,

  /// All required captures are done, the screen is about to return.
  completed,
}

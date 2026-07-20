/// Tracks how long a face has continuously satisfied the current phase and
/// exposes that as a 0..1 progress value used to drive the capture ring.
///
/// It is purely time-based: feed it a validity signal every frame via [update],
/// and read [progress] on a display ticker for a smooth fill regardless of the
/// (slower) camera analysis frame rate.
class StableFaceController {
  StableFaceController({required this.requiredDuration});

  /// How long the face must stay valid before [isComplete] becomes true.
  Duration requiredDuration;

  DateTime? _stableSince;

  /// Feeds the latest validity signal. A `true` starts (or continues) the hold;
  /// a `false` cancels it immediately.
  void update(bool isValid) {
    if (isValid) {
      _stableSince ??= DateTime.now();
    } else {
      _stableSince = null;
    }
  }

  /// Cancels any in-progress hold.
  void reset() => _stableSince = null;

  /// Current hold progress in the range 0..1.
  double get progress {
    final DateTime? since = _stableSince;
    if (since == null) return 0;
    final int elapsed = DateTime.now().difference(since).inMilliseconds;
    final int required = requiredDuration.inMilliseconds;
    if (required <= 0) return 1;
    final double value = elapsed / required;
    return value < 0
        ? 0
        : value > 1
            ? 1
            : value;
  }

  /// Whether the face has been held valid for [requiredDuration].
  bool get isComplete => progress >= 1.0;
}

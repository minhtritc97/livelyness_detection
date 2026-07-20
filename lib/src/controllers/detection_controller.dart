import 'dart:async';

import 'package:livelyness_detection/src/_internal.dart';

/// Orchestrates the banking-style face authentication flow.
///
/// The screen only has to: (1) feed detected [Face]s in via [onFaces] on every
/// analysis frame, and (2) rebuild its overlay from this controller's state
/// (it is a [ChangeNotifier]). All sequencing, stability timing, capturing and
/// optional liveness detection live here.
class DetectionController extends ChangeNotifier {
  DetectionController({
    required this.config,
    required this.capture,
    required this.onFinished,
  }) {
    _livenessSteps = config.steps
        .where((s) => s.step != LivelynessStep.lookStraight)
        .toList();
    _stable = StableFaceController(requiredDuration: config.farStableDuration);
    // A display ticker independent of the (slower) camera frame rate so the
    // capture ring fills smoothly and completion is checked promptly.
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
  }

  final DetectionConfig config;
  final CaptureController capture;

  /// Called once when the flow ends. [paths] holds every captured image path in
  /// order (far, near, then one per completed liveness step). [didCaptureAuto]
  /// is `false` only when the user tapped the manual capture fallback.
  final void Function(List<String?> paths, bool didCaptureAuto) onFinished;

  //* MARK: - Public State (read by the overlay)
  //? =========================================================
  FacePhase get phase => _phase;
  FaceValidationResult get validation => _validation;
  double get stabilityProgress => _stabilityProgress;
  bool get manualCaptureVisible => _manualCaptureVisible;
  bool get isCapturing => _busy;

  /// The liveness step currently being asked of the user, if in that phase.
  LivelynessStep? get currentLivenessStep =>
      _phase == FacePhase.liveness && _livenessIndex < _livenessSteps.length
          ? _livenessSteps[_livenessIndex].step
          : null;

  /// Overall progress across the whole flow (0..1), for a top progress bar.
  double get overallProgress {
    final int total = 2 + _livenessSteps.length; // far + near + liveness steps
    final int done = _capturedPaths.length;
    return total == 0 ? 0 : (done / total).clamp(0.0, 1.0);
  }

  //* MARK: - Private State
  //? =========================================================
  FacePhase _phase = FacePhase.initializing;
  FaceValidationResult _validation =
      const FaceValidationResult.invalid(FaceIssue.noFace);
  double _stabilityProgress = 0;
  bool _busy = false;
  bool _finished = false;
  bool _manualCaptureVisible = false;

  final List<String?> _capturedPaths = [];
  late final StableFaceController _stable;
  late final Timer _ticker;
  Timer? _timeout;

  late final List<LivelynessStepItem> _livenessSteps;
  int _livenessIndex = 0;
  bool _didCloseEyes = false;
  Size _imageSize = Size.zero;

  //* MARK: - Lifecycle
  //? =========================================================
  /// Begins the flow. Call once the camera preview is ready.
  void start() {
    if (_phase != FacePhase.initializing) return;
    _phase = FacePhase.positioningFar;
    _startTimeout();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  //* MARK: - Frame Handling
  //? =========================================================
  /// Feeds the faces detected in the latest analysis frame, along with the
  /// [imageSize] they were detected in (needed to normalise the distance).
  void onFaces(List<Face> faces, Size imageSize) {
    _imageSize = imageSize;
    if (_finished || _busy) return;
    switch (_phase) {
      case FacePhase.initializing:
      case FacePhase.completed:
        return;
      case FacePhase.positioningFar:
      case FacePhase.stabilizingFar:
        _handleDistancePhase(faces, isNear: false);
        break;
      case FacePhase.moveCloser:
      case FacePhase.stabilizingNear:
        _handleDistancePhase(faces, isNear: true);
        break;
      case FacePhase.liveness:
        _handleLiveness(faces);
        break;
    }
    notifyListeners();
  }

  /// Drives the far and near capture phases, which share the same shape:
  /// validate -> update the hold -> the ticker fires the capture.
  void _handleDistancePhase(List<Face> faces, {required bool isNear}) {
    _stable.requiredDuration =
        isNear ? config.nearStableDuration : config.farStableDuration;
    final FaceValidationResult result = _validate(faces, isNear: isNear);
    _validation = result;
    _stable.update(result.isValid);

    final FacePhase holding =
        isNear ? FacePhase.stabilizingNear : FacePhase.stabilizingFar;
    final FacePhase waiting =
        isNear ? FacePhase.moveCloser : FacePhase.positioningFar;
    _phase = result.isValid ? holding : waiting;
  }

  /// Validates the current [faces] against the requirements of a distance phase.
  FaceValidationResult _validate(List<Face> faces, {required bool isNear}) {
    if (faces.isEmpty) {
      return const FaceValidationResult.invalid(FaceIssue.noFace);
    }
    if (faces.length > 1) {
      return const FaceValidationResult.invalid(FaceIssue.multipleFaces);
    }
    final Face face = faces.first;
    final double metric = FaceDetectionService.distanceMetric(face, _imageSize);

    if (!FaceDetectionService.isStraight(face,
        tolerance: isNear ? 22 : 18)) {
      return FaceValidationResult.invalid(FaceIssue.notStraight, metric: metric);
    }

    if (isNear) {
      if (metric < config.nearThreshold) {
        return FaceValidationResult.invalid(FaceIssue.tooFar, metric: metric);
      }
      return FaceValidationResult.valid(metric);
    }

    // Far phase: face must be clearly present but not already too close, so the
    // "move closer" gesture into the near phase is meaningful.
    if (metric < config.farThreshold) {
      return FaceValidationResult.invalid(FaceIssue.tooFar, metric: metric);
    }
    if (metric >= config.nearThreshold) {
      return FaceValidationResult.invalid(FaceIssue.tooClose, metric: metric);
    }
    return FaceValidationResult.valid(metric);
  }

  //* MARK: - Ticker (smooth ring + capture trigger)
  //? =========================================================
  void _tick() {
    if (_finished || _busy) return;
    if (_phase == FacePhase.stabilizingFar ||
        _phase == FacePhase.stabilizingNear) {
      _stabilityProgress = _stable.progress;
      if (_stable.isComplete) {
        _capture(isNear: _phase == FacePhase.stabilizingNear);
        return;
      }
      // Drive the capture ring smoothly at the ticker rate.
      notifyListeners();
    } else if (_stabilityProgress != 0) {
      _stabilityProgress = 0;
      notifyListeners();
    }
  }

  //* MARK: - Capture
  //? =========================================================
  Future<void> _capture({required bool isNear}) async {
    if (_busy || _finished) return;
    _busy = true;
    _stable.reset();
    _stabilityProgress = 1;
    notifyListeners();

    final String? path = await capture.takePhoto();
    _capturedPaths.add(path);

    _stabilityProgress = 0;
    _stable.reset();

    if (!isNear) {
      _phase = FacePhase.moveCloser;
      _validation = const FaceValidationResult.invalid(FaceIssue.tooFar);
    } else {
      _advanceAfterNear();
    }
    _busy = false;
    notifyListeners();
  }

  void _advanceAfterNear() {
    if (_livenessSteps.isEmpty) {
      _finish(didAuto: true);
    } else {
      _phase = FacePhase.liveness;
      _livenessIndex = 0;
      _didCloseEyes = false;
    }
  }

  //* MARK: - Liveness Steps
  //? =========================================================
  void _handleLiveness(List<Face> faces) {
    if (faces.length != 1) {
      _validation = FaceValidationResult.invalid(
        faces.isEmpty ? FaceIssue.noFace : FaceIssue.multipleFaces,
      );
      return;
    }
    final Face face = faces.first;
    _validation = const FaceValidationResult.valid(0);
    final LivelynessStep step = _livenessSteps[_livenessIndex].step;

    switch (step) {
      case LivelynessStep.blink:
        _detectBlink(face);
        break;
      case LivelynessStep.smile:
        if (FaceDetectionService.isStraight(face, tolerance: 16) &&
            (face.smilingProbability ?? 0) > 0.5) {
          _completeLivenessStep();
        }
        break;
      case LivelynessStep.turnLeft:
        _detectTurn(face, toLeft: true);
        break;
      case LivelynessStep.turnRight:
        _detectTurn(face, toLeft: false);
        break;
      case LivelynessStep.lookStraight:
        // Filtered out of _livenessSteps, but handle defensively.
        _completeLivenessStep();
        break;
    }
  }

  void _detectBlink(Face face) {
    const double closed = 0.25;
    const double open = 0.75;
    final double left = face.leftEyeOpenProbability ?? 1.0;
    final double right = face.rightEyeOpenProbability ?? 1.0;
    if (!_didCloseEyes) {
      if (left < closed && right < closed) {
        _didCloseEyes = true;
      }
    } else if (left > open && right > open) {
      _didCloseEyes = false;
      _completeLivenessStep();
    }
  }

  void _detectTurn(Face face, {required bool toLeft}) {
    // On iOS the front-camera yaw sign is mirrored relative to Android.
    final bool mirrored = Platform.isIOS;
    final bool wantPositiveYaw = toLeft ? !mirrored : mirrored;
    final double yaw = face.headEulerAngleY ?? 0;
    const double threshold = 32;
    final bool turned =
        wantPositiveYaw ? yaw > threshold : yaw < -threshold;
    if (turned) _completeLivenessStep();
  }

  Future<void> _completeLivenessStep() async {
    if (_busy || _finished) return;
    _busy = true;
    notifyListeners();

    final String? path = await capture.takePhoto();
    _capturedPaths.add(path);
    _didCloseEyes = false;
    _livenessIndex++;

    if (_livenessIndex >= _livenessSteps.length) {
      _busy = false;
      _finish(didAuto: true);
    } else {
      _busy = false;
      notifyListeners();
    }
  }

  //* MARK: - Manual Capture Fallback & Timeout
  //? =========================================================
  void _startTimeout() {
    _timeout = Timer(
      Duration(seconds: config.maxSecToDetect),
      () {
        if (_finished) return;
        if (config.allowAfterMaxSec) {
          _manualCaptureVisible = true;
          notifyListeners();
        } else {
          _finish(didAuto: false, cancelled: true);
        }
      },
    );
  }

  /// Captures the current frame on the user's demand (manual fallback button).
  Future<void> manualCapture() async {
    if (_busy || _finished) return;
    _busy = true;
    notifyListeners();
    final String? path = await capture.takePhoto();
    _capturedPaths.add(path);
    _busy = false;
    _finish(didAuto: false);
  }

  //* MARK: - Completion
  //? =========================================================
  void _finish({required bool didAuto, bool cancelled = false}) {
    if (_finished) return;
    _finished = true;
    _phase = FacePhase.completed;
    _timeout?.cancel();
    notifyListeners();
    onFinished(cancelled ? const [] : _capturedPaths, didAuto);
  }
}

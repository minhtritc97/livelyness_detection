import 'dart:async';

import 'package:livelyness_detection/src/_internal.dart';

/// Wraps the camerawesome [CameraState] and exposes a single, awaitable
/// [takePhoto] so the flow controller stays free of camera plumbing.
class CaptureController {
  CameraState? _cameraState;

  /// Binds the live camera state produced by `CameraAwesomeBuilder`.
  void attach(CameraState state) => _cameraState = state;

  /// Whether a camera state is available to capture with.
  bool get isReady => _cameraState != null;

  /// Captures a still photo and returns its file path, or `null` if the camera
  /// is unavailable, not in photo mode, or the capture fails/times out.
  Future<String?> takePhoto() async {
    final CameraState? state = _cameraState;
    if (state == null) return null;

    final Completer<String?> completer = Completer<String?>();
    state.when(
      onPhotoMode: (photoState) async {
        try {
          final CaptureRequest request = await photoState.takePhoto();
          if (!completer.isCompleted) completer.complete(request.path);
        } catch (_) {
          if (!completer.isCompleted) completer.complete(null);
        }
      },
    );

    // `when` does not invoke the handler if the camera is not in photo mode,
    // so guard against a completer that would otherwise never resolve.
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
  }
}

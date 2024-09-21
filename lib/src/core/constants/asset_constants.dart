// ignore_for_file: library_private_types_in_public_api

class AssetConstants {
  static const packageName = "livelyness_detection";
  static _LottieAssets lottie = _LottieAssets();
  static _ImageAssets images = _ImageAssets();
}

class _ImageAssets {
  String get _initPath {
    return "src/assets";
  }

  String get mesh {
    return "$_initPath/final-mesh.png";
  }

  String get scanView {
    return "$_initPath/qr_scan_view.png";
  }
}

class _LottieAssets {
  String get _initPath {
    return "src/assets/lottie";
  }

  String get livelynessStart {
    return "$_initPath/livelyness-start.json";
  }

  String get livelynessSuccess {
    return "$_initPath/livelyness-success.json";
  }

  String get stepCompleted {
    return "$_initPath/step_completed.json";
  }

  String get arrowUp {
    return "$_initPath/arrow_up.json";
  }

  String get arrowDown {
    return "$_initPath/arrow_down.json";
  }

  String get arrowLeft {
    return "$_initPath/arrow_left.json";
  }

  String get arrowRight {
    return "$_initPath/arrow_right.json";
  }

  String get check {
    return "$_initPath/check.json";
  }
}

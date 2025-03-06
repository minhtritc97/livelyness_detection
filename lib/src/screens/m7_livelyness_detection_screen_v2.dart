import 'dart:async';
import 'package:livelyness_detection/index.dart';

import '../core/enums/face_status.dart';

class LivelynessDetectionPageV2 extends StatelessWidget {
  final DetectionConfig config;

  const LivelynessDetectionPageV2({
    required this.config,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LivelynessDetectionScreenV2(
          config: config,
        ),
      ),
    );
  }
}

class LivelynessDetectionScreenV2 extends StatefulWidget {
  final DetectionConfig config;

  const LivelynessDetectionScreenV2({
    required this.config,
    super.key,
  });

  @override
  State<LivelynessDetectionScreenV2> createState() =>
      _LivelynessDetectionScreenAndroidState();
}

class _LivelynessDetectionScreenAndroidState
    extends State<LivelynessDetectionScreenV2> {
  //* MARK: - Private Variables
  //? =========================================================
  final _faceDetectionController = BehaviorSubject<FaceDetectionModel>();

  final options = FaceDetectorOptions(
    enableContours: true,
    enableClassification: true,
    enableTracking: true,
    enableLandmarks: true,
    performanceMode: FaceDetectorMode.accurate,
    minFaceSize: 0.8,
  );
  late final faceDetector = FaceDetector(options: options);
  bool _didCloseEyes = false;
  bool _isProcessingStep = false;

  late final List<LivelynessStepItem> _steps;
  final GlobalKey<LivelynessDetectionStepOverlayState> _stepsKey =
      GlobalKey<LivelynessDetectionStepOverlayState>();

  CameraState? _cameraState;
  bool _isProcessing = false;
  late bool _isInfoStepCompleted;
  Timer? _timerToDetectFace;
  bool _isCaptureButtonVisible = false;
  bool _isCompleted = false;
  List<String?> imgPaths = [];
  LivelynessStep? lastCompletedStep;
  //* MARK: - Life Cycle Methods
  //? =========================================================
  @override
  void initState() {
    _preInitCallBack();
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _postFrameCallBack(),
    );
  }

  @override
  void deactivate() {
    faceDetector.close();
    super.deactivate();
  }

  @override
  void dispose() {
    _faceDetectionController.close();
    _timerToDetectFace?.cancel();
    _timerToDetectFace = null;
    super.dispose();
  }

  //* MARK: - Private Methods for Business Logic
  //? =========================================================
  void _preInitCallBack() {
    _steps = widget.config.steps;
    _isInfoStepCompleted = !widget.config.startWithInfoScreen;
  }

  void _postFrameCallBack() {
    if (_isInfoStepCompleted) {
      _startTimer();
    }
  }

  Future<void> _processCameraImage(AnalysisImage img) async {
    if (_isProcessing) {
      return;
    }
    if (mounted) {
      setState(
        () => _isProcessing = true,
      );
    }
    final inputImage = img.toInputImage();

    try {
      final detectedFaces = await faceDetector.processImage(inputImage);

      _faceDetectionController.add(
        FaceDetectionModel(
          faces: detectedFaces,
          absoluteImageSize: inputImage.metadata!.size,
          rotation: 0,
          imageRotation: img.inputImageRotation,
          croppedSize: img.croppedSize,
        ),
      );
      await _processImage(inputImage, detectedFaces);
      if (mounted) {
        setState(
          () => _isProcessing = false,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _isProcessing = false,
        );
      }
      debugPrint("...sending image resulted error $error");
    }
  }

  final List<FaceStatus> _faceStatusList = [];
  Future<void> _processImage(InputImage img, List<Face> faces) async {
    try {
      // if (faces.isEmpty) {
      //   _resetSteps();
      //   return;
      // }
      _faceStatusList.clear();

      if (faces.length > 1) {
        return;
      }
      final Face firstFace = faces.first;
      final landmarks = firstFace.landmarks;
      // Get landmark positions for relevant facial features
      final Point<int>? leftEye = landmarks[FaceLandmarkType.leftEye]?.position;
      final Point<int>? rightEye =
          landmarks[FaceLandmarkType.rightEye]?.position;
      final Point<int>? leftCheek =
          landmarks[FaceLandmarkType.leftCheek]?.position;
      final Point<int>? rightCheek =
          landmarks[FaceLandmarkType.rightCheek]?.position;
      final Point<int>? leftEar = landmarks[FaceLandmarkType.leftEar]?.position;
      final Point<int>? rightEar =
          landmarks[FaceLandmarkType.rightEar]?.position;
      final Point<int>? leftMouth =
          landmarks[FaceLandmarkType.leftMouth]?.position;
      final Point<int>? rightMouth =
          landmarks[FaceLandmarkType.rightMouth]?.position;

      // Calculate symmetry values based on corresponding landmark positions
      final Map<String, double> symmetry = {};
      final eyeSymmetry = calculateSymmetry(
        leftEye,
        rightEye,
      );
      symmetry['eyeSymmetry'] = eyeSymmetry;

      final cheekSymmetry = calculateSymmetry(
        leftCheek,
        rightCheek,
      );
      symmetry['cheekSymmetry'] = cheekSymmetry;

      final earSymmetry = calculateSymmetry(
        leftEar,
        rightEar,
      );
      symmetry['earSymmetry'] = earSymmetry;

      final mouthSymmetry = calculateSymmetry(
        leftMouth,
        rightMouth,
      );
      symmetry['mouthSymmetry'] = mouthSymmetry;
      double total = 0.0;
      symmetry.forEach((key, value) {
        total += value;
      });
      final double average = total / symmetry.length;
      if (average > 200) {
        if (!_faceStatusList.contains(FaceStatus.near)) {
          _faceStatusList.add(FaceStatus.near);
          _faceStatusList.remove(FaceStatus.far);
        }
      }
      if (average < 170) {
        if (!_faceStatusList.contains(FaceStatus.far)) {
          _faceStatusList.add(FaceStatus.far);
          _faceStatusList.remove(FaceStatus.near);
        }
      }
      if (average >= 170 && average <= 200) {
        _faceStatusList.remove(FaceStatus.far);
        _faceStatusList.remove(FaceStatus.near);
      }
      if ((firstFace.headEulerAngleX ?? 0) > 3) {
        if (!_faceStatusList.contains(FaceStatus.up)) {
          _faceStatusList.add(FaceStatus.up);
          _faceStatusList.remove(FaceStatus.down);
        }
      }
      if ((firstFace.headEulerAngleX ?? 0) < -3) {
        if (!_faceStatusList.contains(FaceStatus.down)) {
          _faceStatusList.add(FaceStatus.down);
          _faceStatusList.remove(FaceStatus.up);
        }
      }
      if ((firstFace.headEulerAngleY ?? 0) > 3) {
        if (!_faceStatusList.contains(FaceStatus.left)) {
          _faceStatusList.add(FaceStatus.left);
          _faceStatusList.remove(FaceStatus.right);
        }
      }
      if ((firstFace.headEulerAngleY ?? 0) < -3) {
        if (!_faceStatusList.contains(FaceStatus.right)) {
          _faceStatusList.add(FaceStatus.right);
          _faceStatusList.remove(FaceStatus.left);
        }
      }
      if (kDebugMode) {
        print("Face Symmetry: $average");
      }
      if (_isProcessingStep &&
          _steps[_stepsKey.currentState?.currentIndex ?? 0].step ==
              LivelynessStep.blink) {
        if (_didCloseEyes) {
          if ((faces.first.leftEyeOpenProbability ?? 1.0) < 0.75 &&
              (faces.first.rightEyeOpenProbability ?? 1.0) < 0.75) {
            await _completeStep(
              step: _steps[_stepsKey.currentState?.currentIndex ?? 0].step,
            );
          }
        }
      }
      _detect(
        face: firstFace,
        step: _steps[_stepsKey.currentState?.currentIndex ?? 0].step,
      );
    } catch (e) {
      _startProcessing();
    }
  }

  Future<void> _completeStep({
    required LivelynessStep step,
  }) async {
    if (step != lastCompletedStep) {
      _cameraState?.when(
        onPhotoMode: (p0) => Future.delayed(
          const Duration(milliseconds: 500),
          () => p0.takePhoto().then(
            (value) {
              if (value.path != null) imgPaths.add(value.path);
            },
          ),
        ),
      );
    }
    lastCompletedStep = step;

    final int indexToUpdate = _steps.indexWhere(
      (p0) => p0.step == step,
    );

    _steps[indexToUpdate] = _steps[indexToUpdate].copyWith(
      isCompleted: true,
    );
    if (mounted) {
      setState(() {});
    }
    await _stepsKey.currentState?.nextPage();

    _stopProcessing();
  }

  void _detect({
    required Face face,
    required LivelynessStep step,
  }) async {
    switch (step) {
      case LivelynessStep.blink:
        const double blinkThreshold = 0.25;
        if (_isLookingStraight(face) &&
            (face.leftEyeOpenProbability ?? 1.0) < (blinkThreshold) &&
            (face.rightEyeOpenProbability ?? 1.0) < (blinkThreshold)) {
          _startProcessing();
          if (mounted) {
            setState(
              () => _didCloseEyes = true,
            );
          }
        }
        break;
      case LivelynessStep.turnLeft:
        Platform.isAndroid
            ? await _checkTurnLeft(face, step)
            : await _checkTurnRight(face, step);
        break;
      case LivelynessStep.turnRight:
        Platform.isAndroid
            ? await _checkTurnRight(face, step)
            : await _checkTurnLeft(face, step);
        break;
      case LivelynessStep.smile:
        const double smileThreshold = 0.1;
        if (_isLookingStraight(face) &&
            (face.smilingProbability ?? 0) > (smileThreshold)) {
          _startProcessing();
          await _completeStep(step: step);
        }
      case LivelynessStep.lookStraight:
        if (_isLookingStraight(face)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
    }
  }

  Future<void> _checkTurnRight(Face face, LivelynessStep step) async {
    const double headTurnThreshold = -35.0;
    if ((face.headEulerAngleY ?? 0) < (headTurnThreshold)) {
      _startProcessing();
      await _completeStep(step: step);
    }
  }

  Future<void> _checkTurnLeft(Face face, LivelynessStep step) async {
    const double headTurnThreshold = 30.0;
    if ((face.headEulerAngleY ?? 0) > (headTurnThreshold)) {
      _startProcessing();
      await _completeStep(step: step);
    }
  }

  Point<int> left = const Point(0, 0);
  Point<int> right = const Point(0, 0);
  bool _isLookingStraight(Face face) {
    return !_faceStatusList.contains(FaceStatus.near) &&
        !_faceStatusList.contains(FaceStatus.far) &&
        (face.headEulerAngleY ?? 0) <= 3 &&
        (face.headEulerAngleY ?? 0) >= -3 &&
        (face.headEulerAngleX ?? 0) <= 3 &&
        (face.headEulerAngleX ?? 0) >= -3;
  }

  void _startProcessing() {
    if (!mounted) {
      return;
    }
    setState(
      () => _isProcessingStep = true,
    );
  }

  void _stopProcessing() {
    if (!mounted) {
      return;
    }
    setState(
      () => _isProcessingStep = false,
    );
  }

  void _startTimer() {
    _timerToDetectFace = Timer(
      Duration(seconds: widget.config.maxSecToDetect),
      () {
        _timerToDetectFace?.cancel();
        _timerToDetectFace = null;
        if (widget.config.allowAfterMaxSec) {
          _isCaptureButtonVisible = true;
          if (mounted) {
            setState(() {});
          }
          return;
        }
        _onDetectionCompleted(
          imgToReturn: null,
        );
      },
    );
  }

  Future<void> _takePicture({
    required bool didCaptureAutomatically,
  }) async {
    if (_cameraState == null) {
      _onDetectionCompleted();
      return;
    }
    _cameraState?.when(
      onPhotoMode: (p0) => Future.delayed(
        const Duration(milliseconds: 500),
        () => p0.takePhoto().then(
          (value) {
            _onDetectionCompleted(
              imgToReturn: value.path,
              didCaptureAutomatically: didCaptureAutomatically,
            );
          },
        ),
      ),
    );
  }

  void _onDetectionCompleted({
    String? imgToReturn,
    bool? didCaptureAutomatically,
  }) {
    if (_isCompleted) {
      return;
    }

    setState(
      () => _isCompleted = true,
    );
    final String imgPath = imgToReturn ?? "";
    if (imgPath.isEmpty || didCaptureAutomatically == null) {
      Navigator.of(context).pop(null);
      return;
    }
    Navigator.of(context).pop(
      imgPaths.map(
        (path) {
          if (path?.isNotEmpty ?? false) {
            return CapturedImage(
              imgPath: path!,
              didCaptureAutomatically: didCaptureAutomatically,
            );
          }
        },
      ).toList(),
      // CapturedImage(
      //   imgPath: imgPath,
      //   didCaptureAutomatically: didCaptureAutomatically,
      // ),
    );
  }

  // void _resetSteps() async {
  //   for (var p0 in _steps) {
  //     final int index = _steps.indexWhere(
  //       (p1) => p1.step == p0.step,
  //     );
  //     _steps[index] = _steps[index].copyWith(
  //       isCompleted: false,
  //     );
  //   }
  //   _didCloseEyes = false;
  //   if (_stepsKey.currentState?.currentIndex != 0) {
  //     _stepsKey.currentState?.reset();
  //   }
  //   if (mounted) {
  //     setState(() {});
  //   }
  // }

  //* MARK: - Private Methods for UI Components
  //? =========================================================
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
        colors: [
          const Color.fromARGB(255, 6, 22, 29),
          Colors.blueGrey.shade800,
          const Color.fromARGB(255, 6, 22, 29),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      )),
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          _isInfoStepCompleted
              ? Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.sizeOf(context).height * 0.65),
                            child: AspectRatio(
                              aspectRatio: 9 / 16,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  children: [
                                    CameraAwesomeBuilder.custom(
                                      previewFit: CameraPreviewFit.contain,
                                      mirrorFrontCamera: true,
                                      sensorConfig: SensorConfig.single(
                                        aspectRatio:
                                            CameraAspectRatios.ratio_16_9,
                                        flashMode: FlashMode.auto,
                                        sensor: Sensor.position(
                                            SensorPosition.front),
                                      ),
                                      onImageForAnalysis: (img) =>
                                          _processCameraImage(img),
                                      imageAnalysisConfig: AnalysisConfig(
                                        autoStart: true,
                                        maxFramesPerSecond: 10,
                                      ),
                                      builder: (state, preview) {
                                        _cameraState = state;
                                        return widget.config.showFacialVertices
                                            ? PreviewDecoratorWidget(
                                                cameraState: state,
                                                faceDetectionStream:
                                                    _faceDetectionController,
                                                previewSize: PreviewSize(
                                                  width:
                                                      preview.previewSize.width,
                                                  height: preview
                                                      .previewSize.height,
                                                ),
                                                previewRect: preview.rect,
                                              )
                                            : const SizedBox();
                                      },
                                      // (state, previewSize, previewRect) {
                                      //   _cameraState = state;
                                      //   return PreviewDecoratorWidget(
                                      //     cameraState: state,
                                      //     faceDetectionStream: _faceDetectionController,
                                      //     previewSize: previewSize,
                                      //     previewRect: previewRect,
                                      //     detectionColor:
                                      //         _steps[_stepsKey.currentState?.currentIndex ?? 0]
                                      //             .detectionColor,
                                      //   );
                                      // },
                                      saveConfig: SaveConfig.photo(
                                        pathBuilder: (_) async {
                                          final String fileName =
                                              "${Utils.generate()}.jpg";
                                          final String path =
                                              await getTemporaryDirectory()
                                                  .then(
                                            (value) => value.path,
                                          );
                                          // return "$path/$fileName";
                                          return SingleCaptureRequest(
                                            "$path/$fileName",
                                            Sensor.position(
                                              SensorPosition.front,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    if (_faceStatusList
                                            .contains(FaceStatus.up) &&
                                        _steps[_stepsKey.currentState
                                                        ?.currentIndex ??
                                                    0]
                                                .step !=
                                            LivelynessStep.turnLeft &&
                                        _steps[_stepsKey.currentState
                                                        ?.currentIndex ??
                                                    0]
                                                .step !=
                                            LivelynessStep.turnRight)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              const Icon(Icons.face,
                                                  color: Colors.green),
                                              Lottie.asset(
                                                AssetConstants.lottie.arrowDown,
                                                package:
                                                    AssetConstants.packageName,
                                                animate: true,
                                                repeat: true,
                                                reverse: false,
                                                fit: BoxFit.contain,
                                                width: 40,
                                                height: 40,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (_faceStatusList
                                            .contains(FaceStatus.down) &&
                                        _steps[_stepsKey.currentState
                                                        ?.currentIndex ??
                                                    0]
                                                .step !=
                                            LivelynessStep.turnLeft &&
                                        _steps[_stepsKey.currentState
                                                        ?.currentIndex ??
                                                    0]
                                                .step !=
                                            LivelynessStep.turnRight)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              const Icon(Icons.face,
                                                  color: Colors.green),
                                              Lottie.asset(
                                                AssetConstants.lottie.arrowUp,
                                                package:
                                                    AssetConstants.packageName,
                                                animate: true,
                                                repeat: true,
                                                reverse: false,
                                                fit: BoxFit.contain,
                                                width: 40,
                                                height: 40,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (_faceStatusList
                                            .contains(FaceStatus.right) &&
                                        _steps[_stepsKey.currentState
                                                        ?.currentIndex ??
                                                    0]
                                                .step !=
                                            LivelynessStep.turnLeft &&
                                        _steps[_stepsKey.currentState
                                                        ?.currentIndex ??
                                                    0]
                                                .step !=
                                            LivelynessStep.turnRight)
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              const Icon(Icons.face,
                                                  color: Colors.green),
                                              Lottie.asset(
                                                Platform.isAndroid
                                                    ? AssetConstants
                                                        .lottie.arrowLeft
                                                    : AssetConstants
                                                        .lottie.arrowRight,
                                                package:
                                                    AssetConstants.packageName,
                                                animate: true,
                                                repeat: true,
                                                reverse: false,
                                                fit: BoxFit.contain,
                                                width: 40,
                                                height: 40,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (_faceStatusList
                                            .contains(FaceStatus.left) &&
                                        _steps[_stepsKey.currentState
                                                        ?.currentIndex ??
                                                    0]
                                                .step !=
                                            LivelynessStep.turnLeft &&
                                        _steps[_stepsKey.currentState
                                                        ?.currentIndex ??
                                                    0]
                                                .step !=
                                            LivelynessStep.turnRight)
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              const Icon(Icons.face,
                                                  color: Colors.green),
                                              Lottie.asset(
                                                Platform.isAndroid
                                                    ? AssetConstants
                                                        .lottie.arrowRight
                                                    : AssetConstants
                                                        .lottie.arrowLeft,
                                                package:
                                                    AssetConstants.packageName,
                                                animate: true,
                                                repeat: true,
                                                reverse: false,
                                                fit: BoxFit.contain,
                                                width: 40,
                                                height: 40,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 80,
                            child: Text(
                              _faceStatusList.contains(FaceStatus.far)
                                  ? FaceStatus.far.text
                                  : _faceStatusList.contains(FaceStatus.near)
                                      ? FaceStatus.near.text
                                      : _steps[_stepsKey
                                                  .currentState?.currentIndex ??
                                              0]
                                          .title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : LivelynessInfoWidget(
                  onStartTap: () {
                    if (!mounted) {
                      return;
                    }
                    _startTimer();
                    setState(
                      () => _isInfoStepCompleted = true,
                    );
                  },
                ),
          if (_isInfoStepCompleted)
            LivelynessDetectionStepOverlay(
              key: _stepsKey,
              steps: _steps,
              onCompleted: () => _takePicture(
                didCaptureAutomatically: true,
              ),
            ),
          Visibility(
            visible: _isCaptureButtonVisible,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(
                  flex: 20,
                ),
                MaterialButton(
                  onPressed: () => _takePicture(
                    didCaptureAutomatically: false,
                  ),
                  color: widget.config.captureButtonColor ??
                      Theme.of(context).primaryColor,
                  textColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: const CircleBorder(),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 24,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(
                right: 10,
                top: 10,
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.black,
                child: IconButton(
                  onPressed: () {
                    _onDetectionCompleted(
                      imgToReturn: null,
                      didCaptureAutomatically: null,
                    );
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // if (_isInfoStepCompleted)
          //   Align(
          //     alignment: Alignment.center,
          //     child: Image.asset(
          //       AssetConstants.images.scanView,
          //       package: AssetConstants.packageName,
          //       width: MediaQuery.sizeOf(context).height * 0.28,
          //     ),
          //   ),
        ],
      ),
    );
  }

  bool center = false;
  double calculateSymmetry(
      Point<int>? leftPosition, Point<int>? rightPosition) {
    if (leftPosition != null && rightPosition != null) {
      final double dx = (rightPosition.x - leftPosition.x).abs().toDouble();
      final double dy = (rightPosition.y - leftPosition.y).abs().toDouble();
      final distance = Offset(dx, dy).distance;
      return distance;
    }

    return 0.0;
  }
}

// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:livelyness_detection/index.dart';
import '../../livelyness_detection.dart';

List<CameraDescription> availableCams = [];

class LivelynessDetectionScreenV1 extends StatefulWidget {
  final DetectionConfig config;
  const LivelynessDetectionScreenV1({
    required this.config,
    super.key,
  });

  @override
  State<LivelynessDetectionScreenV1> createState() =>
      _MLivelyness7DetectionScreenState();
}

class _MLivelyness7DetectionScreenState
    extends State<LivelynessDetectionScreenV1> {
  //* MARK: - Private Variables
  //? =========================================================
  late bool _isInfoStepCompleted;
  late final List<LivelynessStepItem> steps;
  CameraController? _cameraController;
  CustomPaint? _customPaint;
  int _cameraIndex = 0;
  bool _isBusy = false;
  final GlobalKey<LivelynessDetectionStepOverlayState> _stepsKey =
      GlobalKey<LivelynessDetectionStepOverlayState>();
  bool _isProcessingStep = false;
  bool _didCloseEyes = false;
  bool _isTakingPicture = false;
  Timer? _timerToDetectFace;
  bool _isCaptureButtonVisible = false;

  late final List<LivelynessStepItem> _steps;

  //* MARK: - Face Position & Distance Tracking
  //? =========================================================
  FaceStatus _faceDistanceStatus = FaceStatus.unknown;
  bool _isFaceInOval = false;
  Timer? _faceStableTimer;
  bool _isFaceStable = false;
  String _currentInstruction = '';
  int _stableFaceCount = 0;
  static const int kRequiredStableFrames = 30; // ~1 second at 30fps
  static const double kOvalWidthRatio = 0.65;
  static const double kOvalHeightRatio = 0.5;

  //* MARK: - Captured Images
  //? =========================================================
  List<String?> _capturedImagePaths = [];
  LivelynessStep? _lastCompletedStep;

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
  void dispose() {
    _cameraController?.dispose();
    _timerToDetectFace?.cancel();
    _timerToDetectFace = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  //* MARK: - Private Methods for Business Logic
  //? =========================================================
  void _preInitCallBack() {
    _steps = widget.config.steps;
    _isInfoStepCompleted = !widget.config.startWithInfoScreen;
  }

  void _postFrameCallBack() async {
    availableCams = await availableCameras();
    if (availableCams.any(
      (element) =>
          element.lensDirection == CameraLensDirection.front &&
          element.sensorOrientation == 90,
    )) {
      _cameraIndex = availableCams.indexOf(
        availableCams.firstWhere((element) =>
            element.lensDirection == CameraLensDirection.front &&
            element.sensorOrientation == 90),
      );
    } else {
      _cameraIndex = availableCams.indexOf(
        availableCams.firstWhere(
          (element) => element.lensDirection == CameraLensDirection.front,
        ),
      );
    }
    if (!widget.config.startWithInfoScreen) {
      _startLiveFeed();
    }
  }

  void _startTimer() {
    _timerToDetectFace = Timer(
      Duration(seconds: widget.config.maxSecToDetect),
      () {
        _timerToDetectFace?.cancel();
        _timerToDetectFace = null;
        if (widget.config.allowAfterMaxSec) {
          _isCaptureButtonVisible = true;
          setState(() {});
          return;
        }
        _onDetectionCompleted(
          imgToReturn: null,
        );
      },
    );
  }

  void _startLiveFeed() async {
    final camera = availableCams[_cameraIndex];
    // _cameraController = CameraController(
    //   camera,
    //   ResolutionPreset.high,
    //   imageFormatGroup: ImageFormatGroup.jpeg,
    //   enableAudio: false,
    // );
    // _cameraController?.initialize().then((_) {
    //   if (!mounted) {
    //     return;
    //   }
    //   _cameraController?.startImageStream(_processCameraImage);
    //   if (mounted) {
    //     _startTimer();
    //     setState(() {});
    //   }
    // });
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _cameraController?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _startTimer();
      _cameraController?.startImageStream(_processCameraImage);
      setState(() {});
    });
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in cameraImage.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(
      cameraImage.width.toDouble(),
      cameraImage.height.toDouble(),
    );

    final camera = availableCams[_cameraIndex];
    final imageRotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (imageRotation == null) return;

    final inputImageFormat = InputImageFormatValue.fromRawValue(
      cameraImage.format.raw,
    );
    if (inputImageFormat == null) return;

    final planeData = cameraImage.planes.map(
      (Plane plane) {
        return InputImageMetadata(
          size: Size(
            plane.width?.toDouble() ?? 0,
            plane.height?.toDouble() ?? 0,
          ),
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: plane.bytesPerRow,
        );
      },
    ).toList();

    final inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: planeData.first.bytesPerRow,
    );

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageData,
    );

    _processImage(inputImage);
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (_isBusy) {
      return;
    }
    _isBusy = true;
    final faces = await MLHelper.instance.processInputImage(inputImage);

    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      if (faces.isEmpty) {
        _resetSteps();
        _faceDistanceStatus = FaceStatus.unknown;
        _isFaceInOval = false;
      } else {
        final firstFace = faces.first;
        final painter = FaceDetectorPainter(
          firstFace,
          inputImage.metadata!.size,
          inputImage.metadata!.rotation,
        );
        _customPaint = CustomPaint(
          painter: painter,
          child: Container(
            color: Colors.transparent,
            height: double.infinity,
            width: double.infinity,
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              bottom: MediaQuery.of(context).padding.bottom,
            ),
          ),
        );
        
        // Check face distance and position
        _checkFacePosition(firstFace, inputImage.metadata!.size);
        
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
          face: faces.first,
          step: _steps[_stepsKey.currentState?.currentIndex ?? 0].step,
        );
      }
    } else {
      _resetSteps();
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _checkFacePosition(Face face, Size imageSize) {
    final faceWidth = face.boundingBox.width;
    final faceHeight = face.boundingBox.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate oval dimensions
    final ovalWidth = screenWidth * kOvalWidthRatio;
    final ovalHeight = screenHeight * kOvalHeightRatio;
    
    // Get face center position
    final faceCenterX = face.boundingBox.center.dx;
    final faceCenterY = face.boundingBox.center.dy;
    
    // Screen center
    final screenCenterX = screenWidth / 2;
    final screenCenterY = screenHeight / 2;
    
    // Check if face is within oval bounds (with some tolerance)
    final tolerance = 0.15; // 15% tolerance
    final isInHorizontalBounds = 
        (faceCenterX - screenCenterX).abs() < (ovalWidth / 2) * (1 + tolerance);
    final isInVerticalBounds = 
        (faceCenterY - screenCenterY).abs() < (ovalHeight / 2) * (1 + tolerance);
    
    _isFaceInOval = isInHorizontalBounds && isInVerticalBounds;
    
    // Check face distance based on face width ratio
    final faceWidthRatio = faceWidth / screenWidth;
    
    // Target ratio for good distance (adjust based on your needs)
    const targetRatio = 0.35;
    const toleranceRatio = 0.08;
    
    if (faceWidthRatio < targetRatio - toleranceRatio) {
      _faceDistanceStatus = FaceStatus.far;
      _stableFaceCount = 0;
      _isFaceStable = false;
    } else if (faceWidthRatio > targetRatio + toleranceRatio) {
      _faceDistanceStatus = FaceStatus.near;
      _stableFaceCount = 0;
      _isFaceStable = false;
    } else {
      _faceDistanceStatus = FaceStatus.good;
      
      // Count stable frames when face is in good position and in oval
      if (_isFaceInOval && !_isProcessingStep) {
        _stableFaceCount++;
        if (_stableFaceCount >= kRequiredStableFrames && !_isFaceStable) {
          _isFaceStable = true;
          _currentInstruction = 'Giữ nguyên vị trí...';
        }
      } else {
        _stableFaceCount = 0;
        _isFaceStable = false;
      }
    }
    
    // Update instruction text
    if (!_isFaceInOval) {
      _currentInstruction = 'Đưa khuôn mặt vào khung hình';
    } else if (_faceDistanceStatus == FaceStatus.far) {
      _currentInstruction = 'Đưa khuôn mặt lại gần hơn';
    } else if (_faceDistanceStatus == FaceStatus.near) {
      _currentInstruction = 'Đưa khuôn mặt ra xa hơn';
    } else if (_isFaceStable) {
      _currentInstruction = 'Giữ nguyên...';
    } else {
      _currentInstruction = 'Giữ khuôn mặt ổn định';
    }
  }

  Future<void> _completeStep({
    required LivelynessStep step,
  }) async {
    // Capture image at each step completion
    if (step != _lastCompletedStep) {
      await _captureStepImage();
    }
    _lastCompletedStep = step;

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

  Future<void> _captureStepImage() async {
    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        return;
      }
      final XFile? capturedImage = await _cameraController?.takePicture();
      if (capturedImage != null && mounted) {
        _capturedImagePaths.add(capturedImage.path);
      }
    } catch (e) {
      debugPrint('Error capturing step image: $e');
    }
  }

  void _takePicture({
    required bool didCaptureAutomatically,
  }) async {
    try {
      if (_cameraController == null) return;
      // if (face == null) return;
      if (_isTakingPicture) {
        return;
      }
      setState(
        () => _isTakingPicture = true,
      );
      await _cameraController?.stopImageStream();
      final XFile? clickedImage = await _cameraController?.takePicture();
      if (clickedImage == null) {
        _startLiveFeed();
        return;
      }
      _onDetectionCompleted(
        imgToReturn: clickedImage,
        didCaptureAutomatically: didCaptureAutomatically,
      );
    } catch (e) {
      _startLiveFeed();
    }
  }

  void _onDetectionCompleted({
    XFile? imgToReturn,
    bool? didCaptureAutomatically,
  }) {
    final String imgPath = imgToReturn?.path ?? "";
    if (imgPath.isEmpty || didCaptureAutomatically == null) {
      Navigator.of(context).pop(null);
      return;
    }
    
    // Return all captured images from each step
    Navigator.of(context).pop(
      _capturedImagePaths.map((path) {
        if (path != null && path.isNotEmpty) {
          return CapturedImage(
            imgPath: path,
            didCaptureAutomatically: didCaptureAutomatically,
          );
        }
      }).where((element) => element != null).toList(),
    );
  }

  void _resetSteps() async {
    for (var p0 in _steps) {
      final int index = _steps.indexWhere(
        (p1) => p1.step == p0.step,
      );
      _steps[index] = _steps[index].copyWith(
        isCompleted: false,
      );
    }
    _customPaint = null;
    _didCloseEyes = false;
    if (_stepsKey.currentState?.currentIndex != 0) {
      _stepsKey.currentState?.reset();
    }
    if (mounted) {
      setState(() {});
    }
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

  void _detect({
    required Face face,
    required LivelynessStep step,
  }) async {
    if (_isProcessingStep) {
      return;
    }
    final faceWidth = face.boundingBox.width;
    final Point<int>? leftEyePosition = face
        .getContour(
          FaceContourType.leftEye,
        )
        ?.points
        .elementAt(8);
    final Point<int>? rightEyePosition = face
        .getContour(
          FaceContourType.rightEye,
        )
        ?.points
        .elementAt(0);
    if (leftEyePosition != null && rightEyePosition != null) {
      final goldenRatio = (faceWidth /
          leftEyePosition.distanceTo(
            rightEyePosition,
          ));
      if (kDebugMode) {
        print("Golden Ratio: $goldenRatio");
      }
    }
    switch (step) {
      case LivelynessStep.blink:
        final BlinkDetectionThreshold? blinkThreshold =
            LivelynessDetection.instance.thresholdConfig.firstWhereOrNull(
          (p0) => p0 is BlinkDetectionThreshold,
        ) as BlinkDetectionThreshold?;
        if ((face.leftEyeOpenProbability ?? 1.0) <
                (blinkThreshold?.leftEyeProbability ?? 0.25) &&
            (face.rightEyeOpenProbability ?? 1.0) <
                (blinkThreshold?.rightEyeProbability ?? 0.25)) {
          _startProcessing();
          if (mounted) {
            setState(
              () => _didCloseEyes = true,
            );
          }
        }
        break;
      case LivelynessStep.turnLeft:
        final HeadTurnDetectionThreshold? headTurnThreshold =
            LivelynessDetection.instance.thresholdConfig.firstWhereOrNull(
          (p0) => p0 is HeadTurnDetectionThreshold,
        ) as HeadTurnDetectionThreshold?;
        if ((face.headEulerAngleY ?? 0) >
            (headTurnThreshold?.rotationAngle ?? 45)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
      case LivelynessStep.turnRight:
        final HeadTurnDetectionThreshold? headTurnThreshold =
            LivelynessDetection.instance.thresholdConfig.firstWhereOrNull(
          (p0) => p0 is HeadTurnDetectionThreshold,
        ) as HeadTurnDetectionThreshold?;
        if ((face.headEulerAngleY ?? 0) >
            (headTurnThreshold?.rotationAngle ?? -50)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
      case LivelynessStep.smile:
        final SmileDetectionThreshold? smileThreshold =
            LivelynessDetection.instance.thresholdConfig.firstWhereOrNull(
          (p0) => p0 is SmileDetectionThreshold,
        ) as SmileDetectionThreshold?;
        if ((face.smilingProbability ?? 0) >
            (smileThreshold?.probability ?? 0.75)) {
          _startProcessing();
          await _completeStep(step: step);
        }
        break;
      case LivelynessStep.lookStraight:
    }
  }

  //* MARK: - Private Methods for UI Components
  //? =========================================================
  Widget _buildBody() {
    return Stack(
      children: [
        _isInfoStepCompleted
            ? _buildDetectionBody()
            : LivelynessInfoWidget(
                onStartTap: () {
                  if (mounted) {
                    setState(
                      () => _isInfoStepCompleted = true,
                    );
                  }
                  _startLiveFeed();
                },
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
                onPressed: () => _onDetectionCompleted(
                  imgToReturn: null,
                  didCaptureAutomatically: null,
                ),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetectionBody() {
    if (_cameraController == null ||
        _cameraController?.value.isInitialized == false) {
      return const Center(
        child: CircularProgressIndicator.adaptive(),
      );
    }
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _cameraController!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    final Widget cameraView = CameraPreview(_cameraController!);
    
    // Calculate oval dimensions for face guide
    final screenWidth = size.width;
    final screenHeight = size.height;
    final ovalWidth = screenWidth * kOvalWidthRatio;
    final ovalHeight = screenHeight * kOvalHeightRatio;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: cameraView,
        ),
        BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: 5.0,
            sigmaY: 5.0,
          ),
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Center(
          child: cameraView,
        ),
        // Draw oval frame for face positioning
        Center(
          child: CustomPaint(
            painter: OvalFramePainter(
              ovalWidth: ovalWidth,
              ovalHeight: ovalHeight,
              isFaceInOval: _isFaceInOval,
              isFaceStable: _isFaceStable,
              faceDistanceStatus: _faceDistanceStatus,
            ),
            size: Size(screenWidth, screenHeight),
          ),
        ),
        if (widget.config.showFacialVertices) ...[
          if (_customPaint != null) _customPaint!,
        ],
        // Display current instruction
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                _currentInstruction.isNotEmpty 
                    ? _currentInstruction 
                    : _steps[_stepsKey.currentState?.currentIndex ?? 0].title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_faceDistanceStatus == FaceStatus.good && _isFaceInOval)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      kRequiredStableFrames ~/ 5,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < (_stableFaceCount ~/ 5)
                              ? Colors.green
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        LivelynessDetectionStepOverlay(
          key: _stepsKey,
          steps: _steps,
          onCompleted: () => Future.delayed(
            const Duration(milliseconds: 500),
            () => _takePicture(
              didCaptureAutomatically: true,
            ),
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
      ],
    );
  }
}

/// Custom painter to draw an oval frame for face positioning
class OvalFramePainter extends CustomPainter {
  final double ovalWidth;
  final double ovalHeight;
  final bool isFaceInOval;
  final bool isFaceStable;
  final FaceStatus faceDistanceStatus;

  OvalFramePainter({
    required this.ovalWidth,
    required this.ovalHeight,
    required this.isFaceInOval,
    required this.isFaceStable,
    required this.faceDistanceStatus,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = _getFrameColor();
    
    // Draw oval path
    final Rect ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: ovalWidth,
      height: ovalHeight,
    );
    
    // Draw the oval
    canvas.drawOval(ovalRect, paint);
    
    // Draw corner markers for better visual guidance
    final markerSize = 20.0;
    final markerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = _getFrameColor();
    
    // Top-left corner
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.top + markerSize),
      Offset(ovalRect.left, ovalRect.top),
      markerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.top),
      Offset(ovalRect.left + markerSize, ovalRect.top),
      markerPaint,
    );
    
    // Top-right corner
    canvas.drawLine(
      Offset(ovalRect.right, ovalRect.top + markerSize),
      Offset(ovalRect.right, ovalRect.top),
      markerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.right, ovalRect.top),
      Offset(ovalRect.right - markerSize, ovalRect.top),
      markerPaint,
    );
    
    // Bottom-left corner
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.bottom - markerSize),
      Offset(ovalRect.left, ovalRect.bottom),
      markerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.bottom),
      Offset(ovalRect.left + markerSize, ovalRect.bottom),
      markerPaint,
    );
    
    // Bottom-right corner
    canvas.drawLine(
      Offset(ovalRect.right, ovalRect.bottom - markerSize),
      Offset(ovalRect.right, ovalRect.bottom),
      markerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.right, ovalRect.bottom),
      Offset(ovalRect.right - markerSize, ovalRect.bottom),
      markerPaint,
    );
  }

  Color _getFrameColor() {
    if (!isFaceInOval) {
      return Colors.white.withOpacity(0.8);
    } else if (faceDistanceStatus == FaceStatus.far ||
        faceDistanceStatus == FaceStatus.near) {
      return Colors.orange;
    } else if (isFaceStable) {
      return Colors.green;
    } else {
      return Colors.blue.withOpacity(0.8);
    }
  }

  @override
  bool shouldRepaint(OvalFramePainter oldDelegate) {
    return oldDelegate.isFaceInOval != isFaceInOval ||
        oldDelegate.isFaceStable != isFaceStable ||
        oldDelegate.faceDistanceStatus != faceDistanceStatus;
  }
}

extension FaceExt on Face {
  FaceContour? getContour(FaceContourType type) {
    switch (type) {
      case FaceContourType.face:
        return contours[FaceContourType.face];
      case FaceContourType.leftEyebrowTop:
        return contours[FaceContourType.leftEyebrowTop];
      case FaceContourType.leftEyebrowBottom:
        return contours[FaceContourType.leftEyebrowBottom];
      case FaceContourType.rightEyebrowTop:
        return contours[FaceContourType.rightEyebrowTop];
      case FaceContourType.rightEyebrowBottom:
        return contours[FaceContourType.rightEyebrowBottom];
      case FaceContourType.leftEye:
        return contours[FaceContourType.leftEye];
      case FaceContourType.rightEye:
        return contours[FaceContourType.rightEye];
      case FaceContourType.upperLipTop:
        return contours[FaceContourType.upperLipTop];
      case FaceContourType.upperLipBottom:
        return contours[FaceContourType.upperLipBottom];
      case FaceContourType.lowerLipTop:
        return contours[FaceContourType.lowerLipTop];
      case FaceContourType.lowerLipBottom:
        return contours[FaceContourType.lowerLipBottom];
      case FaceContourType.noseBridge:
        return contours[FaceContourType.noseBridge];
      case FaceContourType.noseBottom:
        return contours[FaceContourType.noseBottom];
      case FaceContourType.leftCheek:
        return contours[FaceContourType.leftCheek];
      case FaceContourType.rightCheek:
        return contours[FaceContourType.rightCheek];
    }
  }
}

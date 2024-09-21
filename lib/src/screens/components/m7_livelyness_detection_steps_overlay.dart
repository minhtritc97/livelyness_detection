import 'package:livelyness_detection/index.dart';

class LivelynessDetectionStepOverlay extends StatefulWidget {
  final List<LivelynessStepItem> steps;
  final VoidCallback onCompleted;
  const LivelynessDetectionStepOverlay({
    super.key,
    required this.steps,
    required this.onCompleted,
  });

  @override
  State<LivelynessDetectionStepOverlay> createState() =>
      LivelynessDetectionStepOverlayState();
}

class LivelynessDetectionStepOverlayState
    extends State<LivelynessDetectionStepOverlay> {
  //* MARK: - Public Variables
  //? =========================================================
  int get currentIndex {
    return _currentIndex;
  }

  bool _isLoading = false;

  //* MARK: - Private Variables
  //? =========================================================
  int _currentIndex = 0;

  late final PageController _pageController;

  //* MARK: - Life Cycle Methods
  //? =========================================================
  @override
  void initState() {
    _pageController = PageController(
      initialPage: 0,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBody(),
          Visibility(
            visible: _isLoading,
            child: Center(
              child: Lottie.asset(
                AssetConstants.lottie.check,
                package: AssetConstants.packageName,
                animate: true,
                repeat: false,
                reverse: false,
                fit: BoxFit.contain,
                width: 40,
                height: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //* MARK: - Public Methods for Business Logic
  //? =========================================================
  Future<void> nextPage() async {
    if (_isLoading) {
      return;
    }
    if ((_currentIndex + 1) <= (widget.steps.length - 1)) {
      //Move to next step
      _showLoader();
      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeIn,
      );
      // await Future.delayed(
      //   const Duration(seconds: 1),
      // );
      _hideLoader();
      setState(() => _currentIndex++);
    } else {
      _showLoader();
      await Future.delayed(
        const Duration(milliseconds: 500),
      );
      _hideLoader();
      widget.onCompleted();
    }
  }

  void reset() {
    _pageController.jumpToPage(0);
    setState(() => _currentIndex = 0);
  }

  //* MARK: - Private Methods for Business Logic
  //? =========================================================
  void _showLoader() => setState(
        () => _isLoading = true,
      );

  void _hideLoader() => setState(
        () => _isLoading = false,
      );

  //* MARK: - Private Methods for UI Components
  //? =========================================================
  Widget _buildBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          flex: 4,
          child: AbsorbPointer(
            absorbing: true,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.steps.length,
              itemBuilder: (context, index) {
                return _buildAnimatedWidget(
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      widget.steps[index].title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.yellow[200],
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                  isExiting: index != _currentIndex,
                );
              },
            ),
          ),
        ),
        const Spacer(flex: 14),
        Padding(
          padding: const EdgeInsets.fromLTRB(60, 60, 60, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.grey,
              ),
              height: 10,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    flex: _currentIndex,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        gradient: LinearGradient(
                            colors: [Colors.green.shade800, Colors.lightGreen]),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: widget.steps.length - (_currentIndex),
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Center(
          child: Text(
            '${(((_currentIndex) / widget.steps.length) * 100).toStringAsFixed(0)}% Xác thực',
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16)
      ],
    );
  }

  Widget _buildAnimatedWidget(
    Widget child, {
    required bool isExiting,
  }) {
    return isExiting
        ? ZoomOut(
            animate: true,
            child: FadeOutLeft(
              animate: true,
              delay: const Duration(milliseconds: 200),
              child: child,
            ),
          )
        : ZoomIn(
            animate: true,
            delay: const Duration(milliseconds: 500),
            child: FadeInRight(
              animate: true,
              delay: const Duration(milliseconds: 700),
              child: child,
            ),
          );
  }
}

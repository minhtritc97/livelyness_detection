import 'package:livelyness_detection/index.dart';

class LivelynessInfoWidget extends StatefulWidget {
  final VoidCallback onStartTap;
  const LivelynessInfoWidget({
    required this.onStartTap,
    super.key,
  });

  @override
  State<LivelynessInfoWidget> createState() => _LivelynessInfoWidgetState();
}

class _LivelynessInfoWidgetState extends State<LivelynessInfoWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              StringConstants.label.livelyNessDetection,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              StringConstants.label.infoSubText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.normal,
                fontSize: 18,
                height: 1.5,
              ),
            ),
          ),
          Container(
            width: 120,
            height: 120,
            color: Colors.transparent,
            child: Lottie.asset(
              AssetConstants.lottie.livelynessStart,
              package: AssetConstants.packageName,
              animate: true,
              repeat: true,
              reverse: false,
              fit: BoxFit.contain,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 5,
                      spreadRadius: 2.5,
                      color: Colors.black12,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: _buildPointWidget(
                            index: 1,
                            title: StringConstants.label.goodLighting,
                            subTitle: StringConstants.label.goodLightingSubText,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: _buildPointWidget(
                            index: 2,
                            title: StringConstants.label.lookStraight,
                            subTitle: StringConstants.label.lookStraightSubText,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: _buildPointWidget(
                            index: 3,
                            title: StringConstants.label.clearFace,
                            subTitle: StringConstants.label.clearFaceSubText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),
          Center(
            child: ElevatedButton(
              onPressed: () => widget.onStartTap(),
              style: TextButton.styleFrom(
                elevation: 3,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
              child: Text(
                StringConstants.button.start,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 24,
                    color: Colors.green),
              ),
            ),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _buildPointWidget({
    required int index,
    required String title,
    required String subTitle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: Colors.green.shade900,
          child: Text(
            "$index",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const Spacer(),
        Expanded(
          flex: 10,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  textAlign: TextAlign.start,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              // const Spacer(),
              Align(
                alignment: Alignment.topLeft,
                child: Text(
                  subTitle,
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

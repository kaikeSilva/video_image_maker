import 'package:flutter/material.dart';
import '../../../widgets/video_quality_selector.dart';
import '../video_generation_controller.dart';
import '../../../models/video_generation/video_generation_state.dart';

class VideoQualitySelectorWidget extends StatelessWidget {
  final VideoGenerationState state;
  final VideoGenerationController controller;

  const VideoQualitySelectorWidget({
    Key? key,
    required this.state,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: VideoQualitySelector(
          initialQuality: state.encoderQuality,
          initialFormat: state.videoFormat,
          onQualityChanged: (quality) {
            controller.updateQuality(quality);
          },
          onFormatChanged: (format) {
            controller.updateFormat(format);
          },
        ),
      ),
    );
  }
}

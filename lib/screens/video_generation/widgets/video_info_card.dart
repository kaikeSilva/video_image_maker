import 'package:flutter/material.dart';
import '../../../providers/project_provider.dart';
import '../video_generation_controller.dart';

class VideoInfoCard extends StatelessWidget {
  final ProjectProvider projectProvider;
  final VideoGenerationController controller;

  const VideoInfoCard({
    Key? key,
    required this.projectProvider,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informações do Projeto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Áudio: ${controller.getAudioFileName(projectProvider.project.audioFilePath)}',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            Text(
              'Imagens: ${projectProvider.project.timelineItems.length}',
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Duração Estimada: ${controller.formatDuration(projectProvider.project.audioDuration)}',
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

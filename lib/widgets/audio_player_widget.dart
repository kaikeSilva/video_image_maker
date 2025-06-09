import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../providers/audio_player_provider.dart';
import 'audio_timeline_widget.dart';

class AudioPlayerWidget extends StatelessWidget {
  const AudioPlayerWidget({Key? key}) : super(key: key);

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = Provider.of<ProjectProvider>(context);
    final audioPlayerProvider = Provider.of<AudioPlayerProvider>(context);
    final audioFilePath = projectProvider.project.audioFilePath;

    // Carregar áudio se o caminho for diferente do atual
    if (audioFilePath != null && audioFilePath.isNotEmpty) {
      // Carregar áudio se o caminho for diferente do atual
      WidgetsBinding.instance.addPostFrameCallback((_) {
        audioPlayerProvider.loadAudio(audioFilePath);
      });

      return Column(
        children: [
          // Controles de áudio
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botão de play/pause
              IconButton(
                icon: Icon(
                  audioPlayerProvider.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 48,
                ),
                onPressed: () {
                  if (audioPlayerProvider.isPlaying) {
                    audioPlayerProvider.pause();
                  } else {
                    audioPlayerProvider.play();
                  }
                },
              ),
              // Botão de parar
              IconButton(
                icon: const Icon(
                  Icons.stop_circle,
                  size: 48,
                ),
                onPressed: () {
                  audioPlayerProvider.stop();
                },
              ),
            ],
          ),
          // Duração do áudio
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Duração total: ${_formatDuration(audioPlayerProvider.duration)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // Timeline do áudio
          AudioTimelineWidget(
            audioPlayer: audioPlayerProvider.audioPlayer,
          ),
        ],
      );
    } else {
      return const Center(
        child: Text('Nenhum áudio selecionado'),
      );
    }
  }
}

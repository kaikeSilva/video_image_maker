import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import 'audio_timeline_widget.dart';

// Chave global para acessar o state do AudioPlayerWidget
final GlobalKey<_AudioPlayerWidgetState> _audioPlayerKey = GlobalKey<_AudioPlayerWidgetState>();

class AudioPlayerWidget extends StatefulWidget {
  const AudioPlayerWidget({Key? key = _audioPlayerKey}) : super(key: key);
  
  // Método estático para acessar o AudioPlayer de fora
  static AudioPlayer? getAudioPlayer() {
    return _audioPlayerKey.currentState?.audioPlayer;
  }
  
  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  String? _audioFilePath;
  
  // Expor o AudioPlayer para uso em outros widgets
  AudioPlayer get audioPlayer => _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer.playerStateStream.listen((state) {
      if (state.playing != _isPlaying) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    // We don't need to track position here as it's handled in the timeline widget

    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAudio(String filePath) async {
    if (_audioFilePath != filePath) {
      await _audioPlayer.setFilePath(filePath);
      _audioFilePath = filePath;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, projectProvider, child) {
        final audioFilePath = projectProvider.project.audioFilePath;
        
        if (audioFilePath == null) {
          return const Center(
            child: Text('Nenhum arquivo de áudio selecionado'),
          );
        }

        // Load audio if needed
        _loadAudio(audioFilePath);

        return Column(
          children: [
            // Timeline widget
            AudioTimelineWidget(audioPlayer: _audioPlayer),
            
            const SizedBox(height: 8),
            
            // Player controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Play/Pause button
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 48,
                  ),
                  onPressed: () {
                    if (_isPlaying) {
                      _audioPlayer.pause();
                    } else {
                      _audioPlayer.play();
                    }
                  },
                ),
                
                // Stop button
                IconButton(
                  icon: const Icon(
                    Icons.stop_circle,
                    size: 48,
                  ),
                  onPressed: () {
                    _audioPlayer.stop();
                    _audioPlayer.seek(Duration.zero);
                  },
                ),
              ],
            ),
            
            // Duration text
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Duração total: ${_formatDuration(_duration)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}

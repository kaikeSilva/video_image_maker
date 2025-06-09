import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/project_provider.dart';

class AudioTimelineWidget extends StatefulWidget {
  final AudioPlayer audioPlayer;
  
  const AudioTimelineWidget({
    Key? key,
    required this.audioPlayer,
  }) : super(key: key);

  @override
  State<AudioTimelineWidget> createState() => _AudioTimelineWidgetState();
}

class _AudioTimelineWidgetState extends State<AudioTimelineWidget> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  late StreamSubscription<Duration> _positionSubscription;
  late StreamSubscription<Duration?> _durationSubscription;

  @override
  void initState() {
    super.initState();
    
    // Listen to position changes with more frequent updates
    _positionSubscription = widget.audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });

    // Listen to duration changes
    _durationSubscription = widget.audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  void dispose() {
    _positionSubscription.cancel();
    _durationSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, projectProvider, child) {
        final audioFilePath = projectProvider.project.audioFilePath;
        
        if (audioFilePath == null) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            // Current timestamp display
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                'Posição atual: ${_formatDuration(_position)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            
            // Timeline slider with fine control
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 8,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                activeTrackColor: Theme.of(context).primaryColor,
                inactiveTrackColor: Colors.grey.shade300,
                thumbColor: Theme.of(context).primaryColor,
                overlayColor: Theme.of(context).primaryColor.withOpacity(0.3),
                // Melhorar a precisão do slider
                showValueIndicator: ShowValueIndicator.always,
                valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                valueIndicatorColor: Theme.of(context).primaryColorDark,
                valueIndicatorTextStyle: const TextStyle(color: Colors.white),
              ),
              child: Slider(
                min: 0,
                max: _duration.inMilliseconds.toDouble(),
                value: _position.inMilliseconds.toDouble().clamp(
                  0, 
                  _duration.inMilliseconds.toDouble()
                ),
                // Mostrar o valor em mm:ss durante o arrasto
                label: _formatDuration(Duration(milliseconds: _position.inMilliseconds)),
                divisions: _duration.inMilliseconds > 0 ? 
                    (_duration.inMilliseconds ~/ 100).clamp(100, 1000) : 100, // Divisões para controle fino
                onChanged: (value) {
                  final position = Duration(milliseconds: value.round());
                  setState(() {
                    _position = position; // Atualizar imediatamente para feedback visual
                  });
                  widget.audioPlayer.seek(position);
                },
              ),
            ),
            
            // Time indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_position),
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

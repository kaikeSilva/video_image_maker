import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _audioFilePath;

  AudioPlayer get audioPlayer => _audioPlayer;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get audioFilePath => _audioFilePath;

  AudioPlayerProvider() {
    _init();
  }

  void _init() {
    // Ouvir mudanças no estado de reprodução
    _audioPlayer.playerStateStream.listen((state) {
      if (state.playing != _isPlaying) {
        _isPlaying = state.playing;
        notifyListeners();
      }
    });

    // Ouvir mudanças na posição
    _audioPlayer.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });

    // Ouvir mudanças na duração
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _duration = duration;
        notifyListeners();
      }
    });
  }

  Future<void> loadAudio(String filePath) async {
    if (_audioFilePath != filePath) {
      await _audioPlayer.setFilePath(filePath);
      _audioFilePath = filePath;
      notifyListeners();
    }
  }

  void play() {
    _audioPlayer.play();
  }

  void pause() {
    _audioPlayer.pause();
  }

  void stop() {
    _audioPlayer.stop();
    _audioPlayer.seek(Duration.zero);
  }

  void seek(Duration position) {
    _audioPlayer.seek(position);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

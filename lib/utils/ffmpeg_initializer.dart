import 'package:flutter/material.dart';
import '../services/ffmpeg_service.dart';

class FFmpegInitializer {
  // Singleton pattern
  static final FFmpegInitializer _instance = FFmpegInitializer._internal();
  factory FFmpegInitializer() => _instance;
  FFmpegInitializer._internal();
  
  // Status de inicialização
  bool _initialized = false;
  
  // Getter para verificar se o FFmpeg foi inicializado
  bool get isInitialized => _initialized;
  
  // Inicializa o FFmpeg
  Future<bool> initializeFFmpeg() async {
    if (_initialized) return true;
    
    final ffmpegService = FFmpegService();
    final result = await ffmpegService.initialize();
    
    if (result) {
      debugPrint('FFmpeg inicializado com sucesso. Versão: ${ffmpegService.version}');
      _initialized = true;
    } else {
      debugPrint('Falha ao inicializar o FFmpeg');
    }
    
    return result;
  }
  
  // Verifica a disponibilidade do FFmpeg e mostra um diálogo se não estiver disponível
  Future<bool> checkFFmpegAvailability(BuildContext context) async {
    final ffmpegService = FFmpegService();
    final isAvailable = await ffmpegService.checkAvailability();
    
    if (!isAvailable && context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('FFmpeg não disponível'),
          content: const Text(
            'O FFmpeg não está disponível neste dispositivo. '
            'Algumas funcionalidades de geração de vídeo podem não funcionar corretamente.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    
    return isAvailable;
  }
}

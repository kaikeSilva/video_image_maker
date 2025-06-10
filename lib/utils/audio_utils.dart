import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../services/log_service.dart';

/// Utilitários para processamento de áudio
class AudioUtils {
  static final LogService _logService = LogService();

  /// Obtém a duração do áudio em segundos
  static Future<double> getAudioDuration(String audioPath) async {
    try {
      final player = AudioPlayer();
      final duration = await player.setFilePath(audioPath);
      await player.dispose();
      
      if (duration != null) {
        return duration.inMilliseconds / 1000.0;
      } else {
        throw Exception('Não foi possível determinar a duração do áudio');
      }
    } catch (e) {
      _logService.error('AudioUtils', 'Erro ao obter duração do áudio: $e');
      rethrow;
    }
  }

  /// Converte um arquivo de áudio para o formato PCM
  /// O flutter_quick_video_encoder espera dados PCM brutos
  static Future<String> convertAudioToPcm(String audioPath, int sampleRate, int channels) async {
    try {
      // Obtém um diretório temporário para salvar o arquivo PCM
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.pcm';
      
      // Comando FFmpeg para converter o áudio para PCM 16-bit com a taxa de amostragem e canais especificados
      // Usamos exatamente os mesmos parâmetros que serão usados pelo encoder
      final command = '-i "$audioPath" -f s16le -acodec pcm_s16le -ar $sampleRate -ac $channels "$outputPath"';
      
      _logService.info('AudioUtils', 'Convertendo áudio para PCM: $command');
      _logService.info('AudioUtils', 'Parâmetros: sampleRate=$sampleRate, channels=$channels');
      
      // Executa o comando FFmpeg
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      
      // Verifica se a conversão foi bem-sucedida
      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(outputPath);
        final fileSize = await file.length();
        _logService.info('AudioUtils', 'Áudio convertido com sucesso para PCM: $outputPath (${fileSize} bytes)');
        return outputPath;
      } else {
        final logs = await session.getLogs();
        throw Exception('Erro ao converter áudio para PCM: ${logs.join('\n')}');
      }
    } catch (e, stackTrace) {
      _logService.error('AudioUtils', 'Erro ao converter áudio para PCM: $e');
      _logService.exception('AudioUtils', e, stackTrace);
      rethrow;
    }
  }
  
  /// Carrega os bytes de áudio PCM de um arquivo
  static Future<Uint8List> loadPcmAudioBytes(String pcmFilePath) async {
    try {
      final file = File(pcmFilePath);
      if (!file.existsSync()) {
        throw Exception('Arquivo PCM não encontrado: $pcmFilePath');
      }
      
      final bytes = await file.readAsBytes();
      _logService.info('AudioUtils', 'Arquivo PCM carregado: ${bytes.length} bytes');
      return bytes;
    } catch (e, stackTrace) {
      _logService.error('AudioUtils', 'Erro ao carregar arquivo PCM: $e');
      _logService.exception('AudioUtils', e, stackTrace);
      rethrow;
    }
  }

  /// Processa o áudio para um frame específico
  static Future<Uint8List> processAudioForFrame(
    int frameIndex, 
    Uint8List pcmAudioBytes, 
    int sampleRate, 
    int audioChannels, 
    double fps
  ) async {
    try {
      // Calcula o tamanho exato do frame de áudio PCM para este frame
      // O tamanho deve ser (sampleRate * audioChannels * 2) / fps
      // onde 2 é o número de bytes por amostra (16 bits = 2 bytes)
      final int requiredFrameSize = ((sampleRate * audioChannels * 2) / fps).round();
      
      // Cria um buffer de áudio do tamanho exato necessário
      final Uint8List audioFrame = Uint8List(requiredFrameSize);
      
      // Calcula a posição inicial no buffer de áudio PCM para este frame
      // Usamos uma abordagem mais precisa para calcular a posição de tempo
      final double frameDuration = 1.0 / fps; // duração de um frame em segundos
      final double frameTimeSeconds = frameIndex * frameDuration; // tempo exato deste frame em segundos
      final int framePosition = (frameTimeSeconds * sampleRate * audioChannels * 2).round();
      
      // Garantir que a posição seja múltipla de (audioChannels * 2) para evitar desalinhamento de amostras
      final int alignedPosition = framePosition - (framePosition % (audioChannels * 2));
      
      // Copia os bytes do áudio PCM para o frame de áudio
      // Certifica-se de não ultrapassar o tamanho do buffer de áudio PCM
      if (alignedPosition < pcmAudioBytes.length) {
        final int bytesToCopy = min(requiredFrameSize, pcmAudioBytes.length - alignedPosition);
        if (bytesToCopy > 0) {
          audioFrame.setRange(0, bytesToCopy, pcmAudioBytes, alignedPosition);
          
          // Se não tivermos bytes suficientes, preenchemos o resto com silêncio (zeros)
          if (bytesToCopy < requiredFrameSize) {
            audioFrame.fillRange(bytesToCopy, requiredFrameSize, 0);
          }
        } else {
          // Se não houver bytes para copiar, preencher com silêncio
          audioFrame.fillRange(0, requiredFrameSize, 0);
        }
      } else {
        // Se a posição estiver além do tamanho do áudio, preencher com silêncio
        audioFrame.fillRange(0, requiredFrameSize, 0);
      }
      
      return audioFrame;
    } catch (e) {
      _logService.error('AudioUtils', 'Erro ao processar áudio para o frame $frameIndex: $e');
      // Em caso de erro, retorna um frame de silêncio
      return Uint8List(((sampleRate * audioChannels * 2) / fps).round());
    }
  }
}

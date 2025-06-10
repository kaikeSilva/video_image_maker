import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:path_provider/path_provider.dart';

import '../models/image_sequence_item.dart';
import '../utils/audio_utils.dart';
import '../utils/image_utils.dart';
import '../utils/encoder_config.dart';
import 'log_service.dart';

/// Serviço para codificação de vídeo usando o flutter_quick_video_encoder
class QuickVideoEncoderService {
  static final QuickVideoEncoderService _instance = QuickVideoEncoderService._internal();
  final LogService _logService = LogService();
  
  factory QuickVideoEncoderService() {
    return _instance;
  }

  QuickVideoEncoderService._internal();

  /// Gera um vídeo a partir de uma sequência de imagens e um arquivo de áudio
  /// Usa o flutter_quick_video_encoder para processamento nativo de vídeo
  Future<String> generateVideo({
    required List<ImageSequenceItem> imageSequence,
    required String inputAudioPath,
    required Function(double) onProgress,
    VideoQuality quality = VideoQuality.medium,
    VideoFormat format = VideoFormat.mobile,
    int? timeoutSeconds,
  }) async {
    try {
      _logService.info('QuickVideoEncoderService', 'Iniciando geração de vídeo com QuickVideoEncoderService');
      
      // Verifica se os arquivos existem
      if (imageSequence.isEmpty) {
        throw Exception('Nenhuma imagem fornecida para geração de vídeo');
      }

      final audioFile = File(inputAudioPath);
      if (!audioFile.existsSync()) {
        throw Exception('Arquivo de áudio não encontrado: $inputAudioPath');
      }

      // Cria diretório temporário para arquivos de processamento
      final tempDir = await getTemporaryDirectory();
      final outputDir = Directory('${tempDir.path}/video_output');
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }

      // Define o caminho de saída do vídeo
      final outputPath = '${outputDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      _logService.info('QuickVideoEncoderService', 'Caminho de saída do vídeo: $outputPath');

      // Obtém a duração do áudio
      final audioDuration = await AudioUtils.getAudioDuration(inputAudioPath);
      _logService.info('QuickVideoEncoderService', 'Duração do áudio: $audioDuration segundos');
      
      if (audioDuration <= 0) {
        throw Exception('Não foi possível determinar a duração do áudio ou o áudio está vazio');
      }

      // Ordena as imagens por tempo
      imageSequence.sort((a, b) => a.startTimeInSeconds.compareTo(b.startTimeInSeconds));
      _logService.info('QuickVideoEncoderService', 'Sequência de imagens ordenada: ${imageSequence.length} imagens');

      // Parâmetros de áudio
      const int fps = 30;
      const int audioChannels = 2;
      const int audioBitrate = 128000; // 128 kbps
      const int sampleRate = 44100;

      _logService.info('QuickVideoEncoderService', 'Qualidade de vídeo selecionada: ${quality.displayName}');
      _logService.info('QuickVideoEncoderService', 'Formato de vídeo: ${format.displayName}');
      _logService.info('QuickVideoEncoderService', 'Dimensões: ${quality.getWidth(format)}x${quality.getHeight(format)}, Bitrate: ${quality.videoBitrate / 1000000} Mbps');
      
      // Verificação adicional para garantir que o formato está sendo aplicado corretamente
      final bool isDesktopFormat = format == VideoFormat.desktop;
      final int videoWidth = quality.getWidth(format);
      final int videoHeight = quality.getHeight(format);
      final bool dimensionsCorrect = isDesktopFormat ? (videoWidth > videoHeight) : (videoHeight > videoWidth);
      
      _logService.info('QuickVideoEncoderService', 'Verificação de formato: ' +
          'isDesktopFormat=$isDesktopFormat, ' +
          'dimensões=${videoWidth}x${videoHeight}, ' +
          'proporção correta=${dimensionsCorrect ? "SIM" : "NÃO"}');

      // Configura e inicializa o encoder com a qualidade e formato selecionados
      final encoderConfig = EncoderConfig(
        quality: quality,
        format: format,
        fps: fps,
        audioChannels: audioChannels,
        audioBitrate: audioBitrate,
        sampleRate: sampleRate,
        outputPath: outputPath,
      );
      
      await encoderConfig.setupEncoder();
      _logService.info('QuickVideoEncoderService', 'Encoder inicializado com sucesso');

      // Converte o áudio para PCM usando FFmpeg com os mesmos parâmetros do encoder
      _logService.info('QuickVideoEncoderService', 'Convertendo áudio para PCM');
      final pcmAudioPath = await AudioUtils.convertAudioToPcm(inputAudioPath, sampleRate, audioChannels);
      
      // Carrega os bytes do áudio PCM
      final pcmAudioBytes = await AudioUtils.loadPcmAudioBytes(pcmAudioPath);
      _logService.info('QuickVideoEncoderService', 'Áudio PCM carregado: ${pcmAudioBytes.length} bytes');
      
      // Calcula o número total de frames com base na duração do áudio e FPS
      final int totalFrames = (audioDuration * fps).round();
      _logService.info('QuickVideoEncoderService', 'Total de frames a serem gerados: $totalFrames');

      // Prepara as imagens
      final List<ui.Image> images = await ImageUtils.loadImages(imageSequence);
      _logService.info('QuickVideoEncoderService', 'Imagens carregadas: ${images.length} imagens');

      // Processamento de frames
      await _processFrames(
        imageSequence: imageSequence,
        images: images,
        totalFrames: totalFrames,
        fps: fps,
        width: quality.getWidth(format),
        height: quality.getHeight(format),
        pcmAudioBytes: pcmAudioBytes,
        sampleRate: sampleRate,
        audioChannels: audioChannels,
        onProgress: onProgress,
      );
      
      // Finaliza a codificação do vídeo
      return await _finalizeVideo(outputPath);
    } catch (e, stackTrace) {
      _logService.error('QuickVideoEncoderService', 'Erro ao gerar vídeo: $e');
      _logService.exception('QuickVideoEncoderService', e, stackTrace);
      rethrow;
    }
  }

  /// Processa os frames de vídeo e áudio
  Future<void> _processFrames({
    required List<ImageSequenceItem> imageSequence,
    required List<ui.Image> images,
    required int totalFrames,
    required int fps,
    required int width,
    required int height,
    required Uint8List pcmAudioBytes,
    required int sampleRate,
    required int audioChannels,
    required Function(double) onProgress,
  }) async {
    _logService.info('QuickVideoEncoderService', 'Iniciando processamento de frames...');
    
    for (int i = 0; i < totalFrames; i++) {
      try {
        final progress = i / totalFrames;
        
        // Calcula o tempo atual em segundos
        final double currentTimeInSeconds = i / fps;
        
        // Encontra a imagem correspondente ao tempo atual
        final ImageSequenceItem currentImage = ImageUtils.findImageForTime(imageSequence, currentTimeInSeconds);
        
        // Encontra o índice da imagem na lista de imagens carregadas
        final int imageIndex = imageSequence.indexOf(currentImage);
        
        // Gera o frame de vídeo a partir da imagem
        final Uint8List? frameData = await ImageUtils.generateVideoFrame(images[imageIndex], width, height);
        
        if (frameData != null) {
          // Adiciona o frame de vídeo ao encoder
          await FlutterQuickVideoEncoder.appendVideoFrame(frameData);
          if (i % 10 == 0) { // Reduzir quantidade de logs
            _logService.debug('QuickVideoEncoderService', 'Frame de vídeo $i adicionado: ${frameData.length} bytes');
          }
          
          // Processa o áudio para este frame
          final audioFrame = await AudioUtils.processAudioForFrame(
            i, pcmAudioBytes, sampleRate, audioChannels, fps.toDouble());
          
          // Adiciona o frame de áudio ao encoder
          await FlutterQuickVideoEncoder.appendAudioFrame(audioFrame);
          
          if (i % 10 == 0) { // Reduzir a quantidade de logs
            _logService.debug('QuickVideoEncoderService', 'Frame de áudio $i adicionado: ${audioFrame.length} bytes');
          }
          
          // Notifica o progresso
          onProgress(progress);
          
          // Log a cada 10% de progresso
          if (i % (totalFrames ~/ 10) == 0) {
            _logService.debug('QuickVideoEncoderService', 'Progresso da geração de vídeo: ${(progress * 100).toStringAsFixed(1)}%');
          }
        } else {
          _logService.warning('QuickVideoEncoderService', 'Frame de vídeo nulo gerado para o tempo $currentTimeInSeconds');
        }
      } catch (e, stackTrace) {
        _logService.error('QuickVideoEncoderService', 'Erro ao processar frame $i: $e');
        _logService.exception('QuickVideoEncoderService', e, stackTrace);
        // Continua para o próximo frame mesmo em caso de erro
      }
    }
  }

  /// Finaliza a codificação do vídeo e verifica o resultado
  Future<String> _finalizeVideo(String outputPath) async {
    _logService.info('QuickVideoEncoderService', 'Finalizando a codificação do vídeo...');
    try {
      await FlutterQuickVideoEncoder.finish();
      
      // Verifica se o arquivo de vídeo foi criado e tem tamanho adequado
      final File outputFile = File(outputPath);
      if (outputFile.existsSync()) {
        final int fileSize = await outputFile.length();
        _logService.info('QuickVideoEncoderService', 'Tamanho do arquivo de vídeo gerado: ${fileSize} bytes');
        
        if (fileSize < 10000) { // Menos de 10KB provavelmente indica um problema
          _logService.error('QuickVideoEncoderService', 'Arquivo de vídeo gerado é muito pequeno: $fileSize bytes');
          throw Exception('O arquivo de vídeo gerado parece estar corrompido (tamanho muito pequeno)');
        }
      } else {
        _logService.error('QuickVideoEncoderService', 'Arquivo de vídeo não encontrado após finalização');
        throw Exception('Arquivo de vídeo não encontrado após finalização');
      }
      
      _logService.info('QuickVideoEncoderService', 'Vídeo gerado com sucesso: $outputPath');
      return outputPath;
    } catch (e) {
      _logService.error('QuickVideoEncoderService', 'Erro ao finalizar a codificação do vídeo: $e');
      rethrow;
    }
  }
}

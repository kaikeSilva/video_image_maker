import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/image_sequence_item.dart';
import 'log_service.dart';

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
      final audioDuration = await _getAudioDuration(inputAudioPath);
      _logService.info('QuickVideoEncoderService', 'Duração do áudio: $audioDuration segundos');
      
      if (audioDuration <= 0) {
        throw Exception('Não foi possível determinar a duração do áudio ou o áudio está vazio');
      }

      // Ordena as imagens por tempo
      imageSequence.sort((a, b) => a.startTimeInSeconds.compareTo(b.startTimeInSeconds));
      _logService.info('QuickVideoEncoderService', 'Sequência de imagens ordenada: ${imageSequence.length} imagens');

      // Parâmetros de vídeo
      const int width = 1280;
      const int height = 720;
      const int fps = 30;
      const int videoBitrate = 2500000; // 2.5 Mbps
      
      // Parâmetros de áudio
      const int audioChannels = 2;
      const int audioBitrate = 128000; // 128 kbps
      const int sampleRate = 44100;

      // Inicializa o encoder
      await FlutterQuickVideoEncoder.setup(
        width: width,
        height: height,
        fps: fps,
        videoBitrate: videoBitrate,
        audioChannels: audioChannels,
        audioBitrate: audioBitrate,
        sampleRate: sampleRate,
        filepath: outputPath,
        profileLevel: ProfileLevel.baseline31, // Perfil de codificação H.264 compatível com a maioria dos dispositivos
      );
      
      _logService.info('QuickVideoEncoderService', 'Encoder inicializado com sucesso');

      // Converte o áudio para PCM usando FFmpeg com os mesmos parâmetros do encoder
      _logService.info('QuickVideoEncoderService', 'Convertendo áudio para PCM');
      final pcmAudioPath = await _convertAudioToPcm(inputAudioPath, sampleRate, audioChannels);
      
      // Carrega os bytes do áudio PCM
      final pcmAudioBytes = await _loadPcmAudioBytes(pcmAudioPath);
      _logService.info('QuickVideoEncoderService', 'Áudio PCM carregado: ${pcmAudioBytes.length} bytes');
      
      // Já temos a duração do áudio calculada anteriormente
      _logService.info('QuickVideoEncoderService', 'Duração do áudio: $audioDuration segundos');
      // Calcula o número total de frames com base na duração do áudio e FPS
      final int totalFrames = (audioDuration * fps).round();
      _logService.info('QuickVideoEncoderService', 'Total de frames a serem gerados: $totalFrames');

      // Prepara as imagens
      final List<ui.Image> images = await _loadImages(imageSequence);
      _logService.info('QuickVideoEncoderService', 'Imagens carregadas: ${images.length} imagens');

      // Preparamos o processamento de frames
      _logService.info('QuickVideoEncoderService', 'Iniciando processamento de frames...');
      for (int i = 0; i < totalFrames; i++) {
        try {
          final progress = i / totalFrames;
          
          // Calcula o tempo atual em segundos
          final double currentTimeInSeconds = i / fps;
          
          // Encontra a imagem correspondente ao tempo atual
          final ImageSequenceItem currentImage = _findImageForTime(imageSequence, currentTimeInSeconds);
          
          // Encontra o índice da imagem na lista de imagens carregadas
          final int imageIndex = imageSequence.indexOf(currentImage);
          
          // Gera o frame de vídeo a partir da imagem
          final Uint8List? frameData = await _generateVideoFrame(images[imageIndex], width, height);
          
          if (frameData != null) {
            // Adiciona o frame de vídeo ao encoder
            await FlutterQuickVideoEncoder.appendVideoFrame(frameData);
            if (i % 10 == 0) { // Reduzir quantidade de logs
              _logService.debug('QuickVideoEncoderService', 'Frame de vídeo $i adicionado: ${frameData.length} bytes');
            }
            
            // Processa o áudio para este frame
            await _processAudioForFrame(i, totalFrames, pcmAudioBytes, sampleRate, audioChannels, fps.toDouble());
            
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
      
      // Finaliza a codificação do vídeo
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
    } catch (e, stackTrace) {
      _logService.error('QuickVideoEncoderService', 'Erro ao gerar vídeo: $e');
      _logService.exception('QuickVideoEncoderService', e, stackTrace);
      rethrow;
    }
  }

  /// Encontra a imagem correspondente ao tempo atual
  ImageSequenceItem _findImageForTime(List<ImageSequenceItem> imageSequence, double currentTimeInSeconds) {
    // Por padrão, usa a primeira imagem
    ImageSequenceItem currentImage = imageSequence.first;
    
    // Procura a imagem que deve ser exibida no tempo atual
    for (int j = 0; j < imageSequence.length; j++) {
      // Se encontrou uma imagem que começa depois do tempo atual, usa a anterior
      if (j > 0 && imageSequence[j].startTimeInSeconds > currentTimeInSeconds) {
        currentImage = imageSequence[j - 1];
        break;
      }
      // Se é a última imagem ou se o tempo atual está entre esta imagem e a próxima
      else if (j == imageSequence.length - 1 || 
          (imageSequence[j].startTimeInSeconds <= currentTimeInSeconds && 
           imageSequence[j + 1].startTimeInSeconds > currentTimeInSeconds)) {
        currentImage = imageSequence[j];
        break;
      }
    }
    
    return currentImage;
  }

  /// Carrega as imagens da sequência como objetos ui.Image
  Future<List<ui.Image>> _loadImages(List<ImageSequenceItem> imageSequence) async {
    List<ui.Image> images = [];
    
    for (var item in imageSequence) {
      final File imageFile = File(item.imagePath);
      if (!imageFile.existsSync()) {
        throw Exception('Imagem não encontrada: ${item.imagePath}');
      }
      
      final Uint8List bytes = await imageFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      
      images.add(frameInfo.image);
    }
    
    return images;
  }

  /// Gera um frame de vídeo a partir de uma imagem
  Future<Uint8List?> _generateVideoFrame(ui.Image image, int width, int height) async {
    try {
      // Cria um recorder para desenhar a imagem
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Paint paint = Paint();
    
    // Calcula a escala para ajustar a imagem ao tamanho do vídeo
    final double scaleX = width / image.width;
    final double scaleY = height / image.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;
    
    // Calcula o tamanho da imagem escalada
    final double scaledWidth = image.width * scale;
    final double scaledHeight = image.height * scale;
    
    // Calcula a posição para centralizar a imagem
    final double offsetX = (width - scaledWidth) / 2;
    final double offsetY = (height - scaledHeight) / 2;
    
    // Desenha um fundo preto
    paint.color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paint);
    
    // Desenha a imagem centralizada e escalada
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight),
      paint,
    );
    
    // Converte o canvas para uma imagem
    final ui.Picture picture = recorder.endRecording();
    final ui.Image renderedImage = await picture.toImage(width, height);
    
    // Converte a imagem para bytes RGBA
    final ByteData? byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    final Uint8List? result = byteData?.buffer.asUint8List();
    
    // Verifica se os dados da imagem foram gerados corretamente
    if (result == null || result.isEmpty) {
      _logService.warning('QuickVideoEncoderService', 'Falha ao gerar dados de imagem RGBA');
    }
    
    return result;
    } catch (e) {
      _logService.error('QuickVideoEncoderService', 'Erro ao gerar frame de vídeo: $e');
      return null;
    }
  }

  /// Obtém a duração do áudio em segundos
  Future<double> _getAudioDuration(String audioPath) async {
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
      _logService.error('QuickVideoEncoderService', 'Erro ao obter duração do áudio: $e');
      rethrow;
    }
  }

  /// Converte um arquivo de áudio para o formato PCM
  /// O flutter_quick_video_encoder espera dados PCM brutos
  Future<String> _convertAudioToPcm(String audioPath, int sampleRate, int channels) async {
    try {
      // Obtém um diretório temporário para salvar o arquivo PCM
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.pcm';
      
      // Comando FFmpeg para converter o áudio para PCM 16-bit com a taxa de amostragem e canais especificados
      // Usamos exatamente os mesmos parâmetros que serão usados pelo encoder
      final command = '-i "$audioPath" -f s16le -acodec pcm_s16le -ar $sampleRate -ac $channels "$outputPath"';
      
      _logService.info('QuickVideoEncoderService', 'Convertendo áudio para PCM: $command');
      _logService.info('QuickVideoEncoderService', 'Parâmetros: sampleRate=$sampleRate, channels=$channels');
      
      // Executa o comando FFmpeg
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      
      // Verifica se a conversão foi bem-sucedida
      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(outputPath);
        final fileSize = await file.length();
        _logService.info('QuickVideoEncoderService', 'Áudio convertido com sucesso para PCM: $outputPath (${fileSize} bytes)');
        return outputPath;
      } else {
        final logs = await session.getLogs();
        throw Exception('Erro ao converter áudio para PCM: ${logs.join('\n')}');
      }
    } catch (e, stackTrace) {
      _logService.error('QuickVideoEncoderService', 'Erro ao converter áudio para PCM: $e');
      _logService.exception('QuickVideoEncoderService', e, stackTrace);
      rethrow;
    }
  }
  
  /// Carrega os bytes de áudio PCM de um arquivo
  Future<Uint8List> _loadPcmAudioBytes(String pcmFilePath) async {
    try {
      final file = File(pcmFilePath);
      if (!file.existsSync()) {
        throw Exception('Arquivo PCM não encontrado: $pcmFilePath');
      }
      
      final bytes = await file.readAsBytes();
      _logService.info('QuickVideoEncoderService', 'Arquivo PCM carregado: ${bytes.length} bytes');
      return bytes;
    } catch (e, stackTrace) {
      _logService.error('QuickVideoEncoderService', 'Erro ao carregar arquivo PCM: $e');
      _logService.exception('QuickVideoEncoderService', e, stackTrace);
      rethrow;
    }
  }
  
  /// Processa o áudio para um frame específico
  Future<void> _processAudioForFrame(int frameIndex, int totalFrames, Uint8List pcmAudioBytes, int sampleRate, int audioChannels, double fps) async {
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
      
      // Adiciona o frame de áudio ao encoder
      await FlutterQuickVideoEncoder.appendAudioFrame(audioFrame);
      
      if (frameIndex % 10 == 0) { // Reduzir a quantidade de logs
        _logService.debug('QuickVideoEncoderService', 'Frame de áudio $frameIndex adicionado: ${audioFrame.length} bytes');
      }
    } catch (e, stackTrace) {
      _logService.error('QuickVideoEncoderService', 'Erro ao processar áudio para o frame $frameIndex: $e');
      _logService.exception('QuickVideoEncoderService', e, stackTrace);
      // Não lança a exceção para permitir que o processo continue mesmo com erros de áudio
    }
  }
}

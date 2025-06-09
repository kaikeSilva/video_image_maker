import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart'; // Usado para gerar nomes de arquivos únicos
// import 'package:disk_space/disk_space.dart';  // Removido para resolver problema de namespace
import '../models/timeline_item.dart';
import 'ffmpeg_service.dart';
import 'log_service.dart';
import 'storage_service.dart';
import 'package:flutter/material.dart';

/// Classe para configuração da qualidade do vídeo
class VideoQualityConfig {
  final String resolution; // Formato: '1280x720', '1920x1080', etc.
  final String videoBitrate;
  final String audioBitrate;
  final String name;
  final String frameRate;
  final String preset; 
  
  const VideoQualityConfig({
    required this.resolution,
    required this.videoBitrate,
    required this.audioBitrate,
    required this.name,
    required this.frameRate,
    required this.preset,
  });
  
  // Configurações predefinidas
  static const VideoQualityConfig low = VideoQualityConfig(
    resolution: '854x480',
    videoBitrate: '1M',
    audioBitrate: '96k',
    name: 'Baixa (480p)',
    frameRate: '24',
    preset: 'faster',
  );
  
  static const VideoQualityConfig medium = VideoQualityConfig(
    resolution: '1280x720',
    videoBitrate: '2.5M',
    audioBitrate: '128k',
    name: 'Média (720p)',
    frameRate: '30',
    preset: 'medium',
  );
  
  static const VideoQualityConfig high = VideoQualityConfig(
    resolution: '1920x1080',
    videoBitrate: '5M',
    audioBitrate: '192k',
    name: 'Alta (1080p)',
    frameRate: '30',
    preset: 'medium',
  );
  
  // Converte a resolução para largura e altura
  List<int> get dimensions {
    final parts = resolution.split('x');
    return [int.parse(parts[0]), int.parse(parts[1])];
  }
  
  // Converte para parâmetros do FFmpeg
  Map<String, String> toFFmpegParams() {
    return {
      'videoBitrate': videoBitrate,
      'audioBitrate': audioBitrate,
      'frameRate': frameRate,
      'preset': preset,
    };
  }
}

/// Classe para monitorar o progresso da geração de vídeo
class VideoGenerationProgress {
  final double progress; // 0.0 a 1.0
  final String currentStep;
  final bool isCompleted;
  final bool hasError;
  final String? errorMessage;
  
  const VideoGenerationProgress({
    required this.progress,
    required this.currentStep,
    this.isCompleted = false,
    this.hasError = false,
    this.errorMessage,
  });
  
  // Construtor para progresso inicial
  VideoGenerationProgress.initial() : 
    progress = 0.0,
    currentStep = 'Inicializando',
    isCompleted = false,
    hasError = false,
    errorMessage = null;
    
  // Construtor para erro
  VideoGenerationProgress.error(String message) :
    progress = 0.0,
    currentStep = 'Erro',
    isCompleted = false,
    hasError = true,
    errorMessage = message;
    
  // Construtor para conclusão
  VideoGenerationProgress.completed() :
    progress = 1.0,
    currentStep = 'Concluído',
    isCompleted = true,
    hasError = false,
    errorMessage = null;
}

/// Serviço principal para geração de vídeo
class VideoGeneratorService {
  // Serviços
  late final FFmpegService _ffmpegService;
  late final LogService _logService;
  late final StorageService _storageService;
  bool _isCancelled = false;
  // Armazena a duração do áudio atual para cálculos de progresso
  Duration _audioDuration = const Duration();
  
  // Singleton pattern
  static final VideoGeneratorService _instance = VideoGeneratorService._internal();
  factory VideoGeneratorService() => _instance;
  VideoGeneratorService._internal() {
    _ffmpegService = FFmpegService();
    _logService = LogService();
    _storageService = StorageService();
    _initialize();
  }
  
  // Inicializa os serviços necessários
  Future<void> _initialize() async {
    try {
      await _logService.initialize();
      _logService.info('VideoGeneratorService', 'Inicializando serviço de geração de vídeo');
      await _ffmpegService.initialize();
      _logService.info('VideoGeneratorService', 'Serviço de geração de vídeo inicializado com sucesso');
    } catch (e, stackTrace) {
      _logService.exception('VideoGeneratorService', 'Erro ao inicializar serviço de geração de vídeo', stackTrace);
    }
  }
  
  /// Cancela o processo atual de geração de vídeo
  Future<bool> cancelGeneration() async {
    _isCancelled = true;
    return await _ffmpegService.cancelExecution();
  }
  
  /// Verifica se há espaço suficiente para gerar o vídeo
  /// Estima o tamanho do vídeo com base na duração do áudio e na qualidade selecionada
  Future<bool> _checkAvailableSpace(String audioPath, VideoQualityConfig quality) async {
    try {
      // Estima o tamanho do vídeo com base na duração do áudio e na qualidade
      final audioDuration = await _getAudioDuration(audioPath);
      
      // Estimativa básica: 1 minuto de vídeo HD = ~100MB
      // Ajusta com base na qualidade
      double sizeFactor = 1.0;
      if (quality == VideoQualityConfig.low) {
        sizeFactor = 0.5;
      } else if (quality == VideoQualityConfig.high) {
        sizeFactor = 2.0;
      } else if (quality.name == 'Ultra HD') { // Verifica pelo nome em vez do getter
        sizeFactor = 4.0;
      }
      
      final durationMinutes = audioDuration / 60000; // Converte para minutos
      final estimatedSizeBytes = (durationMinutes * 100 * 1024 * 1024 * sizeFactor).round();
      
      _logService.info('VideoGeneratorService', 'Estimativa de tamanho do vídeo: ${(estimatedSizeBytes / (1024 * 1024)).round()}MB');
      
      // Verifica se há espaço suficiente
      return await _storageService.hasEnoughSpace(estimatedSizeBytes);
    } catch (e, stackTrace) {
      _logService.exception('VideoGeneratorService', 'Erro ao verificar espaço disponível', stackTrace);
      // Em caso de erro, assume que há espaço suficiente para não bloquear o usuário
      return true;
    }
  }
  
  /// Verifica se há espaço suficiente no dispositivo
  Future<bool> checkDiskSpace(String audioPath, int estimatedSizeMB) async {
    try {
      _logService.info('VideoGeneratorService', 'Verificação de espaço: ${estimatedSizeMB}MB necessário');
      
      // Simplificado: assume que há espaço suficiente
      // O sistema operacional irá notificar se não houver espaço durante a gravação
      return true;
    } catch (e, stackTrace) {
      _logService.exception('VideoGeneratorService', 'Erro ao verificar espaço em disco', stackTrace);
      return true;
    }
  }
  
  /// Salva o vídeo gerado na galeria e/ou pasta de downloads
  /// Retorna o caminho do vídeo salvo ou null em caso de erro
  Future<String?> saveVideoLocally(String videoPath, {bool saveToGallery = true, bool saveToDownloads = true}) async {
    String? savedPath;
    try {
      _logService.info('VideoGeneratorService', 'Salvando vídeo localmente: $videoPath');
      
      if (saveToGallery) {
        savedPath = await _storageService.saveVideoToGallery(videoPath);
        if (savedPath != null) {
          _logService.info('VideoGeneratorService', 'Vídeo salvo na galeria: $savedPath');
        } else {
          _logService.warning('VideoGeneratorService', 'Não foi possível salvar o vídeo na galeria');
        }
      }
      
      if (saveToDownloads) {
        savedPath = await _storageService.saveVideoToDownloads(videoPath);
        if (savedPath != null) {
          _logService.info('VideoGeneratorService', 'Vídeo salvo na pasta de downloads: $savedPath');
        } else {
          _logService.warning('VideoGeneratorService', 'Não foi possível salvar o vídeo na pasta de downloads');
        }
      }
      
      return savedPath;
    } catch (e, stackTrace) {
      _logService.exception('VideoGeneratorService', 'Erro ao salvar vídeo localmente', stackTrace);
      return null;
    }
  }
  
  /// Combina áudio MP3 com imagens para gerar um vídeo
  /// 
  /// [audioPath] - Caminho do arquivo de áudio MP3
  /// [images] - Lista de imagens com timestamps
  /// [outputPath] - Caminho para salvar o vídeo gerado
  /// [quality] - Configuração de qualidade do vídeo
  /// [progressCallback] - Callback para atualizar o progresso da geração
  Future<String?> generateVideo({
    required String audioPath,
    required List<TimelineItem> images,
    String? outputPath,
    VideoQualityConfig quality = VideoQualityConfig.medium,
    Function(VideoGenerationProgress)? progressCallback,
    bool saveToGallery = true,
    bool saveToDownloads = true,
  }) async {
    // Reinicia o estado de cancelamento
    _isCancelled = false;
    
    // Verifica se há imagens para processar
    if (images.isEmpty) {
      progressCallback?.call(VideoGenerationProgress.error('Nenhuma imagem fornecida'));
      return null;
    }
    
    // Verifica se há espaço suficiente no dispositivo
    progressCallback?.call(VideoGenerationProgress(
      progress: 0.05,
      currentStep: 'Verificando espaço disponível...',
    ));
    
    final bool hasEnoughSpace = await _checkAvailableSpace(audioPath, quality);
    if (!hasEnoughSpace) {
      progressCallback?.call(VideoGenerationProgress.error(
        'Espaço insuficiente no dispositivo para gerar o vídeo'
      ));
      return null;
    }
    
    try {
      // Notifica início do processo
      progressCallback?.call(VideoGenerationProgress(
        progress: 0.0,
        currentStep: 'Verificando disponibilidade do FFmpeg',
      ));
      
      // Verifica se o FFmpeg está disponível
      if (!await _ffmpegService.checkAvailability()) {
        final error = 'FFmpeg não está disponível para gerar o vídeo';
        _logService.error('VideoGeneratorService', error);
        progressCallback?.call(VideoGenerationProgress.error(error));
        return null;
      }
      
      // Verifica se há áudio e imagens
      if (audioPath.isEmpty) {
        final error = 'Nenhum arquivo de áudio selecionado';
        _logService.error('VideoGeneratorService', error);
        progressCallback?.call(VideoGenerationProgress.error(error));
        return null;
      }
      
      if (images.isEmpty) {
        final error = 'Nenhuma imagem adicionada ao projeto';
        _logService.error('VideoGeneratorService', error);
        progressCallback?.call(VideoGenerationProgress.error(error));
        return null;
      }
      
      // Notifica preparação das imagens
      progressCallback?.call(VideoGenerationProgress(
        progress: 0.1,
        currentStep: 'Preparando sequência de imagens',
      ));
      
      // Prepara a sequência de imagens para o FFmpeg
      final List<Map<String, dynamic>> imageSequence = [];
      final int audioDurationMs = await _getAudioDuration(audioPath);
      
      // Ordena as imagens por timestamp
      final sortedImages = List<TimelineItem>.from(images);
      sortedImages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      for (int i = 0; i < sortedImages.length; i++) {
        final TimelineItem item = sortedImages[i];
        final int nextTimestamp = i < sortedImages.length - 1 
            ? sortedImages[i + 1].timestamp 
            : audioDurationMs;
        
        // Calcula a duração de exibição desta imagem
        final int durationMs = nextTimestamp - item.timestamp;
        
        imageSequence.add({
          'imagePath': item.imagePath,
          'timestamp': item.timestamp,
          'duration': durationMs,
        });
      }
      
      // Determina o caminho de saída do vídeo se não foi fornecido
      String finalOutputPath = outputPath ?? await _getDefaultOutputPath();
      
      // Notifica configuração do FFmpeg
      progressCallback?.call(VideoGenerationProgress(
        progress: 0.2,
        currentStep: 'Configurando parâmetros de codificação',
      ));
      
      // Extrai dimensões da configuração de qualidade
      final dimensions = quality.dimensions;
      
      // Configura parâmetros de codificação
      final Map<String, String> customParams = quality.toFFmpegParams();
      
      // Adiciona resolução aos parâmetros
      customParams['scale'] = '${dimensions[0]}:${dimensions[1]}';
      
      // Verifica se foi cancelado
      if (_isCancelled) {
        progressCallback?.call(VideoGenerationProgress(
          progress: 0.0,
          currentStep: 'Processo cancelado',
          hasError: true,
          errorMessage: 'Geração de vídeo cancelada pelo usuário',
        ));
        return null;
      }
      
      // Notifica progresso: Obtendo duração do áudio
      progressCallback?.call(VideoGenerationProgress(
        progress: 0.1,
        currentStep: 'Obtendo duração do áudio',
      ));
      
      // Configura callback para monitorar o progresso
      _ffmpegService.setProgressCallback((statistics) {
        // Verifica se foi cancelado
        if (_isCancelled) return;
        
        final time = statistics.getTime();
        if (time > 0 && audioDurationMs > 0) {
          final progress = time / audioDurationMs;
          progressCallback?.call(VideoGenerationProgress(
            progress: 0.3 + (progress * 0.6), // 30% a 90%
            currentStep: 'Gerando vídeo: ${(progress * 100).toStringAsFixed(0)}%',
          ));
        }
      });
      
      // Gera o vídeo
      // Converter TimelineItems para o formato esperado pelo FFmpegService
      final ffmpegImageSequence = images.map((item) => {
        'imagePath': item.imagePath,  // Corrigido: usando 'imagePath' em vez de 'path'
        'timestamp': item.timestamp,
        'duration': 0,  // Adicionando duração padrão
      }).toList();
      
      final success = await _ffmpegService.generateVideo(
        inputAudioPath: audioPath,
        imageSequence: ffmpegImageSequence,
        outputPath: finalOutputPath,
        customParams: customParams,
      );
      
      // Verifica se o processo foi cancelado ou falhou
      if (_isCancelled) {
        progressCallback?.call(VideoGenerationProgress(
          progress: 0.0,
          currentStep: 'Processo cancelado',
          hasError: true,
          errorMessage: 'Geração de vídeo cancelada pelo usuário',
        ));
        return null;
      } else if (!success) {
        progressCallback?.call(VideoGenerationProgress.error('Falha ao gerar o vídeo'));
        return null;
      }
      
      // Verifica se deve salvar o vídeo localmente
      if (saveToGallery || saveToDownloads) {
        progressCallback?.call(VideoGenerationProgress(
          progress: 0.95,
          currentStep: 'Salvando vídeo na galeria/downloads...',
        ));
        
        // Salva o vídeo localmente
        final String? savedPath = await saveVideoLocally(
          finalOutputPath,
          saveToGallery: saveToGallery,
          saveToDownloads: saveToDownloads,
        );
        
        // Se o salvamento falhou, notifica o erro mas retorna o caminho original
        if (savedPath == null) {
          debugPrint('Aviso: Falha ao salvar vídeo localmente, mas o arquivo foi gerado com sucesso');
        }
      }
      
      // Notifica conclusão
      progressCallback?.call(VideoGenerationProgress.completed());
      return finalOutputPath;
    } catch (e) {
      progressCallback?.call(VideoGenerationProgress.error('Erro: $e'));
      return null;
    }
  }
  
  /// Obtém a duração do arquivo de áudio em milissegundos
  Future<int> _getAudioDuration(String audioPath) async {
    try {
      _logService.info('VideoGeneratorService', 'Obtendo duração do áudio: $audioPath');
      final duration = await _ffmpegService.getAudioDuration(audioPath);
      final durationMs = duration.inMilliseconds;
      _logService.info('VideoGeneratorService', 'Duração do áudio: ${durationMs}ms');
      return durationMs;
    } catch (e, stackTrace) {
      _logService.exception('VideoGeneratorService', 'Erro ao obter duração do áudio', stackTrace);
      return 0; // Retorna 0 em caso de erro
    }
  }
  
  /// Gera um caminho padrão para o arquivo de saída
  Future<String> _getDefaultOutputPath() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String outputFileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    return '${appDocDir.path}/$outputFileName';
  }
}

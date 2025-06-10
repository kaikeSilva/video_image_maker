import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';

/// Enum para as opções de qualidade de vídeo
enum VideoQuality {
  /// Alta qualidade (1080x1920, 3.5 Mbps)
  high,
  
  /// Qualidade média (720x1280, 2.0 Mbps)
  medium,
  
  /// Baixa qualidade (540x960, 1.2 Mbps)
  low,
  
  /// Qualidade muito baixa (360x640, 0.8 Mbps)
  veryLow
}

/// Extensão para obter as configurações de cada qualidade de vídeo
extension VideoQualityExtension on VideoQuality {
  /// Obtém a largura do vídeo para esta qualidade
  int get width {
    switch (this) {
      case VideoQuality.high:
        return 1080;
      case VideoQuality.medium:
        return 720;
      case VideoQuality.low:
        return 540;
      case VideoQuality.veryLow:
        return 360;
    }
  }
  
  /// Obtém a altura do vídeo para esta qualidade
  int get height {
    switch (this) {
      case VideoQuality.high:
        return 1920;
      case VideoQuality.medium:
        return 1280;
      case VideoQuality.low:
        return 960;
      case VideoQuality.veryLow:
        return 640;
    }
  }
  
  /// Obtém o bitrate do vídeo para esta qualidade
  int get videoBitrate {
    switch (this) {
      case VideoQuality.high:
        return 3500000; // 3.5 Mbps
      case VideoQuality.medium:
        return 2000000; // 2.0 Mbps
      case VideoQuality.low:
        return 1200000; // 1.2 Mbps
      case VideoQuality.veryLow:
        return 800000;  // 0.8 Mbps
    }
  }
  
  /// Obtém o nome legível da qualidade
  String get displayName {
    switch (this) {
      case VideoQuality.high:
        return 'Alta (1080x1920)';
      case VideoQuality.medium:
        return 'Média (720x1280)';
      case VideoQuality.low:
        return 'Baixa (540x960)';
      case VideoQuality.veryLow:
        return 'Muito Baixa (360x640)';
    }
  }
}

/// Configurações para o codificador de vídeo
class EncoderConfig {
  /// Qualidade do vídeo
  final VideoQuality quality;
  
  /// Largura do vídeo em pixels
  final int width;
  
  /// Altura do vídeo em pixels
  final int height;
  
  /// Taxa de quadros por segundo
  final int fps;
  
  /// Taxa de bits do vídeo (bits por segundo)
  final int videoBitrate;
  
  /// Número de canais de áudio (1=mono, 2=estéreo)
  final int audioChannels;
  
  /// Taxa de bits do áudio (bits por segundo)
  final int audioBitrate;
  
  /// Taxa de amostragem do áudio (Hz)
  final int sampleRate;
  
  /// Perfil de codificação H.264
  final ProfileLevel profileLevel;
  
  /// Caminho do arquivo de saída
  final String outputPath;

  /// Construtor para as configurações do codificador
  EncoderConfig({
    required this.outputPath,
    this.quality = VideoQuality.medium,
    this.fps = 30,
    this.audioChannels = 2,
    this.audioBitrate = 128000, // 128 kbps
    this.sampleRate = 44100,
    this.profileLevel = ProfileLevel.baseline31,
  }) : width = quality.width,
       height = quality.height,
       videoBitrate = quality.videoBitrate;
       
  /// Construtor alternativo que permite especificar valores personalizados
  EncoderConfig.custom({
    required this.outputPath,
    required this.width,
    required this.height,
    required this.videoBitrate,
    this.fps = 30,
    this.audioChannels = 2,
    this.audioBitrate = 128000,
    this.sampleRate = 44100,
    this.profileLevel = ProfileLevel.baseline31,
  }) : quality = VideoQuality.high; // Valor padrão, mas não usado neste construtor

  /// Inicializa o codificador com estas configurações
  Future<void> setupEncoder() async {
    await FlutterQuickVideoEncoder.setup(
      width: width,
      height: height,
      fps: fps,
      videoBitrate: videoBitrate,
      audioChannels: audioChannels,
      audioBitrate: audioBitrate,
      sampleRate: sampleRate,
      filepath: outputPath,
      profileLevel: profileLevel,
    );
  }
}

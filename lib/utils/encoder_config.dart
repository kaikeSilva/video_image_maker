import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';

/// Enum para os formatos de vídeo
enum VideoFormat {
  /// Formato vertical para celular (9:16)
  mobile,
  
  /// Formato horizontal para desktop (16:9)
  desktop
}

/// Extensão para obter informações sobre o formato de vídeo
extension VideoFormatExtension on VideoFormat {
  /// Obtém o nome legível do formato
  String get displayName {
    switch (this) {
      case VideoFormat.mobile:
        return 'Celular (Vertical 9:16)';
      case VideoFormat.desktop:
        return 'Desktop (Horizontal 16:9)';
    }
  }
  
  /// Verifica se o formato é vertical
  bool get isVertical => this == VideoFormat.mobile;
}

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
  /// Obtém a largura base do vídeo para esta qualidade (para formato mobile)
  int get baseWidth {
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
  
  /// Obtém a altura base do vídeo para esta qualidade (para formato mobile)
  int get baseHeight {
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
  
  /// Obtém a largura do vídeo para esta qualidade e formato
  int getWidth(VideoFormat format) {
    if (format == VideoFormat.mobile) {
      return baseWidth;
    } else {
      // Para desktop (16:9), usamos a altura como base e calculamos a largura
      // Para alta qualidade: 1920x1080, média: 1280x720, baixa: 960x540, muito baixa: 640x360
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
  }
  
  /// Obtém a altura do vídeo para esta qualidade e formato
  int getHeight(VideoFormat format) {
    if (format == VideoFormat.mobile) {
      return baseHeight;
    } else {
      // Para desktop (16:9), definimos alturas fixas para cada qualidade
      // Para alta qualidade: 1920x1080, média: 1280x720, baixa: 960x540, muito baixa: 640x360
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
  
  /// Formato do vídeo (celular ou desktop)
  final VideoFormat format;
  
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
    this.format = VideoFormat.mobile,
    this.fps = 30,
    this.audioChannels = 2,
    this.audioBitrate = 128000, // 128 kbps
    this.sampleRate = 44100,
    this.profileLevel = ProfileLevel.baseline31,
  }) : width = format == VideoFormat.desktop 
            ? (quality == VideoQuality.high ? 1920 : quality == VideoQuality.medium ? 1280 : quality == VideoQuality.low ? 960 : 640)
            : quality.baseWidth,
       height = format == VideoFormat.desktop 
            ? (quality == VideoQuality.high ? 1080 : quality == VideoQuality.medium ? 720 : quality == VideoQuality.low ? 540 : 360)
            : quality.baseHeight,
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
  }) : quality = VideoQuality.high, // Valor padrão, mas não usado neste construtor
       format = VideoFormat.mobile; // Valor padrão, mas não usado neste construtor

  /// Inicializa o codificador com estas configurações
  Future<void> setupEncoder() async {
    // Log detalhado para verificar se as dimensões estão corretas
    print("[EncoderConfig] Configurando encoder - FORMAT: ${format == VideoFormat.desktop ? 'DESKTOP' : 'MOBILE'}");
    print("[EncoderConfig] Dimensões finais: ${width}x${height} (width x height)");
    print("[EncoderConfig] Proporção esperada: ${format == VideoFormat.desktop ? '16:9 (Horizontal)' : '9:16 (Vertical)'}");
    print("[EncoderConfig] Proporção real: ${width/height} (${width > height ? 'Horizontal' : 'Vertical'})");
    
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

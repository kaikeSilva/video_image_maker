import '../../utils/encoder_config.dart';

/// Estado da geração de vídeo para separar lógica e UI
class VideoGenerationState {
  // Status de geração
  final bool isGenerating;
  final bool isExporting;
  final bool isSharing;
  final String? outputVideoPath;
  final VideoGenerationProgress progress;
  final DateTime? generationStartTime;
  
  // Configurações de qualidade e formato
  final VideoQuality encoderQuality;
  final VideoFormat videoFormat;
  final bool saveToGallery;
  final bool saveToDownloads;
  
  // Construtor
  VideoGenerationState({
    this.isGenerating = false,
    this.isExporting = false,
    this.isSharing = false,
    this.outputVideoPath,
    this.progress = const VideoGenerationProgress.initial(),
    this.generationStartTime,
    this.encoderQuality = VideoQuality.medium,
    this.videoFormat = VideoFormat.mobile,
    this.saveToGallery = true,
    this.saveToDownloads = true,
  });
  
  // Cria uma cópia do estado com alguns campos alterados
  VideoGenerationState copyWith({
    bool? isGenerating,
    bool? isExporting,
    bool? isSharing,
    String? outputVideoPath,
    VideoGenerationProgress? progress,
    DateTime? generationStartTime,
    VideoQuality? encoderQuality,
    VideoFormat? videoFormat,
    bool? saveToGallery,
    bool? saveToDownloads,
  }) {
    return VideoGenerationState(
      isGenerating: isGenerating ?? this.isGenerating,
      isExporting: isExporting ?? this.isExporting,
      isSharing: isSharing ?? this.isSharing,
      outputVideoPath: outputVideoPath ?? this.outputVideoPath,
      progress: progress ?? this.progress,
      generationStartTime: generationStartTime ?? this.generationStartTime,
      encoderQuality: encoderQuality ?? this.encoderQuality,
      videoFormat: videoFormat ?? this.videoFormat,
      saveToGallery: saveToGallery ?? this.saveToGallery,
      saveToDownloads: saveToDownloads ?? this.saveToDownloads,
    );
  }
  
  // Factory para inicializar o estado
  factory VideoGenerationState.initial() {
    return VideoGenerationState(
      isGenerating: false,
      isExporting: false,
      isSharing: false,
      outputVideoPath: null,
      progress: const VideoGenerationProgress.initial(),
      generationStartTime: null,
      encoderQuality: VideoQuality.medium,
      videoFormat: VideoFormat.mobile,
      saveToGallery: true,
      saveToDownloads: true,
    );
  }
  
  // Verifica se o vídeo foi gerado com sucesso
  bool get isVideoGenerated => outputVideoPath != null && 
                               !isGenerating && 
                               progress.isCompleted &&
                               !progress.hasError;
                               
  // Verifica se a interface deve usar overlay
  bool get useOverlay => isGenerating && (progress.progress <= 0.05);
}

/// Modelo para o progresso da geração de vídeo
class VideoGenerationProgress {
  final double progress;
  final String currentStep;
  final bool hasError;
  final String? errorMessage;
  final bool isCompleted;
  
  const VideoGenerationProgress({
    required this.progress,
    required this.currentStep,
    this.hasError = false,
    this.errorMessage,
    this.isCompleted = false,
  });
  
  const VideoGenerationProgress.initial() 
    : progress = 0.0, 
      currentStep = 'Iniciando...', 
      hasError = false,
      errorMessage = null,
      isCompleted = false;
      
  VideoGenerationProgress copyWith({
    double? progress,
    String? currentStep,
    bool? hasError,
    String? errorMessage,
    bool? isCompleted,
  }) {
    return VideoGenerationProgress(
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
  
  factory VideoGenerationProgress.error(String message) {
    return VideoGenerationProgress(
      progress: 0.0,
      currentStep: 'Erro',
      hasError: true,
      errorMessage: message,
    );
  }
  
  factory VideoGenerationProgress.completed(String path) {
    return VideoGenerationProgress(
      progress: 1.0,
      currentStep: 'Vídeo gerado com sucesso',
      isCompleted: true,
    );
  }
}

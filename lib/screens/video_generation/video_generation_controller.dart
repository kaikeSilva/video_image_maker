import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/timeline_item.dart';
import '../../models/video_generation/video_generation_state.dart' as state_model;
import '../../providers/project_provider.dart';
import '../../services/video_generator_service.dart' as service;
import '../../services/storage_service.dart';
import '../../services/share_service.dart';
import '../../utils/encoder_config.dart';

/// Controller responsável pela lógica de geração de vídeo
class VideoGenerationController extends ChangeNotifier {
  // Serviços
  final service.VideoGeneratorService _videoGeneratorService = service.VideoGeneratorService();
  final StorageService _storageService = StorageService();
  final ShareService _shareService = ShareService();
  
  // Estado
  state_model.VideoGenerationState _state = state_model.VideoGenerationState.initial();
  state_model.VideoGenerationState get state => _state;
  
  // Getter para compatibilidade
  service.VideoQualityConfig get selectedQuality {
    switch (_state.encoderQuality) {
      case VideoQuality.high:
        return service.VideoQualityConfig.high;
      case VideoQuality.medium:
        return service.VideoQualityConfig.medium;
      case VideoQuality.low:
      case VideoQuality.veryLow:
        return service.VideoQualityConfig.low;
    }
    // Todos os casos são cobertos
  }
  
  // Setter privado para atualizar o estado e notificar a UI
  void _updateState(state_model.VideoGenerationState newState) {
    _state = newState;
    notifyListeners();
  }
  
  // Atualiza a qualidade do vídeo
  void updateQuality(VideoQuality quality) {
    _updateState(_state.copyWith(encoderQuality: quality));
  }
  
  // Atualiza o formato do vídeo
  void updateFormat(VideoFormat format) {
    _updateState(_state.copyWith(videoFormat: format));
  }
  
  // Atualiza as opções de salvar
  void updateSaveOptions({bool? saveToGallery, bool? saveToDownloads}) {
    _updateState(_state.copyWith(
      saveToGallery: saveToGallery ?? _state.saveToGallery,
      saveToDownloads: saveToDownloads ?? _state.saveToDownloads,
    ));
  }
  
  // Gera o vídeo a partir do projeto atual
  Future<void> generateVideo(ProjectProvider projectProvider) async {
    if (projectProvider.project.audioFilePath == null) return;
    
    _updateState(_state.copyWith(
      isGenerating: true,
      progress: const state_model.VideoGenerationProgress.initial(),
      generationStartTime: DateTime.now(),
      outputVideoPath: null,
    ));
    
    try {
      // Converter AudioTimelineItems para TimelineItems
      final timelineItems = projectProvider.project.timelineItems
        .map((item) => TimelineItem(
            imagePath: item.imagePath, 
            timestamp: item.timestamp.inMilliseconds
          )
        ).toList();
      
      // Adiciona log para mostrar o formato selecionado
      print('Gerando vídeo com formato: ${_state.videoFormat.displayName}');
      print('Dimensões: ${_state.encoderQuality.getWidth(_state.videoFormat)}x'
          '${_state.encoderQuality.getHeight(_state.videoFormat)}');
      
      final result = await _videoGeneratorService.generateVideo(
        audioPath: projectProvider.project.audioFilePath!,
        images: timelineItems,
        quality: selectedQuality,
        videoFormat: _state.videoFormat,
        encoderQuality: _state.encoderQuality,
        saveToGallery: _state.saveToGallery,
        saveToDownloads: _state.saveToDownloads,
        progressCallback: (progress) {
          // Converter de service.VideoGenerationProgress para state_model.VideoGenerationProgress
          final modelProgress = state_model.VideoGenerationProgress(
            progress: progress.progress,
            currentStep: progress.currentStep,
            isCompleted: progress.isCompleted,
            hasError: progress.hasError,
            errorMessage: progress.errorMessage,
          );
          _updateState(_state.copyWith(progress: modelProgress));
        },
      );
      
      _updateState(_state.copyWith(
        isGenerating: false,
        outputVideoPath: result,
      ));
    } catch (e) {
      _updateState(_state.copyWith(
        isGenerating: false,
        progress: state_model.VideoGenerationProgress.error('Erro ao gerar vídeo: $e'),
      ));
    }
  }
  
  // Reinicia o processo de geração
  void resetGeneration() {
    _updateState(_state.copyWith(
      isGenerating: false,
      progress: const state_model.VideoGenerationProgress.initial(),
      outputVideoPath: null,
    ));
  }
  
  // Cancela o processo de geração de vídeo
  Future<void> cancelGeneration() async {
    await _videoGeneratorService.cancelGeneration();
    _updateState(_state.copyWith(
      isGenerating: false,
      progress: state_model.VideoGenerationProgress(
        progress: 0.0,
        currentStep: 'Cancelado pelo usuário',
        hasError: true,
        errorMessage: 'O processo de geração foi cancelado',
      ),
      outputVideoPath: null,
    ));
  }
  
  // Calcula o tempo estimado restante com base no progresso atual
  String getEstimatedTimeRemaining() {
    final progress = _state.progress.progress;
    final generationStartTime = _state.generationStartTime;
    
    if (progress <= 0 || generationStartTime == null) return 'Calculando...';
    
    // Estima o tempo total com base no tempo decorrido e no progresso atual
    final DateTime now = DateTime.now();
    final Duration elapsed = now.difference(generationStartTime);
    final double progressPercent = progress * 100;
    
    // Evita divisão por zero
    if (progressPercent <= 0) return 'Calculando...';
    
    // Calcula o tempo total estimado
    final double totalSeconds = elapsed.inSeconds / (progressPercent / 100);
    final int remainingSeconds = (totalSeconds - elapsed.inSeconds).round();
    
    if (remainingSeconds < 0) return 'Finalizando...';
    
    // Formata o tempo restante
    if (remainingSeconds < 60) {
      return '$remainingSeconds segundos restantes';
    } else if (remainingSeconds < 3600) {
      final int minutes = remainingSeconds ~/ 60;
      return '$minutes minutos restantes';
    } else {
      final int hours = remainingSeconds ~/ 3600;
      final int minutes = (remainingSeconds % 3600) ~/ 60;
      return '$hours h $minutes min restantes';
    }
  }
  
  // Abre o vídeo gerado no player padrão do dispositivo usando share_plus
  Future<ShareResult> openVideo(String path) async {
    final result = await Share.shareXFiles(
      [XFile(path)],
      text: 'Vídeo gerado pelo Video Maker',
      subject: 'Meu Vídeo',
    );
    
    return result;
  }
  
  // Salva o vídeo novamente (caso o usuário queira salvar em outro local)
  Future<void> saveVideoAgain(BuildContext context) async {
    if (_state.outputVideoPath == null) return;
    
    final File videoFile = File(_state.outputVideoPath!);
    if (!await videoFile.exists()) {
      return;
    }
    
    _updateState(_state.copyWith(
      progress: state_model.VideoGenerationProgress(
        progress: 0.95,
        currentStep: 'Salvando vídeo...',
      ),
    ));
    
    try {
      String? savedPath;
      
      if (_state.saveToGallery) {
        savedPath = await _storageService.saveVideoToGallery(_state.outputVideoPath!);
      }
      
      if (_state.saveToDownloads) {
        savedPath = await _storageService.saveVideoToDownloads(_state.outputVideoPath!);
      }
      
      _updateState(_state.copyWith(
        progress: state_model.VideoGenerationProgress(
          progress: 1.0,
          currentStep: 'Vídeo salvo com sucesso',
          isCompleted: true,
        ),
      ));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vídeo salvo em: $savedPath')),
        );
      }
    } catch (e) {
      _updateState(_state.copyWith(
        progress: state_model.VideoGenerationProgress.error('Erro ao salvar vídeo: $e'),
      ));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar vídeo: $e')),
        );
      }
    }
  }
  
  // Compartilha o vídeo
  Future<void> shareVideo(BuildContext context) async {
    if (_state.outputVideoPath == null) return;
    
    _updateState(_state.copyWith(isSharing: true));
    
    try {
      final result = await _shareService.shareVideo(_state.outputVideoPath!);
      
      if (result != true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível compartilhar o vídeo')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar vídeo: $e')),
        );
      }
    } finally {
      _updateState(_state.copyWith(isSharing: false));
    }
  }
  
  // Extrai o nome do arquivo de áudio do caminho
  String getAudioFileName(String? path) {
    if (path == null) return 'Não selecionado';
    return path.split('/').last;
  }
  
  // Formata a duração em segundos para um formato legível
  String formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    
    final int totalSeconds = duration.inSeconds;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

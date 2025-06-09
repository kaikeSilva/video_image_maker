import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/project_provider.dart';
import '../services/video_generator_service.dart';
import '../services/storage_service.dart';
import '../services/share_service.dart';
import '../models/timeline_item.dart';
import '../routes.dart';
import '../widgets/progress_indicator_widget.dart';
import '../widgets/loading_overlay.dart';

class VideoGenerationScreen extends StatefulWidget {
  const VideoGenerationScreen({Key? key}) : super(key: key);

  @override
  State<VideoGenerationScreen> createState() => _VideoGenerationScreenState();
}

class _VideoGenerationScreenState extends State<VideoGenerationScreen> {
  final VideoGeneratorService _videoGeneratorService = VideoGeneratorService();
  final StorageService _storageService = StorageService();
  final ShareService _shareService = ShareService();
  VideoQualityConfig _selectedQuality = VideoQualityConfig.medium;
  bool _isGenerating = false;
  String? _outputVideoPath;
  VideoGenerationProgress _progress = VideoGenerationProgress.initial();
  DateTime? _generationStartTime;
  bool _saveToGallery = true;
  bool _saveToDownloads = true;
  bool _isExporting = false;
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final projectProvider = Provider.of<ProjectProvider>(context);
    
    return LoadingOverlay(
      isLoading: _isGenerating,
      message: 'Gerando vídeo... ${(_progress.progress * 100).toStringAsFixed(0)}%',
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Exportar Vídeo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isGenerating) {
              // Confirmar cancelamento se estiver gerando
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cancelar Exportação?'),
                  content: const Text('O processo de geração será interrompido.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Continuar Gerando'),
                    ),
                    TextButton(
                      onPressed: () {
                        _cancelGeneration();
                        Navigator.pop(context); // Fecha dialog
                        Navigator.pop(context); // Volta para tela anterior
                      },
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context); // Volta para Preview ou Editor
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: const FlowProgressIndicator(currentStep: 4),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Configuração de qualidade
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configurações de Qualidade',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // Seleção de qualidade
                    DropdownButton<VideoQualityConfig>(
                      value: _selectedQuality,
                      onChanged: (newValue) {
                        setState(() {
                          _selectedQuality = newValue!;
                        });
                      },
                      items: [
                        DropdownMenuItem(
                          value: VideoQualityConfig.low,
                          child: const Text('Baixa (480p)'),
                        ),
                        DropdownMenuItem(
                          value: VideoQualityConfig.medium,
                          child: const Text('Média (720p)'),
                        ),
                        DropdownMenuItem(
                          value: VideoQualityConfig.high,
                          child: const Text('Alta (1080p)'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Detalhes da configuração selecionada
                    Text('Resolução: ${_selectedQuality.resolution}'),
                    Text('Bitrate de Vídeo: ${_selectedQuality.videoBitrate}'),
                    Text('Bitrate de Áudio: ${_selectedQuality.audioBitrate}'),
                    Text('Taxa de Quadros: ${_selectedQuality.frameRate} fps'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Informações do projeto
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informações do Projeto',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Áudio: ${_getAudioFileName(projectProvider.project.audioFilePath)}'),
                    Text('Imagens: ${projectProvider.project.timelineItems.length}'),
                    Text('Duração Estimada: ${_formatDuration(projectProvider.project.audioDuration)}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Barra de progresso
            if (_isGenerating || _progress.isCompleted || _progress.hasError)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Status: ${_progress.currentStep}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _progress.hasError ? Colors.red : null,
                              ),
                            ),
                          ),
                          // Botão de cancelamento (apenas durante geração)
                          if (_isGenerating)
                            TextButton.icon(
                              onPressed: _cancelGeneration,
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              label: const Text('Cancelar', style: TextStyle(color: Colors.red)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _progress.progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _progress.hasError ? Colors.red : Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Tempo estimado e porcentagem
                      if (_isGenerating && _progress.progress > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${(_progress.progress * 100).toStringAsFixed(1)}% concluído'),
                            Text(_getEstimatedTimeRemaining(_progress.progress)),
                          ],
                        ),
                      if (_progress.hasError && _progress.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _progress.errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            
            const Spacer(),
            
            // Botão para gerar vídeo
            if (!_isGenerating && !_progress.isCompleted)
              ElevatedButton(
                onPressed: projectProvider.project.timelineItems.isNotEmpty && projectProvider.project.audioFilePath != null
                    ? () => _generateVideo(projectProvider)
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('GERAR VÍDEO', style: TextStyle(fontSize: 16)),
              ),
            
            // Botão para visualizar o vídeo gerado
            if (_outputVideoPath != null && _progress.isCompleted)
              Column(
                children: [
                  // Botão principal de visualização
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('REPRODUZIR VÍDEO'),
                    onPressed: () => _openVideo(_outputVideoPath!),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Ações secundárias
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.share),
                          label: const Text('Compartilhar'),
                          onPressed: _shareVideo,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Novo Projeto'),
                          onPressed: () {
                            Navigator.pushNamedAndRemoveUntil(
                              context, 
                              Routes.home, 
                              (route) => false,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
  }

  // Gera o vídeo a partir do projeto atual
  Future<void> _generateVideo(ProjectProvider projectProvider) async {
    if (projectProvider.project.audioFilePath == null) return;
    
    setState(() {
      _isGenerating = true;
      _progress = VideoGenerationProgress.initial();
      _generationStartTime = DateTime.now(); // Inicializa o tempo de início da geração
    });
    
    try {
      // Converter AudioTimelineItems para TimelineItems
      final timelineItems = projectProvider.project.timelineItems.map((item) => 
        TimelineItem(imagePath: item.imagePath, timestamp: item.timestamp.inMilliseconds)
      ).toList();
      
      final result = await _videoGeneratorService.generateVideo(
        audioPath: projectProvider.project.audioFilePath!,
        images: timelineItems,
        quality: _selectedQuality,
        saveToGallery: _saveToGallery,
        saveToDownloads: _saveToDownloads,
        progressCallback: (progress) {
          setState(() {
            _progress = progress;
          });
        },
      );
      
      setState(() {
        _isGenerating = false;
        _outputVideoPath = result;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _progress = VideoGenerationProgress.error('Erro ao gerar vídeo: $e');
      });
    }
  }
  
  // Reinicia o processo de geração
  void _resetGeneration() {
    setState(() {
      _isGenerating = false;
      _progress = VideoGenerationProgress.initial();
      _outputVideoPath = null;
    });
  }
  
  // Cancela o processo de geração de vídeo
  Future<void> _cancelGeneration() async {
    final bool cancelled = await _videoGeneratorService.cancelGeneration();
    if (cancelled) {
      setState(() {
        _isGenerating = false;
        _progress = VideoGenerationProgress(
          progress: 0.0,
          currentStep: 'Cancelado pelo usuário',
          hasError: true,
          errorMessage: 'O processo de geração foi cancelado',
        );
      });
    }
  }
  
  // Calcula o tempo estimado restante com base no progresso atual
  String _getEstimatedTimeRemaining(double progress) {
    if (progress <= 0) return 'Calculando...';
    
    // Estima o tempo total com base no tempo decorrido e no progresso atual
    final DateTime now = DateTime.now();
    final Duration elapsed = now.difference(_generationStartTime!);
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
  
  // Abre o vídeo gerado no player padrão do dispositivo
  Future<void> _openVideo(String path) async {
    final Uri uri = Uri.file(path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o vídeo')),
        );
      }
    }
  }
  
  // Salva o vídeo novamente (caso o usuário queira salvar em outro local)
  Future<void> _saveVideoAgain() async {
    if (_outputVideoPath == null) return;
    
    final File videoFile = File(_outputVideoPath!);
    if (!await videoFile.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O arquivo de vídeo não foi encontrado')),
        );
      }
      return;
    }
    
    setState(() {
      _progress = VideoGenerationProgress(
        progress: 0.95,
        currentStep: 'Salvando vídeo...',
      );
    });
    
    try {
      String? savedPath;
      
      if (_saveToGallery) {
        savedPath = await _storageService.saveVideoToGallery(_outputVideoPath!);
      }
      
      if (_saveToDownloads) {
        savedPath = await _storageService.saveVideoToDownloads(_outputVideoPath!);
      }
      
      if (savedPath != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vídeo salvo com sucesso')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível salvar o vídeo')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar vídeo: $e')),
        );
      }
    } finally {
      setState(() {
        _progress = VideoGenerationProgress.completed();
      });
    }
  }
  
  // Compartilha o vídeo gerado usando o serviço de compartilhamento nativo
  Future<void> _shareVideo() async {
    if (_outputVideoPath == null) return;
    
    final File videoFile = File(_outputVideoPath!);
    if (!await videoFile.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O arquivo de vídeo não foi encontrado')),
        );
      }
      return;
    }
    
    setState(() {
      _isSharing = true;
      _progress = VideoGenerationProgress(
        progress: 0.5,
        currentStep: 'Compartilhando vídeo...',
      );
    });
    
    try {
      final bool success = await _shareService.shareVideo(_outputVideoPath!);
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível compartilhar o vídeo')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar vídeo: $e')),
        );
      }
    } finally {
      setState(() {
        _isSharing = false;
        _progress = VideoGenerationProgress.completed();
      });
    }
  }
  
  // Mostra opções de exportação para diferentes qualidades
  void _showExportOptions() {
    if (_outputVideoPath == null) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Exportar em Qualidade Baixa (480p)'),
            leading: const Icon(Icons.video_file),
            onTap: () {
              Navigator.pop(context);
              _exportVideo(VideoQualityConfig.low);
            },
          ),
          ListTile(
            title: const Text('Exportar em Qualidade Média (720p)'),
            leading: const Icon(Icons.video_file),
            onTap: () {
              Navigator.pop(context);
              _exportVideo(VideoQualityConfig.medium);
            },
          ),
          ListTile(
            title: const Text('Exportar em Qualidade Alta (1080p)'),
            leading: const Icon(Icons.video_file),
            onTap: () {
              Navigator.pop(context);
              _exportVideo(VideoQualityConfig.high);
            },
          ),
          ListTile(
            title: const Text('Compartilhar em Qualidade Baixa (480p)'),
            leading: const Icon(Icons.share),
            onTap: () {
              Navigator.pop(context);
              _shareVideoWithQuality(VideoQualityConfig.low);
            },
          ),
          ListTile(
            title: const Text('Compartilhar em Qualidade Média (720p)'),
            leading: const Icon(Icons.share),
            onTap: () {
              Navigator.pop(context);
              _shareVideoWithQuality(VideoQualityConfig.medium);
            },
          ),
          ListTile(
            title: const Text('Compartilhar em Qualidade Alta (1080p)'),
            leading: const Icon(Icons.share),
            onTap: () {
              Navigator.pop(context);
              _shareVideoWithQuality(VideoQualityConfig.high);
            },
          ),
        ],
      ),
    );
  }
  
  // Exporta o vídeo para uma qualidade específica
  Future<void> _exportVideo(VideoQualityConfig quality) async {
    if (_outputVideoPath == null) return;
    
    setState(() {
      _isExporting = true;
      _progress = VideoGenerationProgress(
        progress: 0.0,
        currentStep: 'Exportando vídeo em qualidade ${quality.name}...',
      );
    });
    
    try {
      final String? exportedPath = await _shareService.exportVideoWithQuality(
        inputVideoPath: _outputVideoPath!,
        quality: quality,
        progressCallback: (progress) {
          setState(() {
            _progress = VideoGenerationProgress(
              progress: progress,
              currentStep: 'Exportando vídeo em qualidade ${quality.name}...',
            );
          });
        },
      );
      
      if (exportedPath != null) {
        // Salva o vídeo exportado
        final String? savedPath = await _storageService.saveVideoToDownloads(exportedPath);
        
        if (savedPath != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Vídeo exportado com sucesso em qualidade ${quality.name}')),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vídeo exportado, mas não foi possível salvá-lo')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível exportar o vídeo')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar vídeo: $e')),
        );
      }
    } finally {
      setState(() {
        _isExporting = false;
        _progress = VideoGenerationProgress.completed();
      });
    }
  }
  
  // Compartilha o vídeo com uma qualidade específica
  Future<void> _shareVideoWithQuality(VideoQualityConfig quality) async {
    if (_outputVideoPath == null) return;
    
    setState(() {
      _isSharing = true;
      _progress = VideoGenerationProgress(
        progress: 0.0,
        currentStep: 'Preparando vídeo para compartilhamento em qualidade ${quality.name}...',
      );
    });
    
    try {
      final bool success = await _shareService.shareVideoWithQuality(
        inputVideoPath: _outputVideoPath!,
        quality: quality,
        progressCallback: (progress) {
          setState(() {
            _progress = VideoGenerationProgress(
              progress: progress,
              currentStep: progress < 0.8 
                ? 'Preparando vídeo para compartilhamento em qualidade ${quality.name}...'
                : 'Compartilhando vídeo...',
            );
          });
        },
      );
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível compartilhar o vídeo')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar vídeo: $e')),
        );
      }
    } finally {
      setState(() {
        _isSharing = false;
        _progress = VideoGenerationProgress.completed();
      });
    }
  }
  
  // Formata o nome do arquivo de áudio para exibição
  String _getAudioFileName(String? path) {
    if (path == null || path.isEmpty) return 'Nenhum';
    return path.split('/').last;
  }
  
  // Formata a duração para exibição
  String _formatDuration(Duration? duration) {
    if (duration == null) return 'Desconhecida';
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    return '${duration.inHours > 0 ? '${duration.inHours}:' : ''}$minutes:$seconds';
  }
}

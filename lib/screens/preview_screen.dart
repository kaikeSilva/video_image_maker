import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../providers/audio_player_provider.dart';
import '../models/audio_timeline_item.dart';
import '../routes.dart';
import '../widgets/progress_indicator_widget.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({Key? key}) : super(key: key);

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> with SingleTickerProviderStateMixin {
  Duration _position = Duration.zero;
  AudioTimelineItem? _currentImage;
  StreamSubscription? _positionSubscription;
  bool _isPlaying = false;
  bool _showTransitionIndicator = false;
  late AnimationController _transitionController;
  
  @override
  void initState() {
    super.initState();
    
    // Controlador para animação de transição
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _transitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showTransitionIndicator = false;
        });
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Cancelar subscription anterior se existir
    _positionSubscription?.cancel();
    
    // Obter o AudioPlayerProvider
    final audioPlayerProvider = Provider.of<AudioPlayerProvider>(context);
    
    // Atualizar estado de reprodução
    setState(() {
      _isPlaying = audioPlayerProvider.isPlaying;
    });
    
    // Ouvir mudanças no estado de reprodução
    audioPlayerProvider.audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
    
    // Ouvir as mudanças na posição do áudio
    _positionSubscription = audioPlayerProvider.audioPlayer.positionStream.listen((position) {
      final oldImage = _currentImage;
      
      setState(() {
        _position = position;
        _updateCurrentImage();
        
        // Verificar se houve mudança de imagem para mostrar indicador de transição
        if (oldImage != null && _currentImage != null && oldImage != _currentImage) {
          _showTransitionIndicator = true;
          _transitionController.reset();
          _transitionController.forward();
        }
      });
    });
  }
  
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _transitionController.dispose();
    super.dispose();
  }
  
  // Atualiza a imagem atual com base na posição do áudio
  void _updateCurrentImage() {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final timelineItems = projectProvider.project.timelineItems;
    
    if (timelineItems.isEmpty) {
      setState(() {
        _currentImage = null;
      });
      return;
    }
    
    // Encontrar a imagem correspondente ao tempo atual
    AudioTimelineItem? currentItem;
    
    for (int i = 0; i < timelineItems.length; i++) {
      final item = timelineItems[i];
      final nextItemTimestamp = i < timelineItems.length - 1 
          ? timelineItems[i + 1].timestamp 
          : projectProvider.project.audioDuration ?? Duration.zero;
      
      // Verificar se a posição atual está entre este item e o próximo
      if (item.timestamp <= _position && _position < nextItemTimestamp) {
        currentItem = item;
        break;
      }
    }
    
    // Se não encontrou nenhuma imagem correspondente, usar a primeira imagem
    if (currentItem == null && timelineItems.isNotEmpty) {
      // Se a posição for menor que o primeiro item, mostrar nada
      if (_position < timelineItems.first.timestamp) {
        currentItem = null;
      } else {
        // Se a posição for maior que o último item, mostrar o último item
        currentItem = timelineItems.last;
      }
    }
    
    setState(() {
      _currentImage = currentItem;
    });
  }
  
  // Formatar duração para exibição
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
  
  // Avançar para a próxima imagem
  void _nextImage() {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final timelineItems = projectProvider.project.timelineItems;
    final audioPlayerProvider = Provider.of<AudioPlayerProvider>(context, listen: false);
    
    if (_currentImage != null && timelineItems.isNotEmpty) {
      int currentIndex = timelineItems.indexOf(_currentImage!);
      if (currentIndex < timelineItems.length - 1) {
        // Avançar para a próxima imagem
        audioPlayerProvider.seek(timelineItems[currentIndex + 1].timestamp);
      }
    }
  }
  
  // Voltar para a imagem anterior
  void _previousImage() {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final timelineItems = projectProvider.project.timelineItems;
    final audioPlayerProvider = Provider.of<AudioPlayerProvider>(context, listen: false);
    
    if (_currentImage != null && timelineItems.isNotEmpty) {
      int currentIndex = timelineItems.indexOf(_currentImage!);
      if (currentIndex > 0) {
        // Voltar para a imagem anterior
        audioPlayerProvider.seek(timelineItems[currentIndex - 1].timestamp);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = Provider.of<ProjectProvider>(context);
    final audioPlayerProvider = Provider.of<AudioPlayerProvider>(context);
    final timelineItems = projectProvider.project.timelineItems;
    final audioDuration = projectProvider.project.audioDuration;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview do Vídeo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Volta para Editor
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: const FlowProgressIndicator(currentStep: 3),
        ),
        actions: [
          // Botão de editar
          TextButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Editar'),
            onPressed: () {
              Navigator.pop(context); // Volta para Editor
            },
          ),
          // Botão de tela cheia
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: () {
              // Implementação futura para modo tela cheia
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Modo tela cheia será implementado em breve')),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, Routes.videoGeneration);
        },
        icon: const Icon(Icons.movie_creation),
        label: const Text('Exportar Vídeo'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Área de preview da imagem com indicador de transição
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _currentImage != null 
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_currentImage!.imagePath),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.broken_image, size: 64, color: Colors.white54),
                            );
                          },
                        ),
                      )
                    : const Center(
                        child: Text(
                          'Nenhuma imagem neste momento',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                ),
                // Indicador de transição
                if (_showTransitionIndicator)
                  Positioned.fill(
                    child: FadeTransition(
                      opacity: Tween<double>(begin: 0.7, end: 0.0).animate(_transitionController),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Informações sobre a imagem atual e tempo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _currentImage != null
                  ? Text(
                      'Imagem atual: ${_formatDuration(_currentImage!.timestamp)}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    )
                  : const Text(
                      'Aguardando imagem...',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                Text(
                  'Tempo: ${_formatDuration(_position)} / ${_formatDuration(audioDuration ?? Duration.zero)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Controles de navegação e reprodução
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Botão para voltar 10 segundos
                IconButton(
                  icon: const Icon(Icons.replay_10, size: 36),
                  onPressed: () {
                    final newPosition = _position - const Duration(seconds: 10);
                    audioPlayerProvider.seek(newPosition.isNegative ? Duration.zero : newPosition);
                  },
                ),
                
                // Botão para imagem anterior
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 36),
                  onPressed: timelineItems.isEmpty ? null : _previousImage,
                ),
                
                // Botão de play/pause
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 56,
                    color: Theme.of(context).primaryColor,
                  ),
                  onPressed: () {
                    if (_isPlaying) {
                      audioPlayerProvider.pause();
                    } else {
                      audioPlayerProvider.play();
                    }
                  },
                ),
                
                // Botão para próxima imagem
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 36),
                  onPressed: timelineItems.isEmpty ? null : _nextImage,
                ),
                
                // Botão para avançar 10 segundos
                IconButton(
                  icon: const Icon(Icons.forward_10, size: 36),
                  onPressed: () {
                    final newPosition = _position + const Duration(seconds: 10);
                    final maxDuration = audioDuration ?? Duration.zero;
                    audioPlayerProvider.seek(
                      newPosition > maxDuration ? maxDuration : newPosition
                    );
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Barra de progresso
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                trackHeight: 6,
              ),
              child: Slider(
                min: 0,
                max: (audioDuration?.inMilliseconds.toDouble() ?? 0) + 1,
                value: math.min(_position.inMilliseconds.toDouble(), 
                          audioDuration?.inMilliseconds.toDouble() ?? 0),
                onChanged: (value) {
                  audioPlayerProvider.seek(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
            
            // Marcadores de imagens na timeline
            if (timelineItems.isNotEmpty && audioDuration != null)
              Container(
                height: 30,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: CustomPaint(
                  painter: TimelineMarkerPainter(
                    timelineItems: timelineItems,
                    audioDuration: audioDuration,
                    currentPosition: _position,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Pintor personalizado para desenhar marcadores na timeline
class TimelineMarkerPainter extends CustomPainter {
  final List<AudioTimelineItem> timelineItems;
  final Duration? audioDuration;
  final Duration currentPosition;
  
  TimelineMarkerPainter({
    required this.timelineItems,
    required this.audioDuration,
    required this.currentPosition,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Se não tiver duração do áudio, não desenhar nada
    if (audioDuration == null) return;
    
    final paint = Paint()
      ..color = Colors.blue.shade300
      ..style = PaintingStyle.fill;
      
    final currentPositionPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;
      
    final audioDurationMs = audioDuration!.inMilliseconds;
    if (audioDurationMs <= 0) return;
      
    // Desenhar marcadores para cada imagem
    for (final item in timelineItems) {
      final position = item.timestamp.inMilliseconds / audioDurationMs;
      final x = position * size.width;
      
      // Desenhar triângulo para marcar posição da imagem
      final path = Path();
      path.moveTo(x, 0);
      path.lineTo(x - 5, 10);
      path.lineTo(x + 5, 10);
      path.close();
      
      canvas.drawPath(path, paint);
    }
    
    // Desenhar indicador de posição atual
    final currentX = currentPosition.inMilliseconds / audioDurationMs * size.width;
    canvas.drawLine(
      Offset(currentX, 0),
      Offset(currentX, size.height),
      currentPositionPaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant TimelineMarkerPainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition ||
           oldDelegate.timelineItems != timelineItems;
  }
}

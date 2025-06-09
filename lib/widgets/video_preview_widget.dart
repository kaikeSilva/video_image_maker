import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../providers/audio_player_provider.dart';
import '../models/audio_timeline_item.dart';

class VideoPreviewWidget extends StatefulWidget {
  const VideoPreviewWidget({Key? key}) : super(key: key);

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  Duration _position = Duration.zero;
  AudioTimelineItem? _currentImage;
  
  @override
  void initState() {
    super.initState();
    
    // A inicialização do listener será feita no didChangeDependencies
  }
  
  StreamSubscription? _positionSubscription;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Cancelar subscription anterior se existir
    _positionSubscription?.cancel();
    
    // Obter o AudioPlayerProvider
    final audioPlayerProvider = Provider.of<AudioPlayerProvider>(context);
    
    // Ouvir as mudanças na posição do áudio
    _positionSubscription = audioPlayerProvider.audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
        _updateCurrentImage();
      });
    });
  }
  
  @override
  void dispose() {
    // Cancelar subscription ao destruir o widget
    _positionSubscription?.cancel();
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, projectProvider, child) {
        // Verificar se há áudio carregado
        if (projectProvider.project.audioFilePath == null) {
          return const Center(
            child: Text('Carregue um áudio para visualizar o preview'),
          );
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Preview do Vídeo:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            
            // Área de preview da imagem
            Container(
              width: double.infinity,
              height: 250,
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
            
            // Informação sobre a imagem atual
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _currentImage != null
                ? Text(
                    'Imagem atual: ${_formatTimestamp(_currentImage!.timestamp)}',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  )
                : const Text(
                    'Aguardando imagem...',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
            ),
          ],
        );
      },
    );
  }
  
  String _formatTimestamp(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}

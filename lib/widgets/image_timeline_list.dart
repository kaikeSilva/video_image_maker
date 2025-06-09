import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../models/audio_timeline_item.dart';

class ImageTimelineList extends StatefulWidget {
  const ImageTimelineList({Key? key}) : super(key: key);

  @override
  State<ImageTimelineList> createState() => _ImageTimelineListState();
}

class _ImageTimelineListState extends State<ImageTimelineList> {
  // Controlador para o scroll horizontal da timeline
  final ScrollController _scrollController = ScrollController();
  
  // Estado para controlar a posição de inserção durante o arrasto
  Duration? _dragInsertPosition;
  bool _isDraggingOver = false;
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, projectProvider, child) {
        final timelineItems = projectProvider.project.timelineItems;
        final audioDuration = projectProvider.project.audioDuration;
        
        if (audioDuration == null) {
          return const Center(
            child: Text('Selecione um áudio para criar a timeline'),
          );
        }

        // Ordenar itens por timestamp
        final sortedItems = List<AudioTimelineItem>.from(timelineItems)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Área de arrasto para a timeline
                  DragTarget<String>(
                    onWillAccept: (data) => data != null,
                    onAccept: (imagePath) {
                      if (_dragInsertPosition != null) {
                        // Adicionar imagem na posição específica da timeline
                        final newItem = AudioTimelineItem(
                          imagePath: imagePath,
                          timestamp: _dragInsertPosition!,
                          displayDuration: const Duration(seconds: 5),
                        );
                        projectProvider.addTimelineItem(newItem);
                        
                        // Resetar posição de inserção
                        setState(() {
                          _dragInsertPosition = null;
                          _isDraggingOver = false;
                        });
                      }
                    },
                    onLeave: (_) {
                      setState(() {
                        _isDraggingOver = false;
                        _dragInsertPosition = null;
                      });
                    },
                    onMove: (details) {
                      // Calcular a posição do timestamp baseado na posição horizontal do arrasto
                      final RenderBox box = context.findRenderObject() as RenderBox;
                      final localPosition = box.globalToLocal(details.offset);
                      
                      // Calcular o timestamp baseado na posição relativa na timeline
                      final timelineWidth = box.size.width;
                      final relativePosition = localPosition.dx / timelineWidth;
                      
                      // Garantir que a posição esteja dentro dos limites da timeline (0 a duração do áudio)
                      final clampedPosition = relativePosition.clamp(0.0, 1.0);
                      
                      // Criar o timestamp baseado na posição relativa
                      final newTimestamp = Duration(
                        milliseconds: (audioDuration.inMilliseconds * clampedPosition).round()
                      );
                      
                      // Validar que o timestamp não ultrapassa a duração do áudio
                      if (newTimestamp <= audioDuration) {
                        setState(() {
                          _dragInsertPosition = newTimestamp;
                          _isDraggingOver = true;
                        });
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        color: _isDraggingOver ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                        width: double.infinity,
                        height: double.infinity,
                      );
                    },
                  ),
                  
                  // Exibição dos itens existentes na timeline
                  ListView(
                    scrollDirection: Axis.horizontal,
                    controller: _scrollController,
                    children: [
                      // Container para representar a duração total do áudio
                      Container(
                        width: MediaQuery.of(context).size.width - 40, // Margem para os lados
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            // Marcadores de tempo na timeline
                            ...List.generate(
                              11, // 10 divisões
                              (index) {
                                final position = index / 10.0;
                                return Positioned(
                                  left: (MediaQuery.of(context).size.width - 40) * position,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                );
                              },
                            ),
                            
                            // Marcadores visuais para cada posição de imagem na timeline
                            ...sortedItems.map((item) {
                              final position = item.timestamp.inMilliseconds / 
                                  audioDuration.inMilliseconds;
                              
                              return Positioned(
                                left: (MediaQuery.of(context).size.width - 40) * position,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 3,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            
                            // Imagens posicionadas na timeline
                            ...sortedItems.map((item) {
                              // Calcular posição relativa na timeline
                              final position = item.timestamp.inMilliseconds / 
                                  audioDuration.inMilliseconds;
                              
                              return Positioned(
                                left: (MediaQuery.of(context).size.width - 40) * position - 30,
                                top: 10,
                                child: _buildTimelineItem(context, item, position, 
                                    timelineItems.indexOf(item)),
                              );
                            }).toList(),
                            
                            // Indicador de posição de inserção durante arrasto
                            if (_isDraggingOver && _dragInsertPosition != null)
                              Positioned(
                                left: (MediaQuery.of(context).size.width - 40) * 
                                    (_dragInsertPosition!.inMilliseconds / 
                                    audioDuration.inMilliseconds),
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 2,
                                  color: Colors.blue,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDuration(_dragInsertPosition!),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Timeline ruler com marcadores de tempo
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildTimelineRuler(audioDuration),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineItem(BuildContext context, AudioTimelineItem item, double position, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        children: [
          // Posição na timeline
          Text(
            _formatDuration(item.timestamp),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          // Imagem
          Expanded(
            child: Container(
              width: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Imagem
                  Image.asset(
                    item.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.file(
                        File(item.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.broken_image, size: 40),
                          );
                        },
                      );
                    },
                  ),
                  // Duração de exibição
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _formatDuration(item.displayDuration),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // Botões de ação
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Row(
                      children: [
                        Container(
                          color: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            onPressed: () {
                              _showTimestampEditor(context, item, index);
                            },
                          ),
                        ),
                        Container(
                          color: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            onPressed: () {
                              _confirmDelete(context, index);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRuler(Duration totalDuration) {
    final totalSeconds = totalDuration.inSeconds;
    final markCount = totalSeconds > 60 ? 10 : totalSeconds;
    
    return Row(
      children: List.generate(markCount + 1, (index) {
        final position = index / markCount;
        final currentTime = Duration(milliseconds: (totalDuration.inMilliseconds * position).round());
        
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 1,
                height: 8,
                color: Colors.grey.shade600,
              ),
              Text(
                _formatDuration(currentTime),
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _confirmDelete(BuildContext context, int index) {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final item = projectProvider.project.timelineItems[index];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover imagem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tem certeza que deseja remover esta imagem da timeline?'),
            const SizedBox(height: 16),
            // Mostrar preview da imagem a ser removida
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(item.imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image, size: 40),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Mostrar informações do timestamp
            Text(
              'Posição: ${_formatDuration(item.timestamp)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () {
              // Remover o item da timeline
              projectProvider.removeTimelineItem(index);
              
              // Fechar o diálogo
              Navigator.of(context).pop();
              
              // Mostrar confirmação
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Imagem removida da timeline'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
  
  void _showTimestampEditor(BuildContext context, AudioTimelineItem item, int index) {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final audioDuration = projectProvider.project.audioDuration;
    if (audioDuration == null) return;
    
    // Valores iniciais para os controladores
    int initialMinutes = item.timestamp.inMinutes.remainder(60);
    int initialSeconds = item.timestamp.inSeconds.remainder(60);
    
    // Controladores para os campos de texto
    final minutesController = TextEditingController(text: initialMinutes.toString().padLeft(2, '0'));
    final secondsController = TextEditingController(text: initialSeconds.toString().padLeft(2, '0'));
    
    // Valor para o slider
    double currentValue = item.timestamp.inMilliseconds / audioDuration.inMilliseconds;
    
    // Função para atualizar o slider a partir dos valores de minutos e segundos
    void updateSliderFromInputs() {
      try {
        final minutes = int.parse(minutesController.text);
        final seconds = int.parse(secondsController.text);
        
        // Validar que os valores estão dentro dos limites permitidos
        if (minutes < 0 || seconds < 0 || seconds >= 60) {
          return;
        }
        
        final newDuration = Duration(minutes: minutes, seconds: seconds);
        
        // Validar que a posição não ultrapassa a duração do áudio
        if (newDuration > audioDuration) {
          return;
        }
        
        currentValue = newDuration.inMilliseconds / audioDuration.inMilliseconds;
      } catch (e) {
        // Ignorar erros de parsing
      }
    }
    
    // Função para atualizar os inputs a partir do valor do slider
    void updateInputsFromSlider() {
      final newDuration = Duration(
        milliseconds: (audioDuration.inMilliseconds * currentValue).round()
      );
      
      final minutes = newDuration.inMinutes.remainder(60);
      final seconds = newDuration.inSeconds.remainder(60);
      
      minutesController.text = minutes.toString().padLeft(2, '0');
      secondsController.text = seconds.toString().padLeft(2, '0');
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Ajustar Timestamp'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Exibição da posição atual
                Text(
                  'Posição na Timeline:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                
                // Input numérico para definição exata da posição
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Campo de minutos
                    SizedBox(
                      width: 50,
                      child: TextField(
                        controller: minutesController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'min',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (value) {
                          setState(() {
                            updateSliderFromInputs();
                          });
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(':', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    // Campo de segundos
                    SizedBox(
                      width: 50,
                      child: TextField(
                        controller: secondsController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'seg',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (value) {
                          setState(() {
                            updateSliderFromInputs();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Slider para ajuste fino
                Text(
                  'Ajuste Fino:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: currentValue,
                  onChanged: (value) {
                    setState(() {
                      currentValue = value;
                      updateInputsFromSlider();
                    });
                  },
                  min: 0.0,
                  max: 1.0,
                  divisions: 200, // Divisões aumentadas para ajuste mais fino
                ),
                
                // Exibir duração total do áudio como referência
                Text(
                  'Duração total do áudio: ${_formatDuration(audioDuration)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  try {
                    // Obter valores dos inputs
                    final minutes = int.parse(minutesController.text);
                    final seconds = int.parse(secondsController.text);
                    
                    // Validar valores
                    if (minutes < 0 || seconds < 0 || seconds >= 60) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Valores inválidos. Segundos devem estar entre 0-59.')),
                      );
                      return;
                    }
                    
                    // Criar nova duração
                    final newTimestamp = Duration(minutes: minutes, seconds: seconds);
                    
                    // Validar que não ultrapassa a duração do áudio
                    if (newTimestamp > audioDuration) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('O timestamp não pode ultrapassar a duração do áudio.')),
                      );
                      return;
                    }
                    
                    // Atualizar item
                    final updatedItem = AudioTimelineItem(
                      imagePath: item.imagePath,
                      timestamp: newTimestamp,
                      displayDuration: item.displayDuration,
                    );
                    
                    projectProvider.updateTimelineItem(index, updatedItem);
                    Navigator.of(context).pop();
                    
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, insira valores numéricos válidos.')),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

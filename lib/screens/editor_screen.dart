import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/image_timeline_list.dart';
import '../widgets/draggable_image_item.dart';
import '../routes.dart';

class EditorScreen extends StatelessWidget {
  const EditorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    final isLargeScreen = screenSize.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Consumer<ProjectProvider>(
          builder: (context, projectProvider, child) {
            return Text('Editor: ${projectProvider.project.name}');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Salvar Projeto',
            onPressed: () {
              // Implementação futura: salvar projeto
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Projeto salvo com sucesso!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: () {
              Navigator.pushNamed(context, Routes.project);
            },
          ),
        ],
      ),
      body: Consumer<ProjectProvider>(
        builder: (context, projectProvider, child) {
          final hasAudio = projectProvider.project.audioFilePath != null;
          
          if (!hasAudio) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Selecione um arquivo de áudio para começar',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.audio_file),
                    label: const Text('Selecionar Áudio'),
                    onPressed: () {
                      Navigator.pushNamed(context, Routes.audioSelection);
                    },
                  ),
                ],
              ),
            );
          }

          // Layout responsivo baseado na orientação e tamanho da tela
          if (isLandscape || isLargeScreen) {
            // Layout horizontal para telas grandes ou modo paisagem
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coluna esquerda: Player de áudio e timeline
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Área do player de áudio
                        Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Player de Áudio',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const AudioPlayerWidget(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Área de visualização da timeline
                        Expanded(
                          child: Card(
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Visualização da Timeline',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: ImageTimelineList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Coluna direita: Lista de imagens
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Imagens do Projeto',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: const Text('Adicionar'),
                                  onPressed: () {
                                    Navigator.pushNamed(context, Routes.imageSelection);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _buildDraggableImageGrid(projectProvider),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Layout vertical para telas menores ou modo retrato
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Área do player de áudio
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Player de Áudio',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const AudioPlayerWidget(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Área de visualização da timeline
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Visualização da Timeline',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: ImageTimelineList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Lista de imagens
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Imagens do Projeto',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: const Text('Adicionar'),
                                  onPressed: () {
                                    Navigator.pushNamed(context, Routes.imageSelection);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 300,
                              child: _buildDraggableImageGrid(projectProvider),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Implementação futura: gerar vídeo
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Funcionalidade de exportação em desenvolvimento')),
          );
        },
        tooltip: 'Exportar Vídeo',
        child: const Icon(Icons.movie_creation),
      ),
    );
  }

  Widget _buildDraggableImageGrid(ProjectProvider projectProvider) {
    final timelineItems = projectProvider.project.timelineItems;
    
    if (timelineItems.isEmpty) {
      return const Center(
        child: Text('Nenhuma imagem adicionada ao projeto'),
      );
    }
    
    // Criar uma lista de caminhos de imagens únicos
    final uniqueImagePaths = <String>{};
    for (var item in timelineItems) {
      uniqueImagePaths.add(item.imagePath);
    }
    
    final uniqueImages = uniqueImagePaths.toList();
    
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: uniqueImages.length,
      itemBuilder: (context, index) {
        final imagePath = uniqueImages[index];
        
        // Encontrar todas as ocorrências desta imagem na timeline
        final occurrences = timelineItems
            .where((item) => item.imagePath == imagePath)
            .toList();
        
        return DraggableImageItem(
          imagePath: imagePath,
          onTap: () {
            _showImageOccurrences(context, occurrences);
          },
        );
      },
    );
  }
  
  void _showImageOccurrences(BuildContext context, List<dynamic> occurrences) {
    if (occurrences.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ocorrências na Timeline'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: occurrences.length,
            itemBuilder: (context, index) {
              final item = occurrences[index];
              return ListTile(
                leading: SizedBox(
                  width: 40,
                  height: 40,
                  child: Image.file(
                    File(item.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image);
                    },
                  ),
                ),
                title: Text('Timestamp: ${_formatDuration(item.timestamp)}'),
                subtitle: Text('Duração: ${_formatDuration(item.displayDuration)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Editar timestamp',
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showEditTimestampDialog(context, item);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Remover imagem',
                      onPressed: () {
                        Navigator.of(context).pop();
                        _confirmDelete(context, item);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
  
  void _showEditTimestampDialog(BuildContext context, dynamic item) {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final audioDuration = projectProvider.project.audioDuration;
    if (audioDuration == null) return;
    
    final index = projectProvider.project.timelineItems.indexOf(item);
    if (index == -1) return;
    
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
            title: const Text('Editar Timestamp'),
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
                    final updatedItem = item.copyWith(timestamp: newTimestamp);
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
  
  void _confirmDelete(BuildContext context, dynamic item) {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final index = projectProvider.project.timelineItems.indexOf(item);
    if (index == -1) return;
    
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
}

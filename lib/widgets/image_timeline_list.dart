import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../models/audio_timeline_item.dart';
import '../routes.dart';

class ImageTimelineList extends StatefulWidget {
  const ImageTimelineList({Key? key}) : super(key: key);

  @override
  State<ImageTimelineList> createState() => _ImageTimelineListState();
}

class _ImageTimelineListState extends State<ImageTimelineList> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, projectProvider, child) {
        return Column(
          children: [
            // Botão simples para adicionar imagem na posição atual
            ElevatedButton.icon(
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Adicionar Imagem na Posição Atual'),
              onPressed: () {
                _showImagePicker(context, projectProvider);
              },
            ),
            
            // Lista simples das imagens na timeline
            Expanded(
              child: ListView.builder(
                itemCount: projectProvider.project.timelineItems.length,
                itemBuilder: (context, index) {
                  return _buildSimpleTimelineItem(
                    context, 
                    projectProvider.project.timelineItems[index], 
                    index
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  void _showImagePicker(BuildContext context, ProjectProvider projectProvider) {
    // Navegar para seleção de imagem única
    Navigator.pushNamed(context, Routes.imageSelection);
  }
  
  Widget _buildSimpleTimelineItem(BuildContext context, AudioTimelineItem item, int index) {
    return Card(
      child: ListTile(
        leading: Image.file(
          File(item.imagePath),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        ),
        title: Text('Posição: ${_formatDuration(item.timestamp)}'),
        subtitle: Text('Duração: ${_formatDuration(item.displayDuration)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editTimestamp(context, item, index),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context, index),
            ),
          ],
        ),
      ),
    );
  }
  
  void _editTimestamp(BuildContext context, AudioTimelineItem item, int index) {
    final initialMinutes = item.timestamp.inMinutes;
    final initialSeconds = item.timestamp.inSeconds % 60;
    
    final minutesController = TextEditingController(text: initialMinutes.toString().padLeft(2, '0'));
    final secondsController = TextEditingController(text: initialSeconds.toString().padLeft(2, '0'));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Posição na Timeline'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minutesController,
                    decoration: const InputDecoration(labelText: 'Minutos'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: secondsController,
                    decoration: const InputDecoration(labelText: 'Segundos'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final minutes = int.tryParse(minutesController.text) ?? 0;
              final seconds = int.tryParse(secondsController.text) ?? 0;
              
              final newTimestamp = Duration(minutes: minutes, seconds: seconds);
              
              final updatedItem = AudioTimelineItem(
                imagePath: item.imagePath,
                timestamp: newTimestamp,
                displayDuration: item.displayDuration,
              );
              
              Provider.of<ProjectProvider>(context, listen: false)
                .updateTimelineItem(index, updatedItem);
              
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
  
  void _confirmDelete(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Imagem'),
        content: const Text('Deseja remover esta imagem da timeline?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<ProjectProvider>(context, listen: false)
                .removeTimelineItem(index);
              Navigator.pop(context);
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

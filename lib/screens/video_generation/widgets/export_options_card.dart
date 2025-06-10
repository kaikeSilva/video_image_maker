import 'package:flutter/material.dart';
import '../video_generation_controller.dart';
import '../../../models/video_generation/video_generation_state.dart';

class ExportOptionsCard extends StatelessWidget {
  final VideoGenerationState state;
  final VideoGenerationController controller;

  const ExportOptionsCard({
    Key? key,
    required this.state,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Opções de Exportação',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Opção para salvar na galeria
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Salvar na Galeria'),
              subtitle: const Text('O vídeo será adicionado à galeria do dispositivo'),
              value: state.saveToGallery,
              onChanged: (bool value) => controller.updateSaveOptions(saveToGallery: value),
            ),
            // Opção para salvar em Downloads
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Salvar em Downloads'),
              subtitle: const Text('O vídeo será salvo na pasta Downloads'),
              value: state.saveToDownloads,
              onChanged: (bool value) => controller.updateSaveOptions(saveToDownloads: value),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

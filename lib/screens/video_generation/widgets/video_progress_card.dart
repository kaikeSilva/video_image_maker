import 'package:flutter/material.dart';
import '../../../models/video_generation/video_generation_state.dart';
import '../video_generation_controller.dart';

class VideoProgressCard extends StatelessWidget {
  final VideoGenerationState state;
  final VideoGenerationController controller;
  final VoidCallback onCancel;

  const VideoProgressCard({
    Key? key,
    required this.state,
    required this.controller,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Status: ${state.progress.currentStep}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: state.progress.hasError ? Colors.red : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                // Botão de cancelamento (apenas durante geração)
                if (state.isGenerating)
                  TextButton.icon(
                    onPressed: onCancel,
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
              // Garantir que o progresso esteja entre 0 e 1
              value: state.progress.progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                state.progress.hasError ? Colors.red : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            // Tempo estimado e porcentagem
            if (state.isGenerating && state.progress.progress > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Limitar a porcentagem exibida a 100%
                  Flexible(
                    flex: 1,
                    child: Text(
                      '${(state.progress.progress.clamp(0.0, 1.0) * 100).toStringAsFixed(1)}% concluído',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 1,
                    child: Text(
                      controller.getEstimatedTimeRemaining(),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            if (state.progress.hasError && state.progress.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  state.progress.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

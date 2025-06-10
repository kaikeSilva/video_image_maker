import 'package:flutter/material.dart';
import '../../../models/video_generation/video_generation_state.dart';
import '../video_generation_controller.dart';

class CompletionActions extends StatelessWidget {
  final VideoGenerationState state;
  final VideoGenerationController controller;
  final VoidCallback onReset;

  const CompletionActions({
    Key? key,
    required this.state,
    required this.controller,
    required this.onReset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!state.isVideoGenerated) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vídeo gerado com sucesso!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('O que você deseja fazer agora?'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Flexible(
                      flex: 1,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.replay),
                        label: const Text('Gerar Novamente'),
                        onPressed: onReset,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 1,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.file_download),
                        label: const Text('Salvar'),
                        onPressed: () => controller.saveVideoAgain(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      flex: 1,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Abrir'),
                        onPressed: state.outputVideoPath != null
                            ? () => controller.openVideo(state.outputVideoPath!)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 1,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text('Compartilhar'),
                        onPressed: () => controller.shareVideo(context),
                      ),
                    ),
                  ],
                ),
                
                // Botão para criar novo projeto
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Novo Projeto'),
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

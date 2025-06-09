import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../routes.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/video_preview_widget.dart';

class ProjectScreen extends StatelessWidget {
  const ProjectScreen({Key? key}) : super(key: key);
  
  String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Projeto'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, Routes.home);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nome do Projeto:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Digite o nome do projeto',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                context.read<ProjectProvider>().updateProjectName(value);
              },
            ),
            const SizedBox(height: 30),
            const Text(
              'Áudio:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Consumer<ProjectProvider>(
              builder: (context, projectProvider, child) {
                final hasAudio = projectProvider.project.audioFilePath != null;
                
                if (hasAudio) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Arquivo: ${projectProvider.project.audioFileName}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Duração: ${_formatDuration(projectProvider.project.audioDuration)}',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Audio Player Widget
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: const [
                              Text(
                                'Player de Áudio',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 12),
                              AudioPlayerWidget(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, Routes.audioSelection);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Alterar Áudio'),
                      ),
                    ],
                  );
                } else {
                  return ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, Routes.audioSelection);
                    },
                    icon: const Icon(Icons.audio_file),
                    label: const Text('Selecionar Arquivo de Áudio'),
                  );
                }
              },
            ),
            
            const SizedBox(height: 30),
            const Text(
              'Imagens:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Consumer<ProjectProvider>(
              builder: (context, projectProvider, child) {
                final hasImages = projectProvider.project.timelineItems.isNotEmpty;
                
                if (hasImages) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Imagens selecionadas: ${projectProvider.project.timelineItems.length}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, Routes.imageSelection);
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar Imagens'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, Routes.editor);
                              },
                              icon: const Icon(Icons.movie_edit),
                              label: const Text('Abrir Editor Principal'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  return ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, Routes.imageSelection);
                    },
                    icon: const Icon(Icons.image),
                    label: const Text('Selecionar Imagens'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

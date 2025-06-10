import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/project_provider.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/progress_indicator_widget.dart';
import 'video_generation_controller.dart';
import 'widgets/video_progress_card.dart';
import 'widgets/video_info_card.dart';
import 'widgets/export_options_card.dart';
import 'widgets/completion_actions.dart';
import 'widgets/video_quality_selector_widget.dart';

class VideoGenerationScreen extends StatefulWidget {
  const VideoGenerationScreen({Key? key}) : super(key: key);

  @override
  State<VideoGenerationScreen> createState() => _VideoGenerationScreenState();
}

class _VideoGenerationScreenState extends State<VideoGenerationScreen> {
  late final VideoGenerationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoGenerationController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = Provider.of<ProjectProvider>(context);
    
    // Escuta as mudanças no controller
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        // Define o conteúdo principal
        final state = _controller.state;
        
        // Só usamos o LoadingOverlay quando estamos em fases iniciais de preparação
        final bool useOverlay = state.useOverlay;
        
        // Conteúdo principal da tela
        final Widget mainContent = Scaffold(
          appBar: AppBar(
            title: const Text('Exportar Vídeo'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (state.isGenerating) {
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
                            _controller.cancelGeneration();
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
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 150,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Componentes reutilizáveis
                      VideoQualitySelectorWidget(
                        state: state,
                        controller: _controller,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Informações do projeto
                      VideoInfoCard(
                        projectProvider: projectProvider,
                        controller: _controller,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Opções de exportação, apenas se não estiver gerando
                      if (!state.isGenerating && !state.isVideoGenerated)
                        ExportOptionsCard(
                          state: state,
                          controller: _controller,
                        ),
                        
                      const SizedBox(height: 16),
                      
                      // Barra de progresso
                      if (state.isGenerating || state.progress.isCompleted || state.progress.hasError)
                        VideoProgressCard(
                          state: state,
                          controller: _controller,
                          onCancel: _controller.cancelGeneration,
                        ),
                      
                      // Ações após conclusão
                      CompletionActions(
                        state: state,
                        controller: _controller,
                        onReset: _controller.resetGeneration,
                      ),
                      
                      // Botão para iniciar geração, apenas se não estiver gerando
                      if (!state.isGenerating && !state.isVideoGenerated)
                        Padding(
                          padding: const EdgeInsets.only(top: 24.0),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.movie_creation),
                            label: const Text('Gerar Vídeo'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => _controller.generateVideo(projectProvider),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        
        // Escolhe qual interface de progresso usar com base no estado da geração
        if (useOverlay) {
          // Usa o LoadingOverlay apenas na fase inicial
          return LoadingOverlay(
            isLoading: true,
            message: 'Preparando geração de vídeo...',
            child: mainContent,
          );
        } else {
          // Usa apenas a barra de progresso interna no resto do tempo
          return mainContent;
        }
      },
    );
  }
}

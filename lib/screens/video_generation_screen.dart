import 'package:flutter/material.dart';
import 'video_generation/video_generation_screen.dart' as refactored;

/// Esta classe foi refatorada para uma arquitetura mais modular
/// O conteúdo original foi movido para os seguintes arquivos:
/// - screens/video_generation/video_generation_screen.dart (UI principal)
/// - screens/video_generation/video_generation_controller.dart (lógica)
/// - screens/video_generation/video_generation_state.dart (modelo de dados)
/// - screens/video_generation/widgets/* (componentes de UI)
/// 
/// Esta classe serve como wrapper para manter compatibilidade com código existente
class VideoGenerationScreen extends StatelessWidget {
  const VideoGenerationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Redireciona para a implementação refatorada
    return const refactored.VideoGenerationScreen();
  }
}

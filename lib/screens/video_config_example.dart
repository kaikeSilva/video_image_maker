import 'package:flutter/material.dart';
import '../utils/encoder_config.dart';
import '../widgets/video_quality_selector.dart';
import '../services/quick_video_encoder_service.dart';
import '../models/image_sequence_item.dart';

/// Tela de exemplo para configuração de vídeo antes da geração
class VideoConfigExample extends StatefulWidget {
  /// Lista de imagens para o vídeo
  final List<ImageSequenceItem> imageSequence;
  
  /// Caminho do arquivo de áudio
  final String audioPath;

  const VideoConfigExample({
    Key? key,
    required this.imageSequence,
    required this.audioPath,
  }) : super(key: key);

  @override
  State<VideoConfigExample> createState() => _VideoConfigExampleState();
}

class _VideoConfigExampleState extends State<VideoConfigExample> {
  VideoQuality _selectedQuality = VideoQuality.medium;
  VideoFormat _selectedFormat = VideoFormat.mobile;
  bool _isGenerating = false;
  double _progress = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações do Vídeo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Widget de seleção de qualidade e formato
            VideoQualitySelector(
              initialQuality: _selectedQuality,
              initialFormat: _selectedFormat,
              onQualityChanged: (quality) {
                setState(() {
                  _selectedQuality = quality;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _selectedFormat = format;
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            // Visualização do formato selecionado
            _buildFormatPreview(),
            
            const SizedBox(height: 24),
            
            // Botão de geração de vídeo
            if (_isGenerating)
              Column(
                children: [
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 8),
                  Text('Gerando vídeo: ${(_progress * 100).toStringAsFixed(1)}%'),
                ],
              )
            else
              ElevatedButton(
                onPressed: _generateVideo,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'GERAR VÍDEO',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Constrói uma visualização do formato selecionado
  Widget _buildFormatPreview() {
    final bool isMobile = _selectedFormat == VideoFormat.mobile;
    final double containerWidth = isMobile ? 120.0 : 200.0;
    final double containerHeight = isMobile ? 200.0 : 120.0;
    
    return Center(
      child: Column(
        children: [
          const Text(
            'Visualização do formato:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            width: containerWidth,
            height: containerHeight,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                isMobile ? Icons.smartphone : Icons.desktop_windows,
                size: 48,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Gera o vídeo com as configurações selecionadas
  Future<void> _generateVideo() async {
    setState(() {
      _isGenerating = true;
      _progress = 0.0;
    });

    try {
      final String outputPath = await QuickVideoEncoderService().generateVideo(
        imageSequence: widget.imageSequence,
        inputAudioPath: widget.audioPath,
        quality: _selectedQuality,
        format: _selectedFormat,
        onProgress: (progress) {
          setState(() {
            _progress = progress;
          });
        },
      );

      // Exibe mensagem de sucesso
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vídeo gerado com sucesso: $outputPath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Exibe mensagem de erro
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar vídeo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
}

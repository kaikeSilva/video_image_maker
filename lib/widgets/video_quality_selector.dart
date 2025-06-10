import 'package:flutter/material.dart';
import '../utils/encoder_config.dart';

/// Widget para seleção de qualidade de vídeo
class VideoQualitySelector extends StatefulWidget {
  /// Callback chamado quando a qualidade é alterada
  final Function(VideoQuality) onQualityChanged;
  
  /// Qualidade inicial selecionada
  final VideoQuality initialQuality;

  /// Construtor do seletor de qualidade
  const VideoQualitySelector({
    Key? key,
    required this.onQualityChanged,
    this.initialQuality = VideoQuality.medium,
  }) : super(key: key);

  @override
  State<VideoQualitySelector> createState() => _VideoQualitySelectorState();
}

class _VideoQualitySelectorState extends State<VideoQualitySelector> {
  late VideoQuality _selectedQuality;

  @override
  void initState() {
    super.initState();
    _selectedQuality = widget.initialQuality;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Qualidade do Vídeo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<VideoQuality>(
          value: _selectedQuality,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: VideoQuality.values.map((quality) {
            return DropdownMenuItem<VideoQuality>(
              value: quality,
              child: Row(
                children: [
                  Icon(
                    _getIconForQuality(quality),
                    color: _getColorForQuality(quality),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(quality.displayName),
                ],
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedQuality = newValue;
              });
              widget.onQualityChanged(newValue);
            }
          },
        ),
        const SizedBox(height: 8),
        _buildQualityInfo(),
      ],
    );
  }

  /// Retorna o ícone apropriado para cada qualidade
  IconData _getIconForQuality(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.high:
        return Icons.high_quality;
      case VideoQuality.medium:
        return Icons.hd;
      case VideoQuality.low:
        return Icons.sd;
      case VideoQuality.veryLow:
        return Icons.sd_outlined;
    }
  }

  /// Retorna a cor apropriada para cada qualidade
  Color _getColorForQuality(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.high:
        return Colors.green;
      case VideoQuality.medium:
        return Colors.blue;
      case VideoQuality.low:
        return Colors.orange;
      case VideoQuality.veryLow:
        return Colors.red;
    }
  }

  /// Constrói o widget de informações da qualidade selecionada
  Widget _buildQualityInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resolução: ${_selectedQuality.width}x${_selectedQuality.height}',
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            'Bitrate: ${(_selectedQuality.videoBitrate / 1000000).toStringAsFixed(1)} Mbps',
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            'Tamanho estimado: ${_getEstimatedFileSize(_selectedQuality)}',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// Calcula o tamanho estimado do arquivo com base na qualidade
  String _getEstimatedFileSize(VideoQuality quality) {
    // Estimativa simples baseada no bitrate de vídeo e áudio para 1 minuto de vídeo
    final int videoBitsPerMinute = quality.videoBitrate * 60;
    const int audioBitsPerMinute = 128000 * 60; // 128 kbps * 60 segundos
    final int totalBits = videoBitsPerMinute + audioBitsPerMinute;
    final double totalMB = totalBits / 8 / 1024 / 1024;
    
    return '~${totalMB.toStringAsFixed(1)} MB por minuto';
  }
}

import 'package:flutter/material.dart';
import '../utils/encoder_config.dart';

/// Widget para seleção de qualidade e formato de vídeo
class VideoQualitySelector extends StatefulWidget {
  /// Callback chamado quando a qualidade é alterada
  final Function(VideoQuality) onQualityChanged;
  
  /// Callback chamado quando o formato é alterado
  final Function(VideoFormat) onFormatChanged;
  
  /// Qualidade inicial selecionada
  final VideoQuality initialQuality;
  
  /// Formato inicial selecionado
  final VideoFormat initialFormat;

  /// Construtor do seletor de qualidade
  const VideoQualitySelector({
    Key? key,
    required this.onQualityChanged,
    required this.onFormatChanged,
    this.initialQuality = VideoQuality.medium,
    this.initialFormat = VideoFormat.mobile,
  }) : super(key: key);

  @override
  State<VideoQualitySelector> createState() => _VideoQualitySelectorState();
}

class _VideoQualitySelectorState extends State<VideoQualitySelector> {
  late VideoQuality _selectedQuality;
  late VideoFormat _selectedFormat;

  @override
  void initState() {
    super.initState();
    _selectedQuality = widget.initialQuality;
    _selectedFormat = widget.initialFormat;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configurações de Vídeo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 16),
        
        // Seletor de formato de vídeo
        const Text(
          'Formato do Vídeo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        _buildFormatSelector(),
        const SizedBox(height: 16),
        
        // Seletor de qualidade de vídeo
        const Text(
          'Qualidade do Vídeo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        _buildQualitySelector(),
        const SizedBox(height: 12),
        _buildQualityInfo(),
      ],
    );
  }
  
  /// Constrói o seletor de formato de vídeo
  Widget _buildFormatSelector() {
    return Row(
      children: VideoFormat.values.map((format) {
        final bool isSelected = format == _selectedFormat;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade200,
                foregroundColor: isSelected ? Colors.white : Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                setState(() {
                  _selectedFormat = format;
                });
                widget.onFormatChanged(format);
              },
              child: Column(
                children: [
                  Icon(
                    format == VideoFormat.mobile ? Icons.smartphone : Icons.desktop_windows,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    format == VideoFormat.mobile ? 'Celular' : 'Desktop',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    format == VideoFormat.mobile ? '(9:16)' : '(16:9)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
  
  /// Constrói o seletor de qualidade de vídeo
  Widget _buildQualitySelector() {
    return DropdownButtonFormField<VideoQuality>(
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
    final int width = _selectedQuality.getWidth(_selectedFormat);
    final int height = _selectedQuality.getHeight(_selectedFormat);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Formato: ${_selectedFormat.displayName}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Resolução: ${width}x${height}',
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

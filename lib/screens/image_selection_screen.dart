import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../routes.dart';
import '../models/audio_timeline_item.dart';
import '../widgets/progress_indicator_widget.dart';

class ImageSelectionScreen extends StatefulWidget {
  const ImageSelectionScreen({Key? key}) : super(key: key);

  @override
  State<ImageSelectionScreen> createState() => _ImageSelectionScreenState();
}

class _ImageSelectionScreenState extends State<ImageSelectionScreen> {
  final List<Map<String, dynamic>> _selectedImages = [];
  String? _errorMessage;
  bool _isLoading = false;
  
  // Maximum file size: 5MB
  static const int _maxFileSize = 5 * 1024 * 1024; // 5MB in bytes

  Future<void> _pickImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        List<PlatformFile> validFiles = [];
        List<String> invalidFiles = [];
        List<String> oversizedFiles = [];

        // Validate each file
        for (var file in result.files) {
          // Check file format
          if (!_isValidImageFormat(file.path!)) {
            invalidFiles.add(file.name);
            continue;
          }
          
          // Check file size
          if (file.size > _maxFileSize) {
            oversizedFiles.add(file.name);
            continue;
          }
          
          validFiles.add(file);
        }

        // Build error message if needed
        if (invalidFiles.isNotEmpty || oversizedFiles.isNotEmpty) {
          String errorMsg = '';
          
          if (invalidFiles.isNotEmpty) {
            errorMsg += 'Formatos inválidos: ${invalidFiles.join(", ")}. Apenas PNG, JPG e JPEG são permitidos.\n';
          }
          
          if (oversizedFiles.isNotEmpty) {
            errorMsg += 'Arquivos muito grandes: ${oversizedFiles.join(", ")}. O tamanho máximo é 5MB por imagem.';
          }
          
          setState(() {
            _errorMessage = errorMsg.trim();
          });
        }

        // Add valid files to the list
        if (validFiles.isNotEmpty) {
          setState(() {
            for (var file in validFiles) {
              _selectedImages.add({
                'path': file.path!,
                'name': file.name,
                'size': file.size,
              });
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao selecionar imagens: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isValidImageFormat(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png'].contains(extension);
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // Métodos de configuração de timestamp e duração removidos

  void _saveImages() {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    
    // Convert selected images to AudioTimelineItem objects with default values
    final timelineItems = _selectedImages.map((image) {
      return AudioTimelineItem(
        imagePath: image['path'],
        timestamp: Duration.zero, // PADRÃO: posicionar no início
        displayDuration: const Duration(seconds: 5), // PADRÃO: 5 segundos
      );
    }).toList();
    
    // Add timeline items to the project
    for (var item in timelineItems) {
      projectProvider.addTimelineItem(item);
    }
    
    // Navigate to editor screen
    Navigator.pushNamed(context, Routes.editor);
  }

  String _formatFileSize(int sizeInBytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = sizeInBytes.toDouble();
    
    while (size > 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar Imagens'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Volta para AudioSelectionScreen
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: const FlowProgressIndicator(currentStep: 1),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickImages,
              icon: const Icon(Icons.image),
              label: Text(_isLoading ? 'Carregando...' : 'Selecionar Imagens'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade100,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Imagens Selecionadas: ${_selectedImages.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _selectedImages.isEmpty
                  ? const Center(
                      child: Text('Nenhuma imagem selecionada'),
                    )
                  : ListView.builder(
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        final image = _selectedImages[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Imagem ${index + 1}: ${image['name']}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Tamanho: ${_formatFileSize(image['size'])}'),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _removeImage(index),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_selectedImages.isNotEmpty)
              ElevatedButton(
                onPressed: _saveImages,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Confirmar Seleção'),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../routes.dart';

class AudioSelectionScreen extends StatefulWidget {
  const AudioSelectionScreen({Key? key}) : super(key: key);

  @override
  State<AudioSelectionScreen> createState() => _AudioSelectionScreenState();
}

class _AudioSelectionScreenState extends State<AudioSelectionScreen> {
  String? _selectedFilePath;
  String? _selectedFileName;
  Duration? _audioDuration;
  String? _errorMessage;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Validate if it's an MP3 file
        if (!_isValidMp3(file.path!)) {
          setState(() {
            _errorMessage = 'Arquivo inválido. Por favor, selecione um arquivo MP3.';
            _isLoading = false;
          });
          return;
        }

        // Load audio to get duration
        try {
          await _audioPlayer.setFilePath(file.path!);
          final duration = await _audioPlayer.duration;
          
          setState(() {
            _selectedFilePath = file.path;
            _selectedFileName = file.name;
            _audioDuration = duration;
            _isLoading = false;
          });
        } catch (e) {
          setState(() {
            _errorMessage = 'Erro ao carregar o arquivo de áudio. Tente novamente.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao selecionar o arquivo. Tente novamente.';
        _isLoading = false;
      });
    }
  }

  bool _isValidMp3(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return extension == 'mp3';
  }

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
        title: const Text('Selecionar Áudio'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, Routes.project);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Selecione um arquivo de áudio MP3',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickAudioFile,
              icon: const Icon(Icons.audio_file),
              label: Text(_isLoading ? 'Carregando...' : 'Selecionar Arquivo MP3'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade100,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_selectedFilePath != null) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arquivo: $_selectedFileName',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Duração: ${_formatDuration(_audioDuration)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_selectedFilePath != null && 
                      _selectedFileName != null && 
                      _audioDuration != null) {
                    // Store the audio file reference in the provider
                    context.read<ProjectProvider>().setAudioFile(
                      _selectedFilePath!,
                      _selectedFileName!,
                      _audioDuration!,
                    );
                    
                    // Navigate back to project screen
                    Navigator.pushReplacementNamed(context, Routes.project);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Confirmar Seleção'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'ffmpeg_service.dart';
import 'video_generator_service.dart';

/// Serviço para compartilhamento de vídeos e exportação em diferentes qualidades
class ShareService {
  static final ShareService _instance = ShareService._internal();
  final FFmpegService _ffmpegService = FFmpegService();
  
  factory ShareService() {
    return _instance;
  }
  
  ShareService._internal();
  
  /// Compartilha um vídeo com aplicativos nativos
  /// Retorna true se o compartilhamento foi iniciado com sucesso
  Future<bool> shareVideo(String videoPath, {String? subject, String? text}) async {
    try {
      final File videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        debugPrint('Arquivo de vídeo não encontrado: $videoPath');
        return false;
      }
      
      final XFile file = XFile(videoPath);
      await Share.shareXFiles(
        [file],
        subject: subject ?? 'Vídeo criado com VideoMaker',
        text: text ?? 'Confira este vídeo que criei com o VideoMaker!',
      );
      
      return true;
    } catch (e) {
      debugPrint('Erro ao compartilhar vídeo: $e');
      return false;
    }
  }
  
  /// Exporta o vídeo para uma qualidade específica
  /// Retorna o caminho do vídeo exportado ou null em caso de erro
  Future<String?> exportVideoWithQuality({
    required String inputVideoPath,
    required VideoQualityConfig quality,
    Function(double)? progressCallback,
  }) async {
    try {
      final File inputFile = File(inputVideoPath);
      if (!await inputFile.exists()) {
        debugPrint('Arquivo de vídeo de entrada não encontrado: $inputVideoPath');
        return null;
      }
      
      // Cria um diretório temporário para o vídeo exportado
      final Directory tempDir = await getTemporaryDirectory();
      final String uuid = const Uuid().v4().substring(0, 8);
      final String outputFileName = 'export_${quality.name}_$uuid.mp4';
      final String outputPath = '${tempDir.path}/$outputFileName';
      
      // Configura os parâmetros do FFmpeg para a qualidade desejada
      final List<String> ffmpegCommand = [
        '-i',
        inputVideoPath,
        '-c:v',
        'libx264',
        '-preset',
        'medium',
        '-b:v',
        quality.videoBitrate,
        '-c:a',
        'aac',
        '-b:a',
        quality.audioBitrate,
        '-s',
        quality.resolution,
        '-y',
        outputPath,
      ];
      
      // Executa o comando FFmpeg
      progressCallback?.call(0.1); // Inicia o progresso
      
      final int result = await _ffmpegService.executeCommand(ffmpegCommand);
      
      if (result != 0) {
        debugPrint('Erro ao exportar vídeo com qualidade ${quality.name}');
        return null;
      }
      
      progressCallback?.call(1.0); // Completa o progresso
      return outputPath;
    } catch (e) {
      debugPrint('Erro ao exportar vídeo: $e');
      return null;
    }
  }
  
  /// Compartilha um vídeo com uma qualidade específica
  /// Primeiro exporta o vídeo para a qualidade desejada e depois o compartilha
  Future<bool> shareVideoWithQuality({
    required String inputVideoPath,
    required VideoQualityConfig quality,
    String? subject,
    String? text,
    Function(double)? progressCallback,
  }) async {
    try {
      // Exporta o vídeo com a qualidade desejada
      progressCallback?.call(0.0);
      final String? exportedVideoPath = await exportVideoWithQuality(
        inputVideoPath: inputVideoPath,
        quality: quality,
        progressCallback: (progress) {
          // Mapeia o progresso da exportação para 0-80%
          progressCallback?.call(progress * 0.8);
        },
      );
      
      if (exportedVideoPath == null) {
        debugPrint('Falha ao exportar vídeo para compartilhamento');
        return false;
      }
      
      // Compartilha o vídeo exportado
      progressCallback?.call(0.9);
      final bool shared = await shareVideo(
        exportedVideoPath,
        subject: subject ?? 'Vídeo criado com VideoMaker (${quality.name})',
        text: text ?? 'Confira este vídeo que criei com o VideoMaker!',
      );
      
      progressCallback?.call(1.0);
      return shared;
    } catch (e) {
      debugPrint('Erro ao compartilhar vídeo com qualidade específica: $e');
      return false;
    }
  }
}

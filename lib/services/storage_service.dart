import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:disk_space/disk_space.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';

/// Serviço para gerenciar o armazenamento local de vídeos
class StorageService {
  static final StorageService _instance = StorageService._internal();
  
  factory StorageService() {
    return _instance;
  }
  
  StorageService._internal();
  
  /// Verifica se há espaço suficiente no dispositivo
  /// Retorna true se houver espaço suficiente, false caso contrário
  Future<bool> hasEnoughSpace(int requiredSpaceInBytes) async {
    try {
      // Obtém o espaço livre em bytes
      final double? freeSpace = await DiskSpace.getFreeDiskSpace;
      
      if (freeSpace == null) {
        debugPrint('Não foi possível determinar o espaço livre');
        return false;
      }
      
      // Converte para bytes (freeSpace é em MB)
      final double freeSpaceInBytes = freeSpace * 1024 * 1024;
      
      // Verifica se há espaço suficiente (com margem de segurança de 10%)
      final bool hasEnough = freeSpaceInBytes > (requiredSpaceInBytes * 1.1);
      
      debugPrint('Espaço livre: ${(freeSpaceInBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
      debugPrint('Espaço necessário: ${(requiredSpaceInBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
      debugPrint('Espaço suficiente: $hasEnough');
      
      return hasEnough;
    } catch (e) {
      debugPrint('Erro ao verificar espaço disponível: $e');
      // Em caso de erro, assume que há espaço suficiente para não bloquear o usuário
      return true;
    }
  }
  
  /// Gera um nome de arquivo único para o vídeo
  /// Formato: VideoMaker_YYYY-MM-DD_HH-MM-SS_UUID.mp4
  String generateUniqueFileName() {
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
    final String uuid = const Uuid().v4().substring(0, 8); // Usa apenas os primeiros 8 caracteres do UUID
    
    return 'VideoMaker_${formattedDate}_$uuid.mp4';
  }
  
  /// Salva o vídeo na galeria/pasta de downloads do dispositivo
  /// Retorna o caminho do vídeo salvo ou null em caso de erro
  Future<String?> saveVideoToGallery(String sourcePath) async {
    try {
      // Verifica permissões
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        debugPrint('Permissão de armazenamento negada');
        return null;
      }
      
      // Verifica se o arquivo existe
      final File sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('Arquivo de origem não encontrado: $sourcePath');
        return null;
      }
      
      // Verifica o tamanho do arquivo
      final int fileSize = await sourceFile.length();
      
      // Verifica se há espaço suficiente
      if (!await hasEnoughSpace(fileSize)) {
        debugPrint('Espaço insuficiente para salvar o vídeo');
        return null;
      }
      
      // Salva o vídeo na galeria
      final bool? success = await GallerySaver.saveVideo(sourcePath);
      
      if (success == true) {
        debugPrint('Vídeo salvo com sucesso na galeria');
        return sourcePath;
      } else {
        debugPrint('Falha ao salvar vídeo na galeria');
        return null;
      }
    } catch (e) {
      debugPrint('Erro ao salvar vídeo na galeria: $e');
      return null;
    }
  }
  
  /// Salva o vídeo na pasta de downloads do dispositivo
  /// Retorna o caminho do vídeo salvo ou null em caso de erro
  Future<String?> saveVideoToDownloads(String sourcePath) async {
    try {
      // Verifica permissões
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        debugPrint('Permissão de armazenamento negada');
        return null;
      }
      
      // Verifica se o arquivo existe
      final File sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('Arquivo de origem não encontrado: $sourcePath');
        return null;
      }
      
      // Verifica o tamanho do arquivo
      final int fileSize = await sourceFile.length();
      
      // Verifica se há espaço suficiente
      if (!await hasEnoughSpace(fileSize)) {
        debugPrint('Espaço insuficiente para salvar o vídeo');
        return null;
      }
      
      // Gera um nome de arquivo único
      final String fileName = generateUniqueFileName();
      
      // Obtém o diretório de downloads
      Directory? downloadsDir;
      
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          // Fallback para o diretório de documentos
          downloadsDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      } else {
        // Outros sistemas (desktop)
        downloadsDir = await getDownloadsDirectory();
      }
      
      if (downloadsDir == null) {
        debugPrint('Não foi possível obter o diretório de downloads');
        return null;
      }
      
      // Caminho completo para o arquivo de destino
      final String destinationPath = '${downloadsDir.path}/$fileName';
      
      // Copia o arquivo para o diretório de downloads
      await sourceFile.copy(destinationPath);
      
      debugPrint('Vídeo salvo com sucesso em: $destinationPath');
      return destinationPath;
    } catch (e) {
      debugPrint('Erro ao salvar vídeo na pasta de downloads: $e');
      return null;
    }
  }
}

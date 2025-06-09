import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// Níveis de log
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical
}

/// Serviço para gerenciar logs da aplicação
class LogService {
  // Singleton pattern
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();
  
  // Configurações
  bool _enableConsoleLog = true;
  bool _enableFileLog = true;
  LogLevel _minLogLevel = LogLevel.debug;
  String? _logFilePath;
  
  // Getters e setters
  bool get enableConsoleLog => _enableConsoleLog;
  set enableConsoleLog(bool value) => _enableConsoleLog = value;
  
  bool get enableFileLog => _enableFileLog;
  set enableFileLog(bool value) => _enableFileLog = value;
  
  LogLevel get minLogLevel => _minLogLevel;
  set minLogLevel(LogLevel value) => _minLogLevel = value;
  
  // Inicializa o serviço de log
  Future<void> initialize() async {
    if (_enableFileLog && _logFilePath == null) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        _logFilePath = '${directory.path}/video_maker_logs_$dateStr.log';
        
        // Cria o arquivo de log se não existir
        final file = File(_logFilePath!);
        if (!await file.exists()) {
          await file.create(recursive: true);
          await _writeToFile('=== Log iniciado em ${DateTime.now()} ===\n');
        }
        
        debug('LogService', 'Serviço de log inicializado com sucesso');
      } catch (e) {
        debugPrint('Erro ao inicializar serviço de log: $e');
        _enableFileLog = false;
      }
    }
  }
  
  // Registra uma mensagem de log com o nível especificado
  Future<void> log(String tag, String message, LogLevel level) async {
    if (level.index < _minLogLevel.index) return;
    
    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    final levelStr = level.toString().split('.').last.toUpperCase();
    final logMessage = '[$timestamp] $levelStr/$tag: $message';
    
    // Log no console
    if (_enableConsoleLog) {
      switch (level) {
        case LogLevel.debug:
          debugPrint(logMessage);
          break;
        case LogLevel.info:
          debugPrint('\x1B[34m$logMessage\x1B[0m'); // Azul
          break;
        case LogLevel.warning:
          debugPrint('\x1B[33m$logMessage\x1B[0m'); // Amarelo
          break;
        case LogLevel.error:
          debugPrint('\x1B[31m$logMessage\x1B[0m'); // Vermelho
          break;
        case LogLevel.critical:
          debugPrint('\x1B[41m\x1B[37m$logMessage\x1B[0m'); // Fundo vermelho, texto branco
          break;
      }
    }
    
    // Log em arquivo
    if (_enableFileLog && _logFilePath != null) {
      await _writeToFile('$logMessage\n');
    }
  }
  
  // Métodos de conveniência para diferentes níveis de log
  Future<void> debug(String tag, String message) async => log(tag, message, LogLevel.debug);
  Future<void> info(String tag, String message) async => log(tag, message, LogLevel.info);
  Future<void> warning(String tag, String message) async => log(tag, message, LogLevel.warning);
  Future<void> error(String tag, String message) async => log(tag, message, LogLevel.error);
  Future<void> critical(String tag, String message) async => log(tag, message, LogLevel.critical);
  
  // Registra uma exceção com stack trace
  Future<void> exception(String tag, dynamic exception, [StackTrace? stackTrace]) async {
    final message = 'Exceção: $exception\n${stackTrace ?? StackTrace.current}';
    await error(tag, message);
  }
  
  // Escreve no arquivo de log
  Future<void> _writeToFile(String message) async {
    try {
      if (_logFilePath != null) {
        final file = File(_logFilePath!);
        await file.writeAsString(message, mode: FileMode.append);
      }
    } catch (e) {
      debugPrint('Erro ao escrever no arquivo de log: $e');
    }
  }
  
  // Limpa os logs antigos (mantém apenas os últimos X dias)
  Future<void> cleanOldLogs({int keepDays = 7}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      
      final now = DateTime.now();
      final logFileRegex = RegExp(r'video_maker_logs_(\d{4}-\d{2}-\d{2})\.log');
      
      for (var fileEntity in files) {
        if (fileEntity is File) {
          final fileName = fileEntity.path.split('/').last;
          final match = logFileRegex.firstMatch(fileName);
          
          if (match != null && match.groupCount >= 1) {
            final dateStr = match.group(1);
            if (dateStr != null) {
              final fileDate = DateFormat('yyyy-MM-dd').parse(dateStr);
              final difference = now.difference(fileDate).inDays;
              
              if (difference > keepDays) {
                await fileEntity.delete();
                debug('LogService', 'Log antigo removido: $fileName');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao limpar logs antigos: $e');
    }
  }
}

import 'dart:async';
import 'dart:io' as io;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'log_service.dart';

class FFmpegService {
  // Singleton pattern
  static final FFmpegService _instance = FFmpegService._internal();
  factory FFmpegService() => _instance;
  FFmpegService._internal() {
    _logService = LogService();
  }
  
  // Serviço de log
  late final LogService _logService;

  // Status da biblioteca
  bool _isAvailable = false;
  String _version = '';
  
  // Callback para monitorar o progresso
  Function(Statistics)? _progressCallback;
  
  // Sessão atual do FFmpeg para permitir cancelamento
  var _currentSession;
  
  // Parâmetros básicos de codificação
  final Map<String, String> _defaultEncodingParams = {
    'videoCodec': 'libx264',       // Codec de vídeo H.264
    'audioCodec': 'aac',           // Codec de áudio AAC
    'videoBitrate': '2M',          // Bitrate do vídeo (2 Mbps)
    'audioBitrate': '128k',        // Bitrate do áudio (128 kbps)
    'frameRate': '30',             // Taxa de quadros (30 fps)
    'preset': 'medium',            // Preset de codificação (equilibrio entre velocidade e qualidade)
    'pixelFormat': 'yuv420p',      // Formato de pixel YUV 4:2:0
    'outputFormat': 'mp4'          // Formato de saída MP4
  };

  // Getters
  bool get isAvailable => _isAvailable;
  String get version => _version;
  Map<String, String> get defaultEncodingParams => Map.unmodifiable(_defaultEncodingParams);

  // Inicializa o FFmpeg e verifica sua disponibilidade
  Future<bool> initialize() async {
    try {
      // Inicializa o serviço de log
      await _logService.initialize();
      _logService.info('FFmpegService', 'Inicializando serviço FFmpeg');
      
      // Verifica se o FFmpeg está disponível
      final version = await FFmpegKitConfig.getFFmpegVersion();
      _version = version ?? '';
      _isAvailable = _version.isNotEmpty;
      
      if (_isAvailable) {
        _logService.info('FFmpegService', 'FFmpeg inicializado com sucesso. Versão: $_version');
        
        // Configura o log level
        FFmpegKitConfig.enableLogCallback((log) {
          final message = log.getMessage();
          final level = log.getLevel();
          
          // Classifica o nível de log do FFmpeg apenas se houver mensagem
          if (message != null && message.isNotEmpty) {
            if (level <= 16) { // AV_LOG_ERROR e abaixo
              _logService.error('FFmpeg', message);
            } else if (level <= 24) { // AV_LOG_WARNING
              _logService.warning('FFmpeg', message);
            } else if (level <= 32) { // AV_LOG_INFO
              _logService.info('FFmpeg', message);
            } else { // AV_LOG_DEBUG e acima
              _logService.debug('FFmpeg', message);
            }
          }
        });
        
        // Configura o callback de estatísticas
        FFmpegKitConfig.enableStatisticsCallback((Statistics statistics) {
          // As estatísticas podem ser usadas para monitorar o progresso
          final time = statistics.getTime();
          final frame = statistics.getVideoFrameNumber();
          final fps = statistics.getVideoFps();
          
          _logService.debug('FFmpeg', 'Stats: Time=$time, Frame=$frame, FPS=$fps');
          
          // Chama o callback de progresso personalizado, se definido
          _progressCallback?.call(statistics);
        });
      } else {
        _logService.error('FFmpegService', 'FFmpeg não está disponível no dispositivo');
      }
      
      return _isAvailable;
    } catch (e, stackTrace) {
      _logService.exception('FFmpegService', 'Erro ao inicializar FFmpeg: $e', stackTrace);
      _isAvailable = false;
      return false;
    }
  }

  // Verifica se o FFmpeg está disponível
  Future<bool> checkAvailability() async {
    if (_isAvailable) return true;
    
    return await initialize();
  }

  // Configura parâmetros personalizados de codificação
  void setEncodingParam(String key, String value) {
    if (_defaultEncodingParams.containsKey(key)) {
      _defaultEncodingParams[key] = value;
    }
  }
  
  // Define o callback para monitorar o progresso da codificação
  void setProgressCallback(Function(Statistics) callback) {
    _progressCallback = callback;
  }

  // Constrói o comando FFmpeg com base nos parâmetros
  List<String> buildCommand({
    required String inputAudioPath,
    required List<Map<String, dynamic>> imageSequence,
    required String outputPath,
    Map<String, String>? customParams,
  }) {
    final params = Map<String, String>.from(_defaultEncodingParams);
    
    // Sobrescreve com parâmetros personalizados, se fornecidos
    if (customParams != null) {
      params.addAll(customParams);
    }

    // Lista para armazenar o comando completo
    List<String> command = [];

    // Input de áudio
    command.add('-i');
    command.add(inputAudioPath);

    // Configuração para a sequência de imagens com transições baseadas no timestamp
    List<String> filterParts = [];
    List<String> segmentParts = [];
    
    // Para cada imagem, criamos um filtro para escalar e ajustar
    for (int i = 0; i < imageSequence.length; i++) {
      final item = imageSequence[i];
      final imagePath = item['imagePath'] as String;
      
      // Verifica se o caminho da imagem existe
      if (imagePath.isEmpty) {
        _logService.error('FFmpegService', 'Caminho de imagem inválido: $imagePath');
        continue;
      }
      
      // Adiciona input para cada imagem
      command.add('-i');
      command.add(imagePath);
      
      // Cria o filtro para esta imagem - escala para 1280x720 mantendo proporção
      filterParts.add('[${i + 1}:v]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1[v$i]');
      
      // Determina a duração desta imagem
      double duration = 0;
      
      if (i < imageSequence.length - 1) {
        // Para todas as imagens exceto a última, a duração é até a próxima imagem
        duration = ((imageSequence[i+1]['timestamp'] as int) - (item['timestamp'] as int)) / 1000.0;
      } else {
        // Para a última imagem, dura até o final do áudio
        // Usar uma duração grande o suficiente para cobrir o resto do áudio
        duration = 86400; // 24 horas em segundos (valor grande para garantir que cubra o áudio)
      }
      
      // Adiciona o segmento com tempo e duração
      segmentParts.add('[v$i]trim=start=0:duration=$duration,setpts=PTS-STARTPTS[s$i]');
    }
    
    // Adiciona os filtros de escala
    filterParts.addAll(segmentParts);
    
    // Concatena os segmentos
    if (imageSequence.length > 0) {
      String concatInputs = '';
      for (int i = 0; i < imageSequence.length; i++) {
        concatInputs += '[s$i]';
      }
      filterParts.add('${concatInputs}concat=n=${imageSequence.length}:v=1:a=0[outv]');
    }
    
    // Adiciona o filtro complex ao comando se houver imagens
    if (filterParts.isNotEmpty) {
      String filterComplex = filterParts.join(';');
      command.add('-filter_complex');
      command.add(filterComplex);
      
      // Mapa o output do filtro para o stream de vídeo
      command.add('-map');
      command.add('[outv]');
      
      // Mapa o áudio original
      command.add('-map');
      command.add('0:a');
    }

    // Adiciona os parâmetros de codificação
    command.add('-c:v');
    command.add(params['videoCodec']!);
    
    command.add('-b:v');
    command.add(params['videoBitrate']!);
    
    command.add('-c:a');
    command.add(params['audioCodec']!);
    
    command.add('-b:a');
    command.add(params['audioBitrate']!);
    
    command.add('-r');
    command.add(params['frameRate']!);
    
    command.add('-preset');
    command.add(params['preset']!);
    
    command.add('-pix_fmt');
    command.add(params['pixelFormat']!);
    
    // Garante que o vídeo tenha a mesma duração do áudio
    command.add('-shortest');
    
    // Caminho de saída
    command.add(outputPath);

    return command;
  }

  // Executa o comando FFmpeg
  Future<int> executeCommand(List<String> command) async {
    if (!_isAvailable) {
      _logService.error('FFmpegService', 'FFmpeg não está disponível para executar comando');
      return -1;
    }

    try {
      final commandStr = command.join(' ');
      _logService.info('FFmpegService', 'Executando comando FFmpeg: $commandStr');
      
      _currentSession = await FFmpegKit.execute(commandStr);
      final returnCode = await _currentSession.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        _logService.info('FFmpegService', 'Comando FFmpeg executado com sucesso');
        return 0;
      } else if (ReturnCode.isCancel(returnCode)) {
        _logService.warning('FFmpegService', 'Comando FFmpeg cancelado pelo usuário');
        return 1;
      } else {
        final output = await _currentSession.getOutput();
        final errorCode = returnCode?.getValue() ?? -1;
        _logService.error('FFmpegService', 'Erro ao executar comando FFmpeg. Código: $errorCode');
        _logService.error('FFmpegService', 'Saída do FFmpeg: $output');
        
        // Tenta obter logs de erro mais detalhados
        final logs = await _currentSession.getLogs();
        if (logs.isNotEmpty) {
          for (final log in logs) {
            final message = log.getMessage() ?? '';
            if (message.contains('Error') || message.contains('error')) {
              _logService.error('FFmpegService', 'Log de erro: $message');
            }
          }
        }
        
        return errorCode;
      }
    } catch (e, stackTrace) {
      _logService.exception('FFmpegService', 'Exceção ao executar FFmpeg', stackTrace);
      return -1;
    }
  }
  
  // Cancela a execução atual do FFmpeg
  Future<bool> cancelExecution() async {
    if (_currentSession != null) {
      await FFmpegKit.cancel();
      return true;
    }
    return false;
  }
  
  // Extrai a duração de um arquivo de áudio
  Future<Duration> getAudioDuration(String audioPath) async {
    if (!_isAvailable) {
      _logService.error('FFmpegService', 'FFmpeg não está disponível para obter duração');
      return const Duration(seconds: 60); // Duração padrão
    }
    
    try {
      // Verifica se o arquivo existe
      final audioFile = io.File(audioPath);
      if (!await audioFile.exists()) {
        _logService.error('FFmpegService', 'Arquivo de áudio não encontrado: $audioPath');
        return const Duration(seconds: 0);
      }
      
      _logService.info('FFmpegService', 'Obtendo duração do áudio: $audioPath');
      
      final session = await FFprobeKit.execute('-v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$audioPath"');
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        
        if (output != null && output.isNotEmpty) {
          final durationInSeconds = double.parse(output.trim());
          final duration = Duration(milliseconds: (durationInSeconds * 1000).round());
          _logService.info('FFmpegService', 'Duração do áudio: ${duration.inSeconds} segundos');
          return duration;
        } else {
          _logService.warning('FFmpegService', 'Não foi possível obter a duração do áudio (saída vazia)');
          return const Duration(seconds: 0);
        }
      } else {
        final output = await session.getOutput() ?? 'Sem saída';
        _logService.error('FFmpegService', 'Erro ao obter duração do áudio. Saída: $output');
        return const Duration(seconds: 0);
      }
    } catch (e, stackTrace) {
      _logService.exception('FFmpegService', 'Exceção ao obter duração do áudio: $e', stackTrace);
      return const Duration(seconds: 60); // Duração padrão em caso de erro
    }
  }
  
  // Método simplificado para gerar vídeo a partir de áudio e sequência de imagens
  Future<bool> generateVideo({
    required String inputAudioPath,
    required List<Map<String, dynamic>> imageSequence,
    required String outputPath,
    Map<String, String>? customParams,
  }) async {
    if (!_isAvailable) {
      _logService.error('FFmpegService', 'FFmpeg não está disponível para gerar vídeo');
      return false;
    }
    
    try {
      // Verifica se os arquivos de entrada existem
      final audioFile = io.File(inputAudioPath);
      if (!await audioFile.exists()) {
        _logService.error('FFmpegService', 'Arquivo de áudio não encontrado: $inputAudioPath');
        return false;
      }
      
      // Verifica se todas as imagens existem
      for (final item in imageSequence) {
        final imagePath = item['imagePath'] as String?;
        if (imagePath == null) {
          _logService.error('FFmpegService', 'Caminho de imagem inválido (null) na sequência');
          return false;
        }
        
        final imageFile = io.File(imagePath);
        if (!await imageFile.exists()) {
          _logService.error('FFmpegService', 'Arquivo de imagem não encontrado: $imagePath');
          return false;
        }
      }
      
      // Verifica se o diretório de saída existe
      final outputDir = io.Directory(outputPath.substring(0, outputPath.lastIndexOf('/')));
      if (!await outputDir.exists()) {
        _logService.info('FFmpegService', 'Criando diretório de saída: ${outputDir.path}');
        await outputDir.create(recursive: true);
      }
      
      _logService.info('FFmpegService', 'Iniciando geração de vídeo');
      _logService.info('FFmpegService', 'Áudio: $inputAudioPath');
      _logService.info('FFmpegService', 'Saída: $outputPath');
      _logService.info('FFmpegService', 'Número de imagens: ${imageSequence.length}');
      
      final command = buildCommand(
        inputAudioPath: inputAudioPath,
        imageSequence: imageSequence,
        outputPath: outputPath,
        customParams: customParams,
      );
      
      final result = await executeCommand(command);
      
      if (result == 0) {
        _logService.info('FFmpegService', 'Vídeo gerado com sucesso: $outputPath');
        return true;
      } else {
        _logService.error('FFmpegService', 'Falha ao gerar vídeo. Código de retorno: $result');
        return false;
      }
    } catch (e, stackTrace) {
      _logService.exception('FFmpegService', 'Exceção ao gerar vídeo', stackTrace);
      return false;
    }
  }
}

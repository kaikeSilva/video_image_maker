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

  // CORRIGIDO: Método buildCommand() agora é síncrono e recebe a duração como parâmetro
  List<String> buildCommand({
    required String inputAudioPath,
    required List<Map<String, dynamic>> imageSequence,
    required String outputPath,
    required double audioDurationSeconds,
    Map<String, String>? customParams,
  }) {
    final params = Map<String, String>.from(_defaultEncodingParams);
    
    // Sobrescreve com parâmetros personalizados, se fornecidos
    if (customParams != null) {
      params.addAll(customParams);
    }

    _logService.info('FFmpegService', 'Construindo comando FFmpeg com duração: ${audioDurationSeconds}s');

    // Lista para armazenar o comando completo
    List<String> command = [];

    // Adiciona parâmetros para melhorar a estabilidade no Android
    command.addAll(['-threads', '2']);  // Limita o número de threads
    command.addAll(['-v', 'warning']);  // Reduz a verbosidade do log

    // Input de áudio primeiro
    command.addAll(['-i', inputAudioPath]);

    // Adicionar cada imagem como input com loop
    for (int i = 0; i < imageSequence.length; i++) {
      final item = imageSequence[i];
      final imagePath = item['imagePath'] as String;
      
      // Verifica se o caminho da imagem existe
      if (imagePath.isEmpty) {
        _logService.error('FFmpegService', 'Caminho de imagem inválido: $imagePath');
        continue;
      }
      
      // Adiciona input para cada imagem com loop
      command.addAll(['-loop', '1', '-i', imagePath]);
    }

    // Construir filtro complex
    List<String> filterParts = [];
    String currentLayer = 'base';
    
    // 1. Criar vídeo base preto com a duração do áudio
    filterParts.add('color=black:1280x720:duration=$audioDurationSeconds:rate=${params['frameRate']}[base]');
    
    // 2. Para cada imagem, criar overlay no tempo correto
    for (int i = 0; i < imageSequence.length; i++) {
      final item = imageSequence[i];
      final timestamp = (item['timestamp'] as int) / 1000.0; // Converter para segundos
      
      // Calcular duração de exibição desta imagem
      double duration;
      if (i < imageSequence.length - 1) {
        final nextTimestamp = (imageSequence[i + 1]['timestamp'] as int) / 1000.0;
        duration = nextTimestamp - timestamp;
      } else {
        // Última imagem: vai até o final do áudio
        duration = audioDurationSeconds - timestamp;
      }
      
      // Garantir que a duração não seja negativa ou zero
      if (duration <= 0) {
        duration = 5.0; // Duração mínima de 5 segundos
        _logService.warning('FFmpegService', 'Duração calculada <= 0 para imagem $i, usando 5s');
      }
      
      // Garantir que não ultrapasse o final do áudio
      final endTime = timestamp + duration;
      if (endTime > audioDurationSeconds) {
        duration = audioDurationSeconds - timestamp;
        _logService.info('FFmpegService', 'Ajustando duração da imagem $i para não ultrapassar áudio');
      }
      
      _logService.info('FFmpegService', 'Imagem $i: timestamp=${timestamp}s, duração=${duration}s');
      
      // Escalar e preparar a imagem
      filterParts.add('[${i + 1}:v]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2[img$i]');
      
      // Aplicar overlay com tempo específico
      final nextLayer = i == imageSequence.length - 1 ? 'outv' : 'layer${i + 1}';
      final overlayEndTime = timestamp + duration;
      
      filterParts.add('[$currentLayer][img$i]overlay=0:0:enable=\'between(t,$timestamp,$overlayEndTime)\'[$nextLayer]');
      currentLayer = nextLayer;
    }
    
    // Se não houver imagens, apenas criar um vídeo preto
    if (imageSequence.isEmpty) {
      filterParts.clear();
      filterParts.add('color=black:1280x720:duration=$audioDurationSeconds:rate=${params['frameRate']}[outv]');
      _logService.info('FFmpegService', 'Nenhuma imagem fornecida, criando vídeo preto');
    }
    
    // Adicionar filtro complex ao comando
    final filterComplex = filterParts.join(';');
    command.addAll(['-filter_complex', filterComplex]);
    
    // Mapear streams de saída
    command.addAll(['-map', '[outv]', '-map', '0:a']);
    
    // Adicionar parâmetros de codificação
    command.addAll([
      '-c:v', params['videoCodec']!,
      '-b:v', params['videoBitrate']!,
      '-c:a', params['audioCodec']!,
      '-b:a', params['audioBitrate']!,
      '-r', params['frameRate']!,
      '-preset', params['preset']!,
      '-pix_fmt', params['pixelFormat']!,
      '-t', audioDurationSeconds.toString(), // Definir duração explicitamente
      '-avoid_negative_ts', 'make_zero', // Evitar timestamps negativos
      '-y', // Sobrescrever arquivo de saída
      outputPath
    ]);

    _logService.info('FFmpegService', 'Comando FFmpeg construído com ${command.length} parâmetros');
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
      
      // Utiliza uma Completer para melhorar o gerenciamento do ciclo de vida do comando
      final completer = Completer<int>();
      
      try {
        // Use executeAsync instead of execute to prevent blocking the UI thread
        _currentSession = await FFmpegKit.executeAsync(commandStr, 
          (session) async {
            try {
              // This callback is called when the execution is completed
              final returnCode = await session.getReturnCode();
              final value = returnCode?.getValue() ?? -1;
              _logService.info('FFmpegService', 'Sessão FFmpeg completada com código: $value');
              
              // Só completa se ainda não tiver sido completado
              if (!completer.isCompleted) {
                completer.complete(value);
              }
            } catch (e) {
              _logService.error('FFmpegService', 'Erro no callback de conclusão: $e');
              if (!completer.isCompleted) {
                completer.complete(-1);
              }
            }
          },
          (log) {
            try {
              // This handles logs in real-time during execution
              final message = log.getMessage() ?? '';
              final level = log.getLevel();
              
              if (message.isNotEmpty) {
                if (level <= 16) { // AV_LOG_ERROR e abaixo
                  _logService.error('FFmpeg-Runtime', message);
                } else if (level <= 24) { // AV_LOG_WARNING
                  _logService.warning('FFmpeg-Runtime', message);
                } else if (level <= 32) { // AV_LOG_INFO
                  _logService.info('FFmpeg-Runtime', message);
                }
              }
            } catch (e) {
              _logService.error('FFmpegService', 'Erro no callback de log: $e');
            }
          },
          (stats) {
            try {
              // Verificar se as estatísticas são válidas antes de propagar
              final time = stats.getTime();
              
              // Registra valores para debug
              final frame = stats.getVideoFrameNumber();
              final fps = stats.getVideoFps();
              _logService.info('FFmpegService', 'Estatísticas: time=$time, frame=$frame, fps=$fps');
              
              // Só propaga estatísticas válidas para o callback
              if (time >= 0 && time < 24 * 60 * 60 * 1000) { // Limitar a 24 horas como segurança
                _progressCallback?.call(stats);
              } else {
                _logService.warning('FFmpegService', 'Ignorando estatística com valor de tempo inválido: $time');
              }
            } catch (e) {
              _logService.error('FFmpegService', 'Erro no callback de estatísticas: $e');
            }
          }
        );
        
        // Definir um timeout para o comando FFmpeg (10 minutos)
        Future.delayed(const Duration(minutes: 10), () {
          if (!completer.isCompleted) {
            _logService.error('FFmpegService', 'Timeout na execução do FFmpeg');
            FFmpegKit.cancel(); // Cancela a execução atual
            completer.complete(-1);
          }
        });
        
        // Aguardar a conclusão do comando
        return await completer.future;
      } catch (e) {
        _logService.error('FFmpegService', 'Erro ao executar FFmpeg de forma assíncrona: $e');
        if (!completer.isCompleted) {
          completer.complete(-1);
        }
        return -1;
      }
    } catch (e, stackTrace) {
      _logService.exception('FFmpegService', 'Exceção ao executar FFmpeg', stackTrace);
      return -1;
    }
  }
  
  // Cancela a execução atual do FFmpeg
  Future<bool> cancelExecution() async {
    _logService.info('FFmpegService', 'Tentando cancelar execução do FFmpeg');
    try {
      if (_currentSession != null) {
        await FFmpegKit.cancel();
        _logService.info('FFmpegService', 'Cancelamento solicitado com sucesso');
        return true;
      }
      return false;
    } catch (e) {
      _logService.error('FFmpegService', 'Erro ao cancelar execução: $e');
      return false;
    }
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
      
      try {
        // Usando um método mais robusto para obter a duração
        final session = await FFprobeKit.executeAsync('-v quiet -print_format json -show_format "$audioPath"');
        final returnCode = await session.getReturnCode();
        
        if (ReturnCode.isSuccess(returnCode)) {
          final output = await session.getOutput();
          
          if (output != null && output.isNotEmpty) {
            // Tenta extrair a duração do JSON de saída
            try {
              // Podemos usar regex para extrair a duração em vez de depender do parsing JSON
              final durationRegex = RegExp(r'"duration":\s*"([\d\.]+)"');
              final match = durationRegex.firstMatch(output);
              
              if (match != null && match.groupCount >= 1) {
                final durationStr = match.group(1);
                if (durationStr != null) {
                  final durationInSeconds = double.parse(durationStr);
                  final duration = Duration(milliseconds: (durationInSeconds * 1000).round());
                  _logService.info('FFmpegService', 'Duração do áudio: ${duration.inSeconds} segundos (${durationInSeconds}s)');
                  return duration;
                }
              }
              
              // Fallback para abordagem alternativa usando FFmpeg em vez de FFprobe
              _logService.warning('FFmpegService', 'Não foi possível extrair duração do JSON, tentando método alternativo');
              return await _getAudioDurationWithFFmpeg(audioPath);
            } catch (e) {
              _logService.error('FFmpegService', 'Erro ao processar JSON de duração: $e');
              return await _getAudioDurationWithFFmpeg(audioPath);
            }
          } else {
            _logService.warning('FFmpegService', 'FFprobe retornou saída vazia, tentando método alternativo');
            return await _getAudioDurationWithFFmpeg(audioPath);
          }
        } else {
          _logService.error('FFmpegService', 'FFprobe retornou erro, tentando método alternativo');
          return await _getAudioDurationWithFFmpeg(audioPath);
        }
      } catch (e) {
        _logService.warning('FFmpegService', 'Exceção ao usar FFprobe: $e, tentando método alternativo');
        return await _getAudioDurationWithFFmpeg(audioPath);
      }
    } catch (e, stackTrace) {
      _logService.exception('FFmpegService', 'Exceção ao obter duração do áudio: $e', stackTrace);
      return const Duration(seconds: 60); // Duração padrão em caso de erro
    }
  }
  
  // Método alternativo para obter duração usando FFmpeg
  Future<Duration> _getAudioDurationWithFFmpeg(String audioPath) async {
    try {
      _logService.info('FFmpegService', 'Usando FFmpeg para obter duração: $audioPath');
      
      // Cria arquivo temporário para receber a duração
      final tempDir = await io.Directory.systemTemp.createTemp('duration_');
      final tempOutputPath = '${tempDir.path}/duration.txt';
      
      try {
        // Executa o FFmpeg para obter a duração
        final command = [
          '-i', audioPath,
          '-f', 'null',
          '-y', '/dev/null'  // Descartar saída de vídeo/áudio
        ];
        
        final commandStr = command.join(' ');
        _logService.info('FFmpegService', 'Executando FFmpeg para duração: $commandStr');
        
        // Executa de forma síncrona para garantir obtenção da duração
        final session = await FFmpegKit.execute(commandStr);
        final returnCode = await session.getReturnCode();
        
        if (ReturnCode.isSuccess(returnCode) || returnCode?.getValue() == 1) {
          // FFmpeg geralmente retorna código 1 quando usado apenas para informações
          final logs = await session.getLogs();
          
          // Procura por "Duration:" nos logs
          final durationRegex = RegExp(r'Duration: (\d{2}):(\d{2}):(\d{2})\.(\d{2})');
          
          for (final log in logs) {
            final message = log.getMessage() ?? '';
            final match = durationRegex.firstMatch(message);
            
            if (match != null && match.groupCount >= 4) {
              final hours = int.parse(match.group(1)!);
              final minutes = int.parse(match.group(2)!);
              final seconds = int.parse(match.group(3)!);
              final centiseconds = int.parse(match.group(4)!);
              
              final durationMs = (hours * 3600 + minutes * 60 + seconds) * 1000 + centiseconds * 10;
              final duration = Duration(milliseconds: durationMs);
              
              _logService.info('FFmpegService', 'Duração obtida com FFmpeg: ${duration.inSeconds}s');
              return duration;
            }
          }
          
          _logService.warning('FFmpegService', 'Não foi possível encontrar a duração nos logs');
          return const Duration(seconds: 60); // Duração padrão
        } else {
          _logService.error('FFmpegService', 'Falha ao obter duração com FFmpeg');
          return const Duration(seconds: 60); // Duração padrão
        }
      } finally {
        // Limpa o diretório temporário
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          _logService.warning('FFmpegService', 'Não foi possível remover diretório temporário: $e');
        }
      }
    } catch (e) {
      _logService.error('FFmpegService', 'Erro no método alternativo de duração: $e');
      return const Duration(seconds: 60); // Duração padrão
    }
  }
  
  // OTIMIZADO: Método generateVideo() para lidar com problemas de codec MP3 no Android
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
      _logService.info('FFmpegService', 'Iniciando geração de vídeo');
      _logService.info('FFmpegService', 'Áudio: $inputAudioPath');
      _logService.info('FFmpegService', 'Saída: $outputPath');
      _logService.info('FFmpegService', 'Número de imagens: ${imageSequence.length}');
      
      // PRIMEIRO: Verificar se os arquivos de entrada existem
      final audioFile = io.File(inputAudioPath);
      if (!await audioFile.exists()) {
        _logService.error('FFmpegService', 'Arquivo de áudio não encontrado: $inputAudioPath');
        return false;
      }
      
      // Verificar se todas as imagens existem
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
      
      // SEGUNDO: Criar diretório temporário para arquivos intermediários
      final tempDir = await io.Directory.systemTemp.createTemp('video_maker_');
      final tempAudioPath = '${tempDir.path}/temp_audio.aac';  // Usando AAC em vez de WAV para melhor compatibilidade
      
      try {
        // TERCEIRO: Converter MP3 para AAC para evitar problemas de codec no Android
        _logService.info('FFmpegService', 'Convertendo MP3 para AAC para compatibilidade...');
        
        // Usar um comando simples para converter - evitando filtros complexos
        final convertCommand = [
          '-i', inputAudioPath,
          '-c:a', 'aac',         // Codec AAC (mais compatível com Android)
          '-b:a', '128k',        // Bitrate moderado
          '-ar', '44100',        // Taxa de amostragem padrão
          '-ac', '2',            // Canais estéreo
          '-strict', 'experimental',  // Para garantir compatibilidade
          '-y',                  // Sobrescrever arquivo de saída
          tempAudioPath
        ];
        
        final conversionResult = await executeCommand(convertCommand);
        if (conversionResult != 0) {
          _logService.error('FFmpegService', 'Falha ao converter o áudio para AAC');
          
          // PLANO B: Se a conversão falhar, tente usar diretamente o arquivo MP3
          _logService.warning('FFmpegService', 'Tentando usar o arquivo MP3 diretamente');
          
          // Usar duração fixa estimada se não conseguir determinar
          Duration audioDuration;
          try {
            audioDuration = await getAudioDuration(inputAudioPath);
            if (audioDuration.inMilliseconds <= 0) {
              audioDuration = const Duration(seconds: 60); // Duração padrão
            }
          } catch (e) {
            _logService.warning('FFmpegService', 'Erro ao obter duração: $e');
            audioDuration = const Duration(seconds: 60); // Duração padrão
          }
          
          final audioDurationSeconds = audioDuration.inMilliseconds / 1000.0;
          
          // GERAR VÍDEO MUDO APENAS COM AS IMAGENS (sem áudio)
          _logService.info('FFmpegService', 'Gerando vídeo sem áudio como fallback');
          final fallbackOutputPath = '${tempDir.path}/temp_video_no_audio.mp4';
          
          // Construir comando simplificado sem áudio
          final silentCommand = [
            '-f', 'lavfi',
            '-i', 'anullsrc=r=44100:cl=stereo',  // Fonte de áudio silenciosa
            '-t', audioDurationSeconds.toString(),  // Duração
          ];
          
          // Adicionar cada imagem como input
          for (int i = 0; i < imageSequence.length; i++) {
            final item = imageSequence[i];
            final imagePath = item['imagePath'] as String;
            silentCommand.addAll(['-loop', '1', '-i', imagePath]);
          }
          
          // Simplificar o filtro complexo para evitar problemas
          final params = customParams ?? {};
          final frameRate = params['frameRate'] ?? '24';
          
          // Filtro básico: apenas um slideshow simples
          List<String> filterParts = [];
          filterParts.add('color=black:1280x720:duration=$audioDurationSeconds:r=$frameRate[bg]');
          
          for (int i = 0; i < imageSequence.length; i++) {
            final item = imageSequence[i];
            final timestamp = (item['timestamp'] as int) / 1000.0;
            double duration = 5.0;  // Duração padrão
            
            if (i < imageSequence.length - 1) {
              final nextItem = imageSequence[i + 1];
              final nextTimestamp = (nextItem['timestamp'] as int) / 1000.0;
              duration = nextTimestamp - timestamp;
              if (duration <= 0) duration = 5.0;
            } else {
              duration = audioDurationSeconds - timestamp;
              if (duration <= 0) duration = 5.0;
            }
            
            if (timestamp + duration > audioDurationSeconds) {
              duration = audioDurationSeconds - timestamp;
            }
            
            // Adicionar imagem ao filtro com escala
            filterParts.add('[${i+1}]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2[img$i]');
          }
          
          // Adicionar os overlays
          String currentLayer = 'bg';
          for (int i = 0; i < imageSequence.length; i++) {
            final item = imageSequence[i];
            final timestamp = (item['timestamp'] as int) / 1000.0;
            double duration = 5.0;
            
            if (i < imageSequence.length - 1) {
              final nextItem = imageSequence[i + 1];
              final nextTimestamp = (nextItem['timestamp'] as int) / 1000.0;
              duration = nextTimestamp - timestamp;
              if (duration <= 0) duration = 5.0;
            } else {
              duration = audioDurationSeconds - timestamp;
              if (duration <= 0) duration = 5.0;
            }
            
            final endTime = timestamp + duration;
            final nextLayer = i == imageSequence.length - 1 ? 'out' : 'l$i';
            
            filterParts.add('[$currentLayer][img$i]overlay=0:0:enable=\'between(t,$timestamp,$endTime)\'[$nextLayer]');
            currentLayer = nextLayer;
          }
          
          // Completar o comando
          silentCommand.addAll([
            '-filter_complex', filterParts.join(';'),
            '-map', '[$currentLayer]',
            '-map', '0:a',
            '-c:v', 'libx264',
            '-preset', 'ultrafast',  // Prioriza velocidade sobre qualidade para evitar travamentos
            '-tune', 'stillimage',   // Otimizado para imagens estáticas
            '-crf', '23',            // Qualidade razoável
            '-c:a', 'aac',
            '-shortest',
            '-y',
            fallbackOutputPath
          ]);
          
          // Executar comando simplificado
          final fallbackResult = await executeCommand(silentCommand);
          
          if (fallbackResult != 0) {
            _logService.error('FFmpegService', 'Falha no plano B. Código: $fallbackResult');
            return false;
          }
          
          // Verificar se o arquivo foi gerado
          final fallbackFile = io.File(fallbackOutputPath);
          if (!await fallbackFile.exists()) {
            _logService.error('FFmpegService', 'Arquivo de saída do plano B não foi criado');
            return false;
          }
          
          // Copiar o arquivo para o destino final
          try {
            await fallbackFile.copy(outputPath);
            final outputFile = io.File(outputPath);
            if (await outputFile.exists()) {
              final fileSize = await outputFile.length();
              _logService.info('FFmpegService', 'Arquivo de saída criado (plano B) com tamanho: ${fileSize} bytes');
              return true;
            } else {
              _logService.error('FFmpegService', 'Falha ao copiar arquivo de plano B para destino final');
              return false;
            }
          } catch (e) {
            _logService.error('FFmpegService', 'Erro ao copiar arquivo de plano B: $e');
            return false;
          }
        }
        
        // Verificar se o arquivo AAC foi criado
        final tempAudioFile = io.File(tempAudioPath);
        if (!await tempAudioFile.exists()) {
          _logService.error('FFmpegService', 'Arquivo de áudio temporário não foi criado');
          return false;
        }
        
        // QUARTO: Obter duração do áudio AAC (operação assíncrona)
        final audioDuration = await getAudioDuration(tempAudioPath);
        final audioDurationSeconds = audioDuration.inMilliseconds / 1000.0;
        
        if (audioDurationSeconds <= 0) {
          _logService.error('FFmpegService', 'Duração do áudio inválida: ${audioDurationSeconds}s');
          return false;
        }
        
        // QUINTO: Verificar se o diretório de saída existe
        final outputDir = io.Directory(outputPath.substring(0, outputPath.lastIndexOf('/')));
        if (!await outputDir.exists()) {
          _logService.info('FFmpegService', 'Criando diretório de saída: ${outputDir.path}');
          await outputDir.create(recursive: true);
        }
        
        // SEXTO: Ordenar as imagens por timestamp para garantir ordem correta
        imageSequence.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
        
        // Log dos timestamps para debug
        for (int i = 0; i < imageSequence.length; i++) {
          final timestamp = (imageSequence[i]['timestamp'] as int) / 1000.0;
          _logService.info('FFmpegService', 'Imagem $i ordenada: timestamp=${timestamp}s');
        }
        
        // SÉTIMO: Construir comando FFmpeg simplificado (menos filtros complexos)
        List<String> command = [];
        
        // Comando básico com opções de segurança
        command.addAll([
          '-threads', '2',         // Menos threads para evitar sobrecarga
          '-v', 'warning',         // Menos logs
        ]);
        
        // Input de áudio
        command.addAll(['-i', tempAudioPath]);
        
        // Adicionar imagens
        for (int i = 0; i < imageSequence.length; i++) {
          final item = imageSequence[i];
          final imagePath = item['imagePath'] as String;
          command.addAll(['-loop', '1', '-i', imagePath]);
        }
        
        // Parâmetros de qualidade do customParams
        final params = Map<String, String>.from(_defaultEncodingParams);
        if (customParams != null) {
          params.addAll(customParams);
        }
        
        // Filtro simplificado para evitar problemas de memória
        List<String> filterParts = [];
        filterParts.add('color=black:1280x720:duration=$audioDurationSeconds:r=${params['frameRate']}[base]');
        
        // Preparar cada imagem
        for (int i = 0; i < imageSequence.length; i++) {
          filterParts.add('[${i+1}]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2[img$i]');
        }
        
        // Aplicar overlays com tempos específicos
        String currentLayer = 'base';
        for (int i = 0; i < imageSequence.length; i++) {
          final item = imageSequence[i];
          final timestamp = (item['timestamp'] as int) / 1000.0;
          
          // Calcular duração desta imagem
          double duration;
          if (i < imageSequence.length - 1) {
            final nextTimestamp = (imageSequence[i+1]['timestamp'] as int) / 1000.0;
            duration = nextTimestamp - timestamp;
          } else {
            duration = audioDurationSeconds - timestamp;
          }
          
          // Garantir duração válida
          if (duration <= 0) duration = 5.0;
          if (timestamp + duration > audioDurationSeconds) {
            duration = audioDurationSeconds - timestamp;
          }
          
          final nextLayer = (i == imageSequence.length - 1) ? 'outv' : 'layer$i';
          final overlayEndTime = timestamp + duration;
          
          filterParts.add('[$currentLayer][img$i]overlay=0:0:enable=\'between(t,$timestamp,$overlayEndTime)\'[$nextLayer]');
          currentLayer = nextLayer;
        }
        
        // Completar comando
        command.addAll([
          '-filter_complex', filterParts.join(';'),
          '-map', '[outv]',
          '-map', '0:a',
          '-c:v', params['videoCodec']!,
          '-preset', 'ultrafast',     // Prioriza velocidade sobre qualidade
          '-crf', '25',               // Qualidade levemente reduzida para melhorar performance
          '-pix_fmt', 'yuv420p',
          '-c:a', 'copy',             // Copiar áudio sem recodificar
          '-shortest',
          '-max_muxing_queue_size', '1024',  // Aumenta o buffer para evitar problemas
          '-y',
          outputPath
        ]);
        
        // OITAVO: Executar comando FFmpeg
        final result = await executeCommand(command);
        
        if (result == 0) {
          _logService.info('FFmpegService', 'Vídeo gerado com sucesso: $outputPath');
          
          // Verificar se o arquivo foi realmente criado
          final outputFile = io.File(outputPath);
          if (await outputFile.exists()) {
            final fileSize = await outputFile.length();
            _logService.info('FFmpegService', 'Arquivo de saída criado com tamanho: ${fileSize} bytes');
            return true;
          } else {
            _logService.error('FFmpegService', 'Arquivo de saída não foi criado');
            return false;
          }
        } else {
          _logService.error('FFmpegService', 'Falha ao gerar vídeo. Código de retorno: $result');
          return false;
        }
      } finally {
        // NONO: Limpeza - remover arquivos temporários independente do resultado
        try {
          await tempDir.delete(recursive: true);
          _logService.info('FFmpegService', 'Arquivos temporários removidos');
        } catch (e) {
          _logService.warning('FFmpegService', 'Não foi possível remover arquivos temporários: $e');
        }
      }
    } catch (e, stackTrace) {
      _logService.exception('FFmpegService', 'Exceção ao gerar vídeo', stackTrace);
      return false;
    }
  }
}
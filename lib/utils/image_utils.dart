import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../models/image_sequence_item.dart';
import '../services/log_service.dart';

/// Utilitários para processamento de imagens
class ImageUtils {
  static final LogService _logService = LogService();

  /// Encontra a imagem correspondente ao tempo atual
  static ImageSequenceItem findImageForTime(List<ImageSequenceItem> imageSequence, double currentTimeInSeconds) {
    // Por padrão, usa a primeira imagem
    ImageSequenceItem currentImage = imageSequence.first;
    
    // Procura a imagem que deve ser exibida no tempo atual
    for (int j = 0; j < imageSequence.length; j++) {
      // Se encontrou uma imagem que começa depois do tempo atual, usa a anterior
      if (j > 0 && imageSequence[j].startTimeInSeconds > currentTimeInSeconds) {
        currentImage = imageSequence[j - 1];
        break;
      }
      // Se é a última imagem ou se o tempo atual está entre esta imagem e a próxima
      else if (j == imageSequence.length - 1 || 
          (imageSequence[j].startTimeInSeconds <= currentTimeInSeconds && 
           imageSequence[j + 1].startTimeInSeconds > currentTimeInSeconds)) {
        currentImage = imageSequence[j];
        break;
      }
    }
    
    return currentImage;
  }

  /// Carrega as imagens da sequência como objetos ui.Image
  static Future<List<ui.Image>> loadImages(List<ImageSequenceItem> imageSequence) async {
    List<ui.Image> images = [];
    
    for (var item in imageSequence) {
      final File imageFile = File(item.imagePath);
      if (!imageFile.existsSync()) {
        throw Exception('Imagem não encontrada: ${item.imagePath}');
      }
      
      final Uint8List bytes = await imageFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      
      images.add(frameInfo.image);
    }
    
    return images;
  }

  /// Gera um frame de vídeo a partir de uma imagem
  static Future<Uint8List?> generateVideoFrame(ui.Image image, int width, int height) async {
    try {
      // Cria um recorder para desenhar a imagem
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Paint paint = Paint();
      
      // Desenha um fundo preto
      paint.color = Colors.black;
      canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paint);
      
      // Verifica se estamos no formato desktop (16:9) ou mobile (9:16)
      bool isDesktopFormat = width > height;
      
      // Determina a estratégia de escala com base no formato
      double scaleX = width / image.width;
      double scaleY = height / image.height;
      
      // Estratégia de escala: 
      // - Para formato desktop (16:9): preservar a altura e ajustar a largura
      // - Para formato mobile (9:16): preservar a largura e ajustar a altura
      double scale;
      if (isDesktopFormat) {
        // No formato desktop, usamos a menor escala para garantir que a imagem caiba na largura
        scale = scaleX < scaleY ? scaleX : scaleY;
      } else {
        // No formato mobile, usamos a maior escala para garantir que a imagem preencha o frame
        scale = scaleX > scaleY ? scaleX : scaleY;
      }
      
      // Calcula o tamanho da imagem escalada
      double scaledWidth = image.width * scale;
      double scaledHeight = image.height * scale;
      
      // Calcula a posição para centralizar a imagem
      double offsetX = (width - scaledWidth) / 2;
      double offsetY = (height - scaledHeight) / 2;
      
      _logService.info('ImageUtils', 'Gerando frame: formato=${isDesktopFormat ? "desktop" : "mobile"}, ' +
          'dimensões=$width x $height, escala=$scale, ' +
          'imagem escalada=${scaledWidth.toInt()} x ${scaledHeight.toInt()}');
      
      // Desenha a imagem centralizada e escalada
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight),
        paint,
      );
      
      // Converte o canvas para uma imagem
      final ui.Picture picture = recorder.endRecording();
      final ui.Image renderedImage = await picture.toImage(width, height);
      
      // Converte a imagem para bytes RGBA
      final ByteData? byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      final Uint8List? result = byteData?.buffer.asUint8List();
      
      // Verifica se os dados da imagem foram gerados corretamente
      if (result == null || result.isEmpty) {
        _logService.warning('ImageUtils', 'Falha ao gerar dados de imagem RGBA');
      }
      
      return result;
    } catch (e) {
      _logService.error('ImageUtils', 'Erro ao gerar frame de vídeo: $e');
      return null;
    }
  }
}

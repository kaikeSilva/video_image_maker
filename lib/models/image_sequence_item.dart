/// Modelo para representar um item de sequência de imagens para geração de vídeo
/// 
/// Contém o caminho da imagem e o tempo de início em segundos
class ImageSequenceItem {
  /// Caminho do arquivo de imagem
  final String imagePath;
  
  /// Tempo de início em segundos
  final double startTimeInSeconds;
  
  /// Construtor
  ImageSequenceItem({
    required this.imagePath,
    required this.startTimeInSeconds,
  });
  
  @override
  String toString() {
    return 'ImageSequenceItem(imagePath: $imagePath, startTimeInSeconds: $startTimeInSeconds)';
  }
}

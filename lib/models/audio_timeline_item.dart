class AudioTimelineItem {
  String imagePath;
  Duration timestamp;
  Duration displayDuration;

  AudioTimelineItem({
    required this.imagePath,
    required this.timestamp,
    this.displayDuration = const Duration(seconds: 5),
  });
  
  // Método para criar uma cópia com valores atualizados
  AudioTimelineItem copyWith({
    String? imagePath,
    Duration? timestamp,
    Duration? displayDuration,
  }) {
    return AudioTimelineItem(
      imagePath: imagePath ?? this.imagePath,
      timestamp: timestamp ?? this.timestamp,
      displayDuration: displayDuration ?? this.displayDuration,
    );
  }
}

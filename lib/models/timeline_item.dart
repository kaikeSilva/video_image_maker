class TimelineItem {
  final String imagePath;
  final int timestamp; // Timestamp em milissegundos

  TimelineItem({
    required this.imagePath,
    required this.timestamp,
  });

  // Método para criar um TimelineItem a partir de um mapa
  factory TimelineItem.fromMap(Map<String, dynamic> map) {
    return TimelineItem(
      imagePath: map['imagePath'] as String,
      timestamp: map['timestamp'] as int,
    );
  }

  // Método para converter um TimelineItem para um mapa
  Map<String, dynamic> toMap() {
    return {
      'imagePath': imagePath,
      'timestamp': timestamp,
    };
  }
}

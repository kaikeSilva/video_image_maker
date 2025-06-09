import 'audio_timeline_item.dart';

class Project {
  String name;
  String? audioFilePath;
  String? audioFileName;
  Duration? audioDuration;
  List<AudioTimelineItem> timelineItems;

  Project({
    required this.name,
    this.audioFilePath,
    this.audioFileName,
    this.audioDuration,
    this.timelineItems = const [],
  });
}

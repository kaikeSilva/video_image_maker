import 'package:flutter/foundation.dart';
import '../models/project.dart';
import '../models/audio_timeline_item.dart';

class ProjectProvider extends ChangeNotifier {
  Project _project = Project(name: 'New Project');

  Project get project => _project;

  void setProject(Project project) {
    _project = project;
    notifyListeners();
  }

  void updateProjectName(String name) {
    _project.name = name;
    notifyListeners();
  }

  void setAudioFile(String filePath, String fileName, Duration duration) {
    _project.audioFilePath = filePath;
    _project.audioFileName = fileName;
    _project.audioDuration = duration;
    notifyListeners();
  }

  void addTimelineItem(AudioTimelineItem item) {
    _project.timelineItems = [..._project.timelineItems, item];
    notifyListeners();
  }

  void removeTimelineItem(int index) {
    if (index >= 0 && index < _project.timelineItems.length) {
      final newList = List<AudioTimelineItem>.from(_project.timelineItems);
      newList.removeAt(index);
      _project.timelineItems = newList;
      notifyListeners();
    }
  }

  void updateTimelineItem(int index, AudioTimelineItem item) {
    if (index >= 0 && index < _project.timelineItems.length) {
      final newList = List<AudioTimelineItem>.from(_project.timelineItems);
      newList[index] = item;
      _project.timelineItems = newList;
      notifyListeners();
    }
  }
}

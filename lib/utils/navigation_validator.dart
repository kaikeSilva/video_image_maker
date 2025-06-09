import '../providers/project_provider.dart';

class NavigationValidator {
  static bool canAccessImageSelection(ProjectProvider projectProvider) {
    return projectProvider.project.audioFilePath != null;
  }
  
  static bool canAccessEditor(ProjectProvider projectProvider) {
    return projectProvider.project.audioFilePath != null;
  }
  
  static bool canAccessPreview(ProjectProvider projectProvider) {
    return projectProvider.project.audioFilePath != null && 
           projectProvider.project.timelineItems.isNotEmpty;
  }
}

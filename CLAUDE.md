# CLAUDE.md - Video Maker Flutter Project Guide

## Project Scope
This app creates videos from audio files and images. Users upload an MP3 audio file, select multiple images, and place images at specific timestamps in the audio timeline. The app then generates a video combining the audio with images displayed at their assigned positions. Features include audio playback, timeline editing, preview functionality, and video export with FFmpeg.

## Build and Test Commands
- Run app: `flutter run`
- Build for release: `flutter build apk` or `flutter build ios`
- Run tests: `flutter test`
- Run specific test: `flutter test test/widget_test.dart`
- Check code quality: `flutter analyze`
- Format code: `flutter format lib/`

## Code Style Guidelines
- Use named parameters with required annotation for non-optional parameters
- Prefer const constructors when possible: `const MyWidget()`
- Import order: dart, flutter, third-party, relative
- Use camelCase for variables/methods, PascalCase for classes
- Nullable types marked with `?` (String?, int?)
- Error handling: Use try/catch blocks and handle error states in UI
- State management: Provider pattern for app state
- Create immutable collections when updating state (use [...list] or List.from())
- Widget structure: Props at top, private methods next, build method last
- Use MediaQuery or LayoutBuilder for responsive designs

## Project Structure
Models define data structures, Providers manage state, Screens contain pages, and Widgets are reusable UI components. Key components include audio player, timeline editor, and video generation service using FFmpeg.
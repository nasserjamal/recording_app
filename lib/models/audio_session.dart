import 'package:recording_app/models/audio_file.dart';

class AudioSession {
  String sessionId;
  List<AudioFile>? audioFiles;
  String sessionPath = '';

  AudioSession({required this.sessionId, this.audioFiles}) {
    audioFiles ??= [];
  }

  // Convert an AudioSession object to a Map
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'audioFiles': audioFiles!.map((file) => file.toJson()).toList(),
    };
  }

  // Create an AudioSession object from a Map
  factory AudioSession.fromJson(Map<String, dynamic> json) {
    return AudioSession(
      sessionId: json['sessionId'],
      audioFiles: (json['audioFiles'] as List)
          .map((fileJson) => AudioFile.fromJson(fileJson))
          .toList(),
    );
  }

  void addAudioFile(String filePath) {
    audioFiles!.add(AudioFile(filePath: filePath, isUploaded: false));
  }

  void setSessionPath(String path) {
    sessionPath = path;
  }
}

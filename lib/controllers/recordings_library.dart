import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:recording_app/models/audio_file.dart';
import 'package:recording_app/models/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordingsLibrary {
  // Private constructor
  RecordingsLibrary._privateConstructor() {
    _loadAudioSessions();
  }

  // Singleton instance
  static final RecordingsLibrary _instance =
      RecordingsLibrary._privateConstructor();

  // Factory constructor to return the singleton instance
  factory RecordingsLibrary() {
    return _instance;
  }

  // Add your methods and properties here
  final String _recordingFolder = 'recordings';
  String? _recordingPath;
  List<AudioSession> _audioSessions = []; //  A list of audio sessions

  List<AudioSession> get audioSessions => _audioSessions;

  Future<String> getAudioPath() async {
    if (_recordingPath != null) {
      return _recordingPath!;
    }
    Directory? externalDir = await getApplicationDocumentsDirectory();
    _recordingPath = '${externalDir.path}/$_recordingFolder';
    return _recordingPath!;
  }

  // Method to add a new audio session
  void addAudioSession(AudioSession session) {
    _audioSessions.add(session);
    _saveAudioSessions();
  }

  // Method to load audio sessions from SharedPreferences
  Future<void> _loadAudioSessions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('audioSessions');
    if (jsonString != null) {
      List<dynamic> jsonList = jsonDecode(jsonString);
      _audioSessions =
          jsonList.map((json) => AudioSession.fromJson(json)).toList();
    }
  }

  // Method to save audio sessions to SharedPreferences
  Future<void> _saveAudioSessions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> jsonList =
        _audioSessions.map((session) => session.toJson()).toList();
    String jsonString = jsonEncode(jsonList);
    await prefs.setString('audioSessions', jsonString);
  }

  Future deleteAudioFile(String sessionId, AudioFile file) async {
    // Find the session by sessionId
    AudioSession? session = _audioSessions.firstWhere(
      (s) => s.sessionId == sessionId,
    );

    // Remove the file from the session's audio files
    session.audioFiles!.remove(file);

    if (session.audioFiles!.isEmpty) {
      // Remove the session if it has no audio files
      _audioSessions.remove(session);
    }

    // Delete the file from the filesystem
    File audioFile = File(file.filePath);
    if (await audioFile.exists()) {
      await audioFile.delete();
    }
    // Save the updated audio sessions
    _saveAudioSessions();
  }
}

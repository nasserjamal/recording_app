import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';

// Add your widget code here
// vvvvvvvvvvvvvvvvvvvvvvvvv

// Define the RecordingStatus enum
enum RecordingStatus { playing, idle, paused }

class RecordingNotifier extends ChangeNotifier {
  AudioSession? _session;
  int _timer = 0;
  RecordingStatus _status = RecordingStatus.idle;
  Timer? _ticker;

  // Getter for timer
  int get timer => _timer;

  // Getter for status
  RecordingStatus get status => _status;

  // Start audio recording
  void startRecording() async {
    if (status != RecordingStatus.idle) {
      // TODO: Handle error
      debugPrint("*************Error: Recording already in progress");
      return;
    }

    try {
      _session = AudioSession(
          sessionId: DateTime.now().millisecondsSinceEpoch.toString());
      _session!.setSessionPath(
          "${await RecordingsLibrary().getAudioPath()}/${_session!.sessionId}");
      await setupAudioPath(_session!.sessionPath);
      await AudioManager().startRecording(_session!.sessionPath);

      // Listen to the audio stream and save the audio chunk file path
      AudioManager().audioStream.listen((chunk) {
        _saveChunk(chunk);
      });

      // start timer
      _resumeTimer();
      RecordingsLibrary().addAudioSession(_session!);
      _status = RecordingStatus.playing;
      notifyListeners();
    } catch (e) {
      // TODO: Handle error
      debugPrint("*************Error: $e");
    }
  }

  void pauseRecording() {
    if (_status != RecordingStatus.playing) {
      // TODO: Handle error
      debugPrint("*************Error: Recording not in progress");
    }

    try {
      AudioManager().pauseRecording();
      _stopTimer();
      _status = RecordingStatus.paused;
      notifyListeners();
    } catch (e) {
      // TODO: Handle error
      debugPrint("*************Error: $e");
    }
  }

  void resumeRecording() {
    if (_status != RecordingStatus.paused) {
      // TODO: Handle error
      debugPrint("*************Error: Recording not paused");
    }

    try {
      AudioManager().resumeRecording();
      _resumeTimer();
      _status = RecordingStatus.playing;
      notifyListeners();
    } catch (e) {
      // TODO: Handle error
      debugPrint("*************Error: $e");
    }
  }

  void stopRecording() {
    if (_status != RecordingStatus.playing &&
        _status != RecordingStatus.paused) {
      // TODO: Handle error
      debugPrint("*************Error: Recording not in progress");
    }

    try {
      AudioManager().stopRecording();
      _stopTimer();
      _timer = 0;
      _status = RecordingStatus.idle;
      notifyListeners();
    } catch (e) {
      // TODO: Handle error
      debugPrint("*************Error: $e");
    }
  }

  // Helper methods

  // Count up timer. kep track of the time welapsed
  void _resumeTimer() {
    // Prevent multiple timers from running
    if (_ticker != null || _status == RecordingStatus.playing) return;

    // Create a new Timer that ticks every second
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      _timer++;
      notifyListeners();
    });
  }

  void _stopTimer() {
    if (_ticker == null) return;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  // Method to reset all attributes
  void _reset() {
    _stopTimer();
    _session = null;
    _timer = 0;
    _status = RecordingStatus.idle;
    notifyListeners(); // Notify listeners of the reset
  }

  void _saveChunk(String newFilePath) {
    _session!.addAudioFile(newFilePath);
  }

  // Ensure that the audio directory exists. If not create it
  Future<String> setupAudioPath(String audioDir) async {
    Directory dir = Directory(audioDir);
    if (!await dir.exists()) {
      try {
        await dir.create(recursive: true);
      } catch (e) {
        throw Exception('Error creating storage directory: $e');
      }
    }
    return audioDir;
  }
}

// ************************************* Helper classes *************************************

//  Audio Manager class

enum RecordingState {
  idle,
  recording,
  paused,
}

class AudioManager {
  // Private constructor
  AudioManager._privateConstructor();

  // Singleton instance
  static final AudioManager _instance = AudioManager._privateConstructor();

  // Factory constructor to return the singleton instance
  factory AudioManager() {
    return _instance;
  }

  // class attributes
  final _record = AudioRecorder();
  final List<int> _buffer = []; // buffer to store audio chunks
  final StreamController<String> _pathStreamController =
      StreamController<String>();
  Stream<String> get audioStream => _pathStreamController.stream;
  Timer? _ticker;
  int maxRecordingChunk = 300; // in seconds
  String _audioDir = '';
  DateTime chunkStartTime = DateTime.now();
  int remainingChunkDuration = 0;

  // start recording
  Future startRecording(String audioDir) async {
    _audioDir = audioDir;
    remainingChunkDuration = maxRecordingChunk;
    try {
      if (await _record.hasPermission()) {
        final stream = await _record
            .startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits));
        _startTicker();
        stream.listen((chunk) {
          _buffer.addAll(chunk);
        });
      } else {
        throw Exception('Permission denied');
      }
    } catch (e) {
      throw ('Error starting recording: $e');
    }
  }

  // stop recording
  Future stopRecording() async {
    await _record.isRecording().then((isRecording) async {
      if (isRecording) {
        _saveToFile();
        stopTicker();
        await _record.stop();
        await _record.dispose();
        await _pathStreamController.close();
      }
    });
  }

  void pauseRecording() async {
    await _record.isRecording().then((isRecording) {
      if (isRecording) {
        _record.pause();
        stopTicker();
        remainingChunkDuration = maxRecordingChunk -
            DateTime.now().difference(chunkStartTime).inSeconds;
      }
    });
  }

  void resumeRecording() async {
    await _record.isPaused().then((isPaused) {
      if (isPaused) {
        _record.resume();
        _startTicker();
      }
    });
  }

  void dispose() {
    _record.dispose();
  }

  void _startTicker() {
    _ticker =
        Timer.periodic(Duration(seconds: remainingChunkDuration), (_) async {
      if (_buffer.isNotEmpty) {
        chunkStartTime = DateTime.now();
        await _saveToFile();
      }
    });
  }

  void stopTicker() {
    _ticker?.cancel();
  }

  Future<void> _saveToFile() async {
    final filePath = '$_audioDir/${DateTime.now().millisecondsSinceEpoch}.wav';
    await saveAsWav(Uint8List.fromList(_buffer), filePath, 44100, 2);
    _buffer.clear();
    _pathStreamController.add(filePath);
  }

  Future<void> saveAsWav(Uint8List pcmBytes, String wavFilePath, int sampleRate,
      int channels) async {
    final header = createWavHeader(
      totalAudioLen: pcmBytes.length,
      sampleRate: sampleRate,
      channels: channels,
      bitDepth: 16,
    );

    final wavFile = File(wavFilePath);
    await wavFile.writeAsBytes([...header, ...pcmBytes]);
  }

  List<int> createWavHeader({
    required int totalAudioLen,
    required int sampleRate,
    required int channels,
    required int bitDepth,
  }) {
    int byteRate = sampleRate * channels * (bitDepth ~/ 8);
    int blockAlign = channels * (bitDepth ~/ 8);

    List<int> header = [];

    // "RIFF" chunk descriptor
    header.addAll(utf8.encode('RIFF'));
    header.addAll(_intToBytes(36 + totalAudioLen, 4)); // File size
    header.addAll(utf8.encode('WAVE'));

    // "fmt " sub-chunk
    header.addAll(utf8.encode('fmt '));
    header.addAll(_intToBytes(16, 4)); // Subchunk1Size
    header.addAll(_intToBytes(1, 2)); // AudioFormat (PCM)
    header.addAll(_intToBytes(channels, 2)); // NumChannels
    header.addAll(_intToBytes(sampleRate, 4)); // SampleRate
    header.addAll(_intToBytes(byteRate, 4)); // ByteRate
    header.addAll(_intToBytes(blockAlign, 2)); // BlockAlign
    header.addAll(_intToBytes(bitDepth, 2)); // BitsPerSample

    // "data" sub-chunk
    header.addAll(utf8.encode('data'));
    header.addAll(_intToBytes(totalAudioLen, 4)); // Data chunk size

    return header;
  }

  List<int> _intToBytes(int value, int length) {
    List<int> bytes = [];
    for (int i = 0; i < length; i++) {
      bytes.add((value >> (8 * i)) & 0xFF);
    }
    return bytes;
  }
}

// Recordings Library class

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

// ************************************* Models *************************************

// AudioFile model
class AudioFile {
  String filePath;
  bool isUploaded;

  AudioFile({required this.filePath, required this.isUploaded});

  // Convert an AudioFile object to a Map
  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'isUploaded': isUploaded,
    };
  }

  // Create an AudioFile object from a Map
  factory AudioFile.fromJson(Map<String, dynamic> json) {
    return AudioFile(
      filePath: json['filePath'],
      isUploaded: json['isUploaded'],
    );
  }
}

// AudioSession model
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

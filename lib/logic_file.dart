import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

// Add your widget code here
// vvvvvvvvvvvvvvvvvvvvvvvvv

// Define the RecordingStatus enum
enum RecordingStatus { playing, idle, paused }

class RecordingNotifier extends ChangeNotifier {
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
      start();
      _resumeTimer();
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
      stop();
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
    _timer = 0;
    _status = RecordingStatus.idle;
    notifyListeners(); // Notify listeners of the reset
  }
}

// ************************************* Helper classes *************************************

// ************************************* Recording serviceManager *************************************
// Managed creation and disposal of the audio manager

class RecordingServiceManager {
  // Private constructor
  RecordingServiceManager._privateConstructor();

  // Singleton instance
  static final RecordingServiceManager _instance =
      RecordingServiceManager._privateConstructor();

  // Factory constructor to return the singleton instance
  factory RecordingServiceManager() {
    return _instance;
  }

  // class attributes
  AudioSession? _session;

  void startRecording() async {
    _session = AudioSession(
        sessionId: DateTime.now().millisecondsSinceEpoch.toString());
    _session!.setSessionPath(
        "${await RecordingsLibrary().getAudioPath()}/${_session!.sessionId}");
    await _setupAudioPath(_session!.sessionPath);
    await AudioManager().startRecording(_session!.sessionPath);
    // Listen to the audio stream and save the audio chunk file path
    AudioManager().audioStream.listen((chunk) {
      _saveChunk(chunk);
    });

    // start timer
    RecordingsLibrary().addAudioSession(_session!);
  }

  void _saveChunk(String newFilePath) {
    _session!.addAudioFile(newFilePath);
    RecordingsLibrary().saveAudioSessions();
  }

  // Ensure that the audio directory exists. If not create it
  Future<String> _setupAudioPath(String audioDir) async {
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
  int maxRecordingChunk = 10; // in seconds
  String _audioDir = '';
  DateTime chunkStartTime = DateTime.now();
  int remainingChunkDuration = 0;

  // start recording
  Future startRecording(String audioDir) async {
    _audioDir = audioDir;
    remainingChunkDuration = maxRecordingChunk;
    try {
      final stream = await _record
          .startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits));
      _startTicker();
      stream.listen((chunk) {
        _buffer.addAll(chunk);
      });
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
    print("Start ticker");
    _ticker =
        Timer.periodic(Duration(seconds: remainingChunkDuration), (_) async {
      print("Timer ticked");
      if (_buffer.isNotEmpty) {
        chunkStartTime = DateTime.now();
        print("Buffer is not empty");
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
    print("Now trying to save file to $filePath");
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
    loadAudioSessions();
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
    saveAudioSessions();
  }

  // Method to load audio sessions from SharedPreferences
  Future<void> loadAudioSessions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('audioSessions');
    print("****************Loaded $jsonString");
    if (jsonString != null) {
      List<dynamic> jsonList = jsonDecode(jsonString);
      _audioSessions =
          jsonList.map((json) => AudioSession.fromJson(json)).toList();
    }
  }

  // Method to save audio sessions to SharedPreferences
  Future<void> saveAudioSessions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> jsonList =
        _audioSessions.map((session) => session.toJson()).toList();
    String jsonString = jsonEncode(jsonList);
    print("Check here, now saving $jsonString");
    await prefs.setString('audioSessions', jsonString);
  }

  void clearAudioSessions() {
    _audioSessions.clear();
    saveAudioSessions();
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
    saveAudioSessions();
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

// ************************************* Flutter foreground *************************************

void initForegroundTasks() {
  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'record_service',
      channelName: 'Record Service',
      channelImportance: NotificationChannelImportance.MAX,
      priority: NotificationPriority.MAX,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

void _onReceiveTaskData(Object data) {
  if (data == 'stop') {
    stop();
  }
}

Future<void> stop() async {
  if (Platform.isAndroid) {
    final ServiceRequestResult result =
        await FlutterForegroundTask.stopService();

    if (result is ServiceRequestFailure) {
      throw result.error;
    }
  } else {
    AudioManager().stopRecording();
  }
}

const String _kStopAction = 'action.stop';

@pragma('vm:entry-point')
void startRecordService() {
  FlutterForegroundTask.setTaskHandler(RecordServiceHandler());
}

class RecordServiceHandler extends TaskHandler {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _startRecorder();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // not use
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _stopRecorder();
  }

  @override
  void onNotificationButtonPressed(String id) async {
    if (id == _kStopAction) {
      FlutterForegroundTask.sendDataToMain('stop');
    }
  }

  Future<void> _startRecorder() async {
    // create record directory
    // final Directory supportDir = await getApplicationSupportDirectory();
    // final Directory recordDir = Directory(p.join(supportDir.path, "record"));
    // await recordDir.create(recursive: true);

    // // determine file path
    // final String currTime = DateFormat("aud_").format(DateTime.now());
    // final String filePath = p.join(recordDir.path, '$currTime.m4a');

    // // start recorder
    // await _recorder.start(const RecordConfig(), path: filePath);

    RecordingServiceManager().startRecording();

    // create stop action button
    FlutterForegroundTask.updateService(
      notificationText: 'recording..',
      notificationButtons: [
        const NotificationButton(id: _kStopAction, text: 'stop'),
      ],
    );
  }

  Future<void> _stopRecorder() async {
    // stop recorder
    await _recorder.stop();
    await _recorder.dispose();
  }
}

Future<void> start() async {
  await _requestNotificationPermission();
  await _requestRecordPermission();

  if (Platform.isAndroid) {
    final ServiceRequestResult result =
        await FlutterForegroundTask.startService(
      serviceId: 300,
      notificationTitle: 'Record Service',
      notificationText: '',
      callback: startRecordService,
    );

    if (result is ServiceRequestFailure) {
      throw result.error;
    }
  } else {
    RecordingServiceManager().startRecording();
  }
}

Future<void> stopRecording() async {
  if (Platform.isAndroid) {
    final ServiceRequestResult result =
        await FlutterForegroundTask.stopService();

    if (result is ServiceRequestFailure) {
      throw result.error;
    }
  } else {
    AudioManager().stopRecording();
  }
}

Future<void> _requestNotificationPermission() async {
  // Android 13+, you need to allow notification permission to display foreground service notification.
  //
  // iOS: If you need notification, ask for permission.
  final NotificationPermission notificationPermission =
      await FlutterForegroundTask.checkNotificationPermission();
  if (notificationPermission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }
}

Future<void> _requestRecordPermission() async {
  if (!await AudioRecorder().hasPermission()) {
    throw Exception(
        'To start record service, you must grant microphone permission.');
  }
}

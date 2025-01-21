import 'dart:io';
import 'package:record/record.dart';

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

  // start recording
  Future<String> startRecording(String audioDir) async {
    String filePath = '';
    try {
      if (await _record.hasPermission()) {
        String audioPath = await setupAudioPath(audioDir);
        String currentTimestamp =
            DateTime.now().millisecondsSinceEpoch.toString();
        filePath = '$audioPath/$currentTimestamp.aac';
        await _record.start(const RecordConfig(), path: filePath);
      } else {
        throw Exception('Permission denied');
      }
    } catch (e) {
      throw ('Error starting recording: $e');
    }
    return filePath;
  }

  // stop recording
  Future stopRecording() async {
    await _record.isRecording().then((isRecording) {
      if (isRecording) {
        _record.stop();
        _record.dispose();
      }
    });
  }

  void pauseRecording() async {
    print("My message: Pausing recording");
    await _record.isRecording().then((isRecording) {
      if (isRecording) {
        print("My message: Pausing recording 12");
        _record.pause();
      }
    });
  }

  void resumeRecording() async {
    await _record.isPaused().then((isPaused) {
      if (isPaused) {
        _record.resume();
      }
    });
  }

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

  // Future<void> listStorageContents() async {
  //   try {
  //     Directory? externalDir = await getExternalStorageDirectory();
  //     if (externalDir != null) {
  //       String externalPath = externalDir.path;
  //       Directory dir = Directory(externalPath);
  //       List<FileSystemEntity> files = dir.listSync();
  //       for (var file in files) {
  //         print(file.path);
  //       }
  //     } else {
  //       print('Could not get external storage directory');
  //     }
  //   } catch (e) {
  //     print('Error listing storage contents: $e');
  //   }
  // }
}

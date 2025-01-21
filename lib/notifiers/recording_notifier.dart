import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:recording_app/controllers/audio_manager.dart';
import 'package:recording_app/controllers/recordings_library.dart';
import 'package:recording_app/models/audio_session.dart';

// Define the RecordingStatus enum
enum RecordingStatus { playing, idle, paused }

class RecordingNotifier extends ChangeNotifier {
  AudioSession? _session;
  int _timer = 0;
  int _chunkTimer = 0;
  RecordingStatus _status = RecordingStatus.idle;
  Timer? _ticker;
  int maxRecordingChunk = 60; // in seconds

  // Getter for timer
  int get timer => _timer;

  // Getter for status
  RecordingStatus get status => _status;

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
      String filePath =
          await AudioManager().startRecording(_session!.sessionPath);

      _session!.addAudioFile(filePath);
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
      _chunkTimer = 0;
      _status = RecordingStatus.idle;
      notifyListeners();
    } catch (e) {
      // TODO: Handle error
      debugPrint("*************Error: $e");
    }
  }

  // Helper methods

  void _resumeTimer() {
    // Prevent multiple timers from running
    if (_ticker != null || _status == RecordingStatus.playing) return;

    // Create a new Timer that ticks every second
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      _timer++;
      _chunkTimer++;
      if (_chunkTimer >= maxRecordingChunk) {
        _chunkTimer = 0;
        await AudioManager().stopRecording();
        String filePath =
            await AudioManager().startRecording(_session!.sessionPath);
        _session!.addAudioFile(filePath);
      }
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
    _chunkTimer = 0;
    _status = RecordingStatus.idle;
    notifyListeners(); // Notify listeners of the reset
  }
}

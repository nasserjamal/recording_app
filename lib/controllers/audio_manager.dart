import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
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
  final List<int> _buffer = [];
  final StreamController<String> _pathStreamController =
      StreamController<String>();
  Stream<String> get audioStream => _pathStreamController.stream;
  Timer? _ticker;
  int maxRecordingChunk = 10; // in seconds
  String _audioDir = '';

  // start recording
  Future startRecording(String audioDir) async {
    _audioDir = audioDir;
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
        _ticker!.cancel();
        await _record.stop();
        await _record.dispose();
        await _pathStreamController.close();
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

  // Future<String> setupAudioPath(String audioDir) async {
  //   Directory dir = Directory(audioDir);
  //   print("Audio directory is $audioDir");
  //   if (!await dir.exists()) {
  //     try {
  //       await dir.create(recursive: true);
  //     } catch (e) {
  //       throw Exception('Error creating storage directory: $e');
  //     }
  //   }
  //   return audioDir;
  // }

  void dispose() {
    _record.dispose();
  }

  void _startTicker() {
    _ticker = Timer.periodic(Duration(seconds: maxRecordingChunk), (_) async {
      if (_buffer.isNotEmpty) {
        await _saveToFile();
      }
    });
  }

  void stopTicker() {
    _ticker?.cancel();
  }

  Future<void> _saveToFile() async {
    final filePath = '$_audioDir/${DateTime.now().millisecondsSinceEpoch}.wav';
    // final file = File(filePath);
    // await file.writeAsBytes(_buffer);
    await saveAsWav(Uint8List.fromList(_buffer), filePath, 44100, 2);
    _buffer.clear();
    _pathStreamController.add(filePath);
    print('My message: Saved to file: $filePath');
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

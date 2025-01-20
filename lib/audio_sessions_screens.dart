import 'package:flutter/material.dart';
import 'package:recording_app/controllers/recordings_library.dart';
import 'package:recording_app/models/audio_file.dart';
import 'package:recording_app/models/audio_session.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioSessionsScreen extends StatefulWidget {
  @override
  _AudioSessionsScreenState createState() => _AudioSessionsScreenState();
}

class _AudioSessionsScreenState extends State<AudioSessionsScreen> {
  final RecordingsLibrary _recordingsLibrary = RecordingsLibrary();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playAudio(String filePath) async {
    await _audioPlayer.play(DeviceFileSource(filePath));
  }

  void _deleteAudioFile(AudioSession session, AudioFile file) {
    setState(() {
      _recordingsLibrary.deleteAudioFile(session.sessionId, file);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio Sessions'),
      ),
      body: ListView.builder(
        itemCount: _recordingsLibrary.audioSessions.length,
        itemBuilder: (context, sessionIndex) {
          AudioSession session = _recordingsLibrary.audioSessions[sessionIndex];
          return ExpansionTile(
            title: Text('Session ID: ${session.sessionId}'),
            children: session.audioFiles!.map((file) {
              return ListTile(
                title: Text(file.filePath),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.play_arrow),
                      onPressed: () => _playAudio(file.filePath),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteAudioFile(session, file),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

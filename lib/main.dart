import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:recording_app/audio_sessions_screens.dart';
import 'package:recording_app/controllers/audio_manager.dart';
import 'package:recording_app/controllers/back_services.dart';
import 'package:recording_app/notifiers/recording_notifier.dart';

import 'controllers/longprocess.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.notification.isDenied.then((value) async {
    if (value) {
      await Permission.notification.request();
    }
  });
  // await initializeService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final recordingNotifier = RecordingNotifier();
  String text = "Start Service";

  @override
  void initState() {
    super.initState();
    recordingNotifier.addListener(updateUI);
  }

  @override
  void dispose() {
    recordingNotifier.removeListener(updateUI);
    super.dispose();
  }

  void updateUI() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Timer: ${recordingNotifier.timer}'),
            Builder(builder: (context) {
              if (recordingNotifier.status == RecordingStatus.idle) {
                return ElevatedButton(
                  onPressed: () {
                    recordingNotifier.startRecording();
                  },
                  child: const Text('Start Recording'),
                );
              } else if (recordingNotifier.status == RecordingStatus.playing) {
                return Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        recordingNotifier.pauseRecording();
                      },
                      child: const Text('Pause Recording'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        recordingNotifier.stopRecording();
                      },
                      child: const Text('Stop Recording'),
                    )
                  ],
                );
              } else {
                return Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        recordingNotifier.resumeRecording();
                      },
                      child: const Text('Resume Recording'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        recordingNotifier.stopRecording();
                      },
                      child: const Text('Stop Recording'),
                    )
                  ],
                );
              }
            }),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AudioSessionsScreen()),
                );
              },
              child: const Text('Go to Audio Sessions'),
            ),
            const SizedBox(height: 20),
            // ElevatedButton(
            //   onPressed: () {
            //     FlutterBackgroundService().invoke("setAsForeground");
            //   },
            //   child: const Text('Start fOREGROUND SERVICE'),
            // ),
            // const SizedBox(height: 20),
            // ElevatedButton(
            //   onPressed: () {
            //     FlutterBackgroundService().invoke("startRecording");
            //   },
            //   child: const Text('Start background SERVICE'),
            // ),
            // const SizedBox(height: 20),
            // ElevatedButton(
            //   onPressed: () async {
            //     final service = FlutterBackgroundService();
            //     bool isRunning = await service.isRunning();
            //     if (isRunning) {
            //       service.invoke("stopService");
            //     } else {
            //       service.startService();
            //     }

            //     if (!isRunning) {
            //       text = "Stop Service";
            //     } else {
            //       text = "Start Service";
            //     }
            //     setState(() {});
            //   },
            //   child: Text(text),
            // ),
            // const SizedBox(height: 20),
            // Text(text),
          ],
        ),
      ),
    );
  }
}

// import 'dart:async';
// import 'dart:io';
// import 'dart:math';
// import 'dart:ui';

// import 'package:flutter/material.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:recording_app/controllers/audio_manager.dart';

// Future<void> initializeService() async {
//   final service = FlutterBackgroundService();
//   await service.configure(
//     iosConfiguration: IosConfiguration(
//       autoStart: true,
//       onForeground: onStart,
//       onBackground: onIosBackground,
//     ),
//     androidConfiguration: AndroidConfiguration(
//       onStart: onStart,
//       isForegroundMode: true,
//       autoStart: true,
//     ),
//   );
// }

// @pragma("vm:entry-point")
// Future<bool> onIosBackground(ServiceInstance service) async {
//   WidgetsFlutterBinding.ensureInitialized();
//   DartPluginRegistrant.ensureInitialized();
//   return true;
// }

// @pragma("vm:entry-point")
// void onStart(ServiceInstance service) async {
//   print("My message: Bg services started");
//   DartPluginRegistrant.ensureInitialized();

//   if (service is AndroidServiceInstance) {
//     if (await service.isForegroundService()) {
//       service.setForegroundNotificationInfo(
//           title: "Recording!", content: "This app is now recording...");
//     }
//   }

//   service.on("startRecording").listen((event) async {
//     print("My message: Starting recording event path is ${event?["path"]}");
//     AudioManager().startRecording(event?["path"]);
//   });

//   // if (service is AndroidServiceInstance) {
//   //   service.on("setAsForeground").listen((event) {
//   //     service.setAsForegroundService();
//   //   });

//   //   service.on("setAsBackground").listen((event) {
//   //     service.setAsBackgroundService();
//   //   });
//   // }

//   service.on("stopService").listen((event) {
//     service.stopSelf();
//   });

//   // Timer.periodic(const Duration(seconds: 1), (timer) async {
//   //   if (service is AndroidServiceInstance) {
//   //     if (await service.isForegroundService()) {
//   //       service.setForegroundNotificationInfo(
//   //           title: "My title", content: "Blurrr");
//   //     }
//   //   }

//   //   print("Backlgound service is running");
//   //   service.invoke("Update");
//   // });
// }

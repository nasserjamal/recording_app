// import 'dart:async';
// import 'dart:math';
// import 'dart:ui';

// import 'package:flutter/material.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';

// Future<void> initializeService() async {
//   final service = FlutterBackgroundService();
//   await service.configure(
//     iosConfiguration: IosConfiguration(
//       autoStart: false,
//       onForeground: onStart,
//       onBackground: onIosBackground,
//     ),
//     androidConfiguration: AndroidConfiguration(
//       onStart: onStart,
//       isForegroundMode: true,
//       autoStart: false,
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
//     service.on("setAsForeground").listen((event) {
//       service.setAsForegroundService();
//     });

//     service.on("setAsBackground").listen((event) {
//       service.setAsBackgroundService();
//     });
//   }

//   service.on("stopService").listen((event) {
//     service.stopSelf();
//   });

//   Timer.periodic(const Duration(seconds: 1), (timer) async {
//     if (service is AndroidServiceInstance) {
//       if (await service.isForegroundService()) {
//         service.setForegroundNotificationInfo(
//             title: "My title", content: "Blurrr");
//       }
//     }

//     print("Backlgound service is running");
//     service.invoke("Update");
//   });
// }

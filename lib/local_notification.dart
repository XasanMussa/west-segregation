// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class localNotifications {
//   static final FlutterLocalNotificationsPlugin
//       _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// //iniitalize the plugin
//   static Future init() async {
//     // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//     final DarwinInitializationSettings initializationSettingsDarwin =
//         DarwinInitializationSettings(
//       onDidReceiveLocalNotification: (id, title, body, payload) => null,
//     );
//     final LinuxInitializationSettings initializationSettingsLinux =
//         LinuxInitializationSettings(defaultActionName: 'Open notification');
//     final InitializationSettings initializationSettings =
//         InitializationSettings(
//             android: initializationSettingsAndroid,
//             iOS: initializationSettingsDarwin,
//             linux: initializationSettingsLinux);
//     _flutterLocalNotificationsPlugin.initialize(initializationSettings,
//         onDidReceiveNotificationResponse: (details) => null);
//   }

//   //show simple notification
//   static Future showSimpleNotification(
//       {required String title,
//       required String body,
//       required String payload}) async {
//     const AndroidNotificationDetails androidNotificationDetails =
//         AndroidNotificationDetails('channel id', 'channel name',
//             channelDescription: 'channel description',
//             importance: Importance.max,
//             priority: Priority.high,
//             ticker: 'ticker');
//     const NotificationDetails notificationDetails =
//         NotificationDetails(android: androidNotificationDetails);
//     await _flutterLocalNotificationsPlugin
//         .show(0, title, body, notificationDetails, payload: payload);
//   }

//   static Future periodicNotification(
//       {required String title,
//       required String body,
//       required String payload}) async {
//     try {
//       const AndroidNotificationDetails androidNotificationDetails =
//           AndroidNotificationDetails('channel 2', 'periodic notify',
//               channelDescription: 'this channel is for periodic notification',
//               importance: Importance.max,
//               priority: Priority.high,
//               ticker: 'ticker');
//       NotificationDetails notificationDetails =
//           NotificationDetails(android: androidNotificationDetails);
//       int id = DateTime.now().millisecondsSinceEpoch % 1000000;
//       await _flutterLocalNotificationsPlugin.periodicallyShow(
//           0, title, body, RepeatInterval.everyMinute, notificationDetails);
//     } catch (e) {
//       print("periodic notification error: $e");
//     }
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webpush/firebase_options.dart';
import 'package:webpush/main_dev.dart';
import 'package:webpush/notification_service.dart';

const String countKey = 'count';

const String isolateName = 'isolate';

ReceivePort port = ReceivePort();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  IsolateNameServer.registerPortWithName(port.sendPort, isolateName);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Animation',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PushNotificationApp(),
    );
  }
}

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  //schedule after receiveing message;
  print("some ${message?.data?.toString()}");
  final alarmTime = DateTime.parse(message?.data?['time']).toLocal();
  print('arlm time is ${alarmTime}');
  // print("date is ${alarmTime.toLocal()}");
  final now = DateTime.now();
  const day = 0;
  const minute = 1;
  // final alarmTime = DateTime(now.year, now.month, now.day, 16, 5); // 3:42 PM

  // Calculate the initial delay until the first alarm
  final initialDelay = alarmTime.isBefore(now)
      ? alarmTime.add(Duration(days: 1)).difference(now)
      : alarmTime.difference(now);

  // print(DateTime.now());
  // Schedule the periodic alarm
  AndroidAlarmManager.periodic(
    const Duration(minutes: 1), // Repeat every day
    0,
    BOOTS.callback,
    startAt: now.add(initialDelay),
    exact: true,
    allowWhileIdle: true,
  );
}

class PushNotificationApp extends StatefulWidget {
  @override
  State<PushNotificationApp> createState() => _PushNotificationAppState();
}

class _PushNotificationAppState extends State<PushNotificationApp> {
  @override
  void initState() {
    // messageListener(context);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    AndroidAlarmManager.initialize();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationPage();
  }

  // void messageListener(BuildContext context) {
  //   // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  //   FirebaseMessaging.onMessage.listen((message) {
  //     print('Got a message whilst in the foreground!');
  //     print('Message data: ${message.data}');
  //     print("${message.notification?.title} and ${message.notification?.body}");
  //
  //     if (message.notification != null) {
  //       // print(
  //       // 'Message also contained a notification: ${message.notification.body}');
  //       showDialog(
  //           context: context,
  //           builder: ((BuildContext context) {
  //             return DynamicDialog(
  //                 title: message.notification?.title,
  //                 body: message.notification?.body);
  //           }));
  //     }
  //   });
  // }
}

class NotificationPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _Application();
}

class _Application extends State<NotificationPage> {
  late String _token;
  late Stream<String> _tokenStream;
  int notificationCount = 0;
  int _counter = 0;

  NotificationService notificationService  = NotificationService();

  FutureOr<dynamic> setToken(String? token) {
    developer.log('FCM TokenToken: $token');
    setState(() {
      _token = token!;
    });
  }

  @override
  void initState() {
    super.initState();
    //get token
    FirebaseMessaging.instance.getToken().then(setToken);
    _tokenStream = FirebaseMessaging.instance.onTokenRefresh;
    _tokenStream.listen(setToken);
    notificationService.initialNotification();
    port.listen((_) async => await _incrementCounter());
  }

  Future<void> _incrementCounter() async {
    developer.log('Increment counter!');
    // Ensure we've loaded the updated count from the background isolate.
    await prefs?.reload();

    setState(() {
      _counter++;
    });
  }

  // The background
  static SendPort? uiSendPort;

  @override
  Widget build(BuildContext context) {
    print("init");
    return Scaffold(
        appBar: AppBar(
          title: const Text('Firebase push push notification'),
        ),
        body: Container(
          child: Center(
            child: Card(
              margin: EdgeInsets.all(10),
              elevation: 10,
              child: ListTile(
                title: Center(
                  child: OutlinedButton.icon(
                    label: Text('Push Notification',
                        style: TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    onPressed: () async {
                      // final storage = new FlutterSecureStorage();
                      // sendPushMessageToWeb();
                      // print("some ${await storage.read(key: 'firstName')}");
                      // notificationService.initialNotification();
                      notificationService.sendNotification();
                    },
                    icon: Icon(Icons.notifications),
                  ),
                ),
              ),
            ),
          ),
        ));
  }
}

//push notification dialog for foreground
// class DynamicDialog extends StatefulWidget {
//   final title;
//   final body;
//
//   DynamicDialog({this.title, this.body});
//
//   @override
//   _DynamicDialogState createState() => _DynamicDialogState();
// }
//
// class _DynamicDialogState extends State<DynamicDialog> {
//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Text(widget.title),
//       actions: <Widget>[
//         OutlinedButton.icon(
//             label: Text('Close'),
//             onPressed: () {
//               Navigator.pop(context);
//             },
//             icon: Icon(Icons.close))
//       ],
//       content: Text(widget.body),
//     );
//   }
// }

class BOOTS {
  // The callback for our alarm
  @pragma('vm:entry-point')
  static Future<void> callback() async {
    developer.log('Alarm fired!');

    NotificationService notificationService  = NotificationService();
    notificationService.sendNotification();
    // Get the previous cached count and increment it.
    // final prefs = await SharedPreferences.getInstance();
    // final currentCount = prefs.getInt(countKey) ?? 0;
    // await prefs.setInt(countKey, currentCount + 1);

    // This will be null if we're running in the background.
    // uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
    // uiSendPort?.send(null);
  }
}

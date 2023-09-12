import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';
import 'package:cron/cron.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webpush/firebase_options.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

const String countKey = 'count';

const String isolateName = 'isolate';

ReceivePort port = ReceivePort();

final storage = new FlutterSecureStorage();

SharedPreferences? prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  IsolateNameServer.registerPortWithName(port.sendPort, isolateName);
  prefs = await SharedPreferences.getInstance();
  if (!prefs!.containsKey(countKey)) {
    await prefs!.setInt(countKey, 0);
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
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

/// Entry point for the example application.
class PushNotificationApp extends StatefulWidget {
  static const routeName = "/firebase-push";

  @override
  _PushNotificationAppState createState() => _PushNotificationAppState();
}

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // String value = await storage.read(key: key);

  // Map<String, String> allValues = await storage.readAll();
  //
  // await storage.delete(key: key);
  //
  // await storage.deleteAll();
  //
  // await storage.write(key: key, value: value);
  final cron = new Cron();
  // cron.close()

  try {
    cron.schedule(Schedule.parse('*/${message.data['time']} * * * * *'),
        () async => {print("every ${message.data['time']} second")});

    await storage.write(key: "firstName", value: message.data['firstName']);
  } catch (e) {
    print('e ${e}');
  }
  print("Handling a background message ${message.data}");
}

class _PushNotificationAppState extends State<PushNotificationApp> {
  @override
  void initState() {
    getPermission();
    messageListener(context);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    AndroidAlarmManager.initialize();
    // FirebaseMessaging.onBackgroundMessage((message) => firebaseMessagingBackgroundHandler(message, cb));
    super.initState();
  }

  Future<void> cb(data) async {
    final storage = new FlutterSecureStorage();
    await storage.write(key: "firstName", value: data['firstName']);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      // Initialize FlutterFire
      future: Firebase.initializeApp(
          // options: DefaultFirebaseOptions.currentPlatform
          ),
      builder: (context, snapshot) {
        // Check for errors
        if (snapshot.hasError) {
          return Center(
            child: Text(snapshot.error.toString()),
          );
        }
        // Once complete, show your application
        if (snapshot.connectionState == ConnectionState.done) {
          print('android firebase initiated');
          return NotificationPage();
        }
        // Otherwise, show something whilst waiting for initialization to complete
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  Future<void> getPermission() async {
    // FirebaseMessaging messaging = FirebaseMessaging.instance;
    // String token = await messaging.getToken(
    //   vapidKey:
    //       "AAAAIQByb9o:APA91bHUuNOnGaudsDLh4atlw971Ed6w1Rx75AFgTl0L_-7481fBCUYJQs4TG8HCcogYG-Z644-X-NbM7ovN1bdxDE86P91TWEzHygRG42xlxb7l5jkN4MzLKqOERL4oAtJUoHMLQ02Z",
    // );
    //
    // NotificationSettings settings = await messaging.requestPermission(
    //   alert: true,
    //   announcement: false,
    //   badge: true,
    //   carPlay: false,
    //   criticalAlert: false,
    //   provisional: false,
    //   sound: true,
    // );
    //
    // print('User granted permission: ${settings.authorizationStatus}');
  }

  void messageListener(BuildContext context) {
    // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    FirebaseMessaging.onMessage.listen((message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      print("${message.notification?.title} and ${message.notification?.body}");

      if (message.notification != null) {
        // print(
        // 'Message also contained a notification: ${message.notification.body}');
        showDialog(
            context: context,
            builder: ((BuildContext context) {
              return DynamicDialog(
                  title: message.notification?.title,
                  body: message.notification?.body);
            }));
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      // print("${message.notification.title} and ${message.notification.body}");

      if (message.notification != null) {
        // print(
        //     'Message also contained a notification: ${message.notification.body}');
        showDialog(
            context: context,
            builder: ((BuildContext context) {
              return DynamicDialog(
                  title: message.notification?.title,
                  body: message.notification?.body);
            }));
      }
    });
  }
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

  FutureOr<dynamic> setToken(String? token) {
    print('FCM TokenToken: $token');
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

  // The callback for our alarm
  @pragma('vm:entry-point')
  static Future<void> callback() async {
    developer.log('Alarm fired!');
    // Get the previous cached count and increment it.
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(countKey) ?? 0;
    await prefs.setInt(countKey, currentCount + 1);

    // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
    uiSendPort?.send(null);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.headlineMedium;

    return Scaffold(
        appBar: AppBar(
          title: const Text('Firebase push notification'),
        ),
        body: Column(
          children: [
            Container(
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
                          final storage = new FlutterSecureStorage();
                          // sendPushMessageToWeb();
                          print("some ${await storage.read(key: 'firstName')}");
                        },
                        icon: Icon(Icons.notifications),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              'Alarm fired $_counter times',
              style: textStyle,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Total alarms fired: ',
                  style: textStyle,
                ),
                Text(
                  prefs?.getInt(countKey).toString() ?? '',
                  key: const ValueKey('BackgroundCountText'),
                  style: textStyle,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const ValueKey('RegisterOneShotAlarm'),
              onPressed: () async {
                // await AndroidAlarmManager.oneShot(
                //   const Duration(seconds: 5),
                //   // Ensure we have a unique alarm ID.
                //   Random().nextInt(pow(2, 31) as int),
                //   callback,
                //   exact: true,
                //   wakeup: true,
                // );
                // await AndroidAlarmManager.periodic(const Duration(minutes: 1),
                //     Random().nextInt(pow(2, 31) as int), callback,
                //     exact: true, wakeup: true);
              },
              child: const Text(
                'Schedule OneShot Alarm',
              ),
            ),
          ],
        ));
  }

  //send notification
  sendPushMessageToWeb() async {
    if (_token == null) {
      print('Unable to send FCM message, no token exists.');
      return;
    }
    try {
      await http
          .post(
            Uri.parse('https://fcm.googleapis.com/fcm/send'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'key=YOUR SERVER KEY'
            },
            body: json.encode({
              'to': _token,
              'message': {
                'token': _token,
              },
              "notification": {
                "title": "Push Notification",
                "body": "Firebase  push notification"
              }
            }),
          )
          .then((value) => print(value.body));
      print('FCM request for web sent!');
    } catch (e) {
      print(e);
    }
  }
}

//push notification dialog for foreground
class DynamicDialog extends StatefulWidget {
  final title;
  final body;

  DynamicDialog({this.title, this.body});

  @override
  _DynamicDialogState createState() => _DynamicDialogState();
}

class _DynamicDialogState extends State<DynamicDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      actions: <Widget>[
        OutlinedButton.icon(
            label: Text('Close'),
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.close))
      ],
      content: Text(widget.body),
    );
  }
}
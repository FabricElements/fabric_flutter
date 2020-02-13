/// Child helper from notifications
import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

class PushProvider {
  FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  // ignore: close_sinks
  final _messagesStreamController =
      StreamController<Map<dynamic, dynamic>>.broadcast();

  Stream<Map<dynamic, dynamic>> get message => _messagesStreamController.stream;

  getToken() async {
    _firebaseMessaging.requestNotificationPermissions();
    String token = await _firebaseMessaging.getToken();
    return token;
  }

  initNotifications() async {
    _firebaseMessaging.configure(
      onMessage: (info) {
        Map<dynamic, dynamic> data = {};
        if (Platform.isAndroid) {
          data.addAll(info["data"]);
          data.addAll(info["notification"]);
        } else if (Platform.isIOS) {
          data.addAll(info);
        }
        data.addAll({
          "type": "On Message",
        });
        _messagesStreamController.sink.add(data);
        return;
      },
      onLaunch: (info) {
        Map<dynamic, dynamic> data = {};
        if (Platform.isAndroid) {
          data.addAll(info["data"]);
          data.addAll(info["notification"]);
        } else if (Platform.isIOS) {
          data.addAll(info);
        }
        data.addAll({
          "type": "On Launch",
        });
        _messagesStreamController.sink.add(data);
        return;
      },
      onResume: (info) {
        Map<dynamic, dynamic> data = {};
        if (Platform.isAndroid) {
          data.addAll(info["data"]);
          data.addAll(info["notification"]);
        } else if (Platform.isIOS) {
          data.addAll(info);
        }
        data.addAll({
          "type": "On Resume",
        });
        _messagesStreamController.sink.add(data);
        return;
      },
    );
//    _messagesStreamController.close();
  }
}

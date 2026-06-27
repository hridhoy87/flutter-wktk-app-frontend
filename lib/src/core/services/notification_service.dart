import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permissions for iOS/Android 13+
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    // This is where the app wakes up from terminated state.
    // Logic: If message contains PTT_START, initialize WebRTC.
    if (message.data['type'] == 'PTT_START') {
      // In a real app, you would use a background task or high-priority channel
      // to start listening to the audio stream immediately.
    }
  }
}

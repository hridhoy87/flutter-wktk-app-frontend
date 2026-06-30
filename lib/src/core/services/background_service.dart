import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:walkie_talkie/src/core/utils/logger.dart';

@pragma('vm:entry-point')
class BackgroundService {
  static const String notificationChannelId = 'ptt_foreground_service';
  static const int notificationId = 888;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'PTT Background Service',
      description: 'Keeps Walkie Talkie active for incoming calls',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'PTT READY',
        initialNotificationContent: 'Monitoring for incoming voice...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    L.info('Background Service Started');

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    service.on('updateNotification').listen((event) {
      if (service is AndroidServiceInstance && event != null) {
        final title = event['title'] as String? ?? 'PTT READY';
        final content = event['content'] as String? ?? 'Monitoring for incoming voice...';
        final int? colorValue = event['color'] as int?;

        if (colorValue != null) {
          flutterLocalNotificationsPlugin.show(
            notificationId,
            title,
            content,
            NotificationDetails(
              android: AndroidNotificationDetails(
                notificationChannelId,
                'PTT Background Service',
                icon: '@mipmap/ic_launcher',
                ongoing: true,
                color: Color(colorValue),
                showWhen: false,
              ),
            ),
          );
        } else {
          service.setForegroundNotificationInfo(
            title: title,
            content: content,
          );
        }
      }
    });

    L.info('Background Service Initialized');
  }
}

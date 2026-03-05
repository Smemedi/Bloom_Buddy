import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../task.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    InitializationSettings initSettings = const InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'plant_care_channel',
        'Plant Care Notifications',
        description: 'Notifications for plant care tasks',
        importance: Importance.max,
        playSound: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Request notification permission for Android 13+
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  static Future<void> scheduleNotification(PlantTask task, DateTime date) async {
    try {
      final scheduledDate = date.subtract(Duration(hours: 8)); // Schedule for 8 AM on the task day
      if (scheduledDate.isBefore(DateTime.now())) {
        return;
      }

      await flutterLocalNotificationsPlugin.zonedSchedule(
        task.id.hashCode,
        'Plant Care Reminder',
        task.title,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'plant_care_channel',
            'Plant Care Notifications',
            channelDescription: 'Notifications for plant care tasks',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  static Future<void> cancelNotification(int id) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
    } catch (e) {
      print('Error cancelling notification: $e');
    }
  }

  static Future<void> showTestNotification() async {
    try {
      await flutterLocalNotificationsPlugin.show(
        999,
        'Test Plant Care Reminder',
        'This is a test notification to verify your notifications are working!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'plant_care_channel',
            'Plant Care Notifications',
            channelDescription: 'Notifications for plant care tasks',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      print('Error showing test notification: $e');
      rethrow;
    }
  }
}
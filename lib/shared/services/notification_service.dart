import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/insights/insights_model.dart';
import 'currency_settings.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final StreamController<String> _routeTapController =
      StreamController<String>.broadcast();
  static String? _initialRoute;

  static Stream<String> get routeTapStream => _routeTapController.stream;

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _routeTapController.add(payload);
        }
      },
    );

    final launchDetails = await _notificationsPlugin
        .getNotificationAppLaunchDetails();
    final route = launchDetails?.notificationResponse?.payload;
    if (route != null && route.isNotEmpty) {
      _initialRoute = route;
    }
  }

  static String? takeInitialRoute() {
    final route = _initialRoute;
    _initialRoute = null;
    return route;
  }

  static Future<bool> _canNotifyToday(String category, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final key = 'notif_${type}_${category}_$today';

    if (prefs.getBool(key) == true) return false;
    await prefs.setBool(key, true);
    return true;
  }

  static Future<void> showBudgetWarning(
    String category,
    double usagePct,
    double limit,
  ) async {
    if (!await _canNotifyToday(category, 'warning')) return;

    final formattedLimit = CurrencySettings.format(limit);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'budget_channel',
          'Budget Alerts',
          importance: Importance.high,
          priority: Priority.high,
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      category.hashCode,
      'Budget $category Hampir Habis!',
      'Sudah terpakai ${usagePct.toStringAsFixed(0)}% dari $formattedLimit.',
      details,
    );
  }

  static Future<void> showBudgetExceeded(String category, double excess) async {
    if (!await _canNotifyToday(category, 'exceeded')) return;

    final formattedExcess = CurrencySettings.format(excess);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'budget_channel',
          'Budget Alerts',
          importance: Importance.max,
          priority: Priority.max,
          color: Color(0xFFFF4C4C),
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      category.hashCode + 1,
      'Budget $category Melebihi Limit!',
      'Kamu overspend sebesar $formattedExcess. Hati-hati!',
      details,
    );
  }

  static Future<void> showSavingsGoalReminder({
    required String goalId,
    required String goalName,
    required double progressPct,
    required int daysRemaining,
  }) async {
    if (!await _canNotifyToday(goalId, 'savings_deadline')) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'savings_goal_channel',
          'Savings Goal Alerts',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF4F6EF7),
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    final dayText = daysRemaining <= 0
        ? 'hari ini'
        : '$daysRemaining hari lagi';
    await _notificationsPlugin.show(
      goalId.hashCode,
      'Goal "$goalName" mendekati target date',
      'Progress baru ${progressPct.toStringAsFixed(0)}%. Deadline $dayText.',
      details,
    );
  }

  static Future<void> maybeShowWeeklyDigest(InsightsBundle bundle) async {
    final now = DateTime.now();
    if (now.weekday != DateTime.monday || now.hour < 6) return;

    final prefs = await SharedPreferences.getInstance();
    final monday = DateTime(now.year, now.month, now.day);
    final key = 'weekly_digest_${DateFormat('yyyy-MM-dd').format(monday)}';
    if (prefs.getBool(key) == true) return;

    await showWeeklyDigest(body: bundle.mainInsight.title);
    await prefs.setBool(key, true);
  }

  static Future<void> showWeeklyDigest({
    required String body,
    String payload = '/insights',
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'weekly_digest_channel',
      'Weekly Digest',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF4F6EF7),
    );
    const details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      9001,
      'Ringkasan minggu lalu siap 📊',
      body,
      details,
      payload: payload,
    );
  }
}

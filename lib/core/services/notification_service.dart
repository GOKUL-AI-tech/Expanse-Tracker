import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Notification IDs
  static const int _spendingReminderId = 1;
  static const int _dailySummaryId = 2;
  static const int _weeklyReportId = 3;
  static const int _budgetAlertId = 4;

  // Prefs keys
  static const String _keySpendingReminder = 'notif_spending_reminder';
  static const String _keySpendingInterval = 'notif_spending_interval'; // '30min','1hour','2hours'
  static const String _keyDailySummary = 'notif_daily_summary';
  static const String _keyWeeklyReport = 'notif_weekly_report';
  static const String _keyBudgetAlert = 'notif_budget_alert';

  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Create notification channel
    const channel = AndroidNotificationChannel(
      'expense_tracker_channel',
      'Expense Tracker',
      description: 'Expense tracking reminders and alerts',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Re-schedule saved settings after app start
    await _restoreSchedules();
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? false;
    return granted;
  }

  // ── Notification details ─────────────────────────────────────────────────

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'expense_tracker_channel',
          'Expense Tracker',
          channelDescription: 'Expense tracking reminders and alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  // ── Spending Reminder ────────────────────────────────────────────────────

  Future<void> scheduleSpendingReminder(String interval) async {
    await cancelSpendingReminder();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySpendingReminder, true);
    await prefs.setString(_keySpendingInterval, interval);

    Duration period;
    switch (interval) {
      case '30min':
        period = const Duration(minutes: 30);
        break;
      case '1hour':
        period = const Duration(hours: 1);
        break;
      case '2hours':
        period = const Duration(hours: 2);
        break;
      default:
        period = const Duration(hours: 1);
    }

    // Schedule repeating via periodic
    final androidDetails = AndroidNotificationDetails(
      'expense_tracker_channel',
      'Expense Tracker',
      channelDescription: 'Spending reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    RepeatInterval repeatInterval;
    if (interval == '30min') {
      // flutter_local_notifications only supports hourly/daily/weekly built-in
      // For 30min we schedule individual notifications staggered
      await _scheduleEvery30Min();
      return;
    } else if (interval == '1hour') {
      repeatInterval = RepeatInterval.hourly;
    } else {
      repeatInterval = RepeatInterval.hourly; // fallback; we'll use everyN below
    }

    await _plugin.periodicallyShow(
      _spendingReminderId,
      '💰 Expense Reminder',
      'Have you tracked your expenses? Keep your finances in check!',
      repeatInterval,
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexact,
    );
  }

  Future<void> _scheduleEvery30Min() async {
    final now = tz.TZDateTime.now(tz.local);
    final messages = [
      'Have you tracked your expenses? Stay on budget! 💸',
      'Quick check — did you spend anything recently? 🧾',
      'Time to log your expenses! Small habits = big savings 📊',
      'Don\'t forget to track! Every rupee counts 💰',
    ];

    for (int i = 0; i < 8; i++) {
      final scheduled = now.add(Duration(minutes: 30 * (i + 1)));
      await _plugin.zonedSchedule(
        _spendingReminderId + 10 + i,
        '💰 Expense Reminder',
        messages[i % messages.length],
        scheduled,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelSpendingReminder() async {
    await _plugin.cancel(_spendingReminderId);
    // Cancel 30-min batch
    for (int i = 0; i < 8; i++) {
      await _plugin.cancel(_spendingReminderId + 10 + i);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySpendingReminder, false);
  }

  // ── Daily Summary (9 PM every day) ──────────────────────────────────────

  Future<void> scheduleDailySummary(bool enable) async {
    await _plugin.cancel(_dailySummaryId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDailySummary, enable);
    if (!enable) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, 21, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailySummaryId,
      '📊 Daily Summary',
      'How did your finances look today? Tap to see your daily report.',
      scheduled,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Weekly Report (Every Monday 8 AM) ───────────────────────────────────

  Future<void> scheduleWeeklyReport(bool enable) async {
    await _plugin.cancel(_weeklyReportId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWeeklyReport, enable);
    if (!enable) return;

    final now = tz.TZDateTime.now(tz.local);
    // Find next Monday
    var daysUntilMonday = (DateTime.monday - now.weekday + 7) % 7;
    if (daysUntilMonday == 0) daysUntilMonday = 7;
    final monday = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + daysUntilMonday,
        8,
        0);

    await _plugin.zonedSchedule(
      _weeklyReportId,
      '📅 Weekly Report Ready',
      'Your weekly spending summary is ready. Review how you did this week!',
      monday,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // ── Budget Alert (manual trigger when 80%+ spent) ───────────────────────

  Future<void> sendBudgetAlert(String category, double percent) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_keyBudgetAlert) ?? true)) return;

    await _plugin.show(
      _budgetAlertId,
      '⚠️ Budget Alert: $category',
      '${percent.toStringAsFixed(0)}% of your $category budget is used. Consider slowing down!',
      _details,
    );
  }

  Future<void> setBudgetAlertEnabled(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBudgetAlert, enable);
  }

  // ── Restore on app start ─────────────────────────────────────────────────

  Future<void> _restoreSchedules() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_keySpendingReminder) == true) {
      final interval = prefs.getString(_keySpendingInterval) ?? '1hour';
      await scheduleSpendingReminder(interval);
    }
    if (prefs.getBool(_keyDailySummary) == true) {
      await scheduleDailySummary(true);
    }
    if (prefs.getBool(_keyWeeklyReport) == true) {
      await scheduleWeeklyReport(true);
    }
  }

  // ── Read saved prefs ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'spending_reminder': prefs.getBool(_keySpendingReminder) ?? false,
      'spending_interval': prefs.getString(_keySpendingInterval) ?? '1hour',
      'daily_summary': prefs.getBool(_keyDailySummary) ?? false,
      'weekly_report': prefs.getBool(_keyWeeklyReport) ?? false,
      'budget_alert': prefs.getBool(_keyBudgetAlert) ?? true,
    };
  }
}

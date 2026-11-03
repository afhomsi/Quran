import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/strings.dart';
import '../settings/app_settings.dart';

/// Sets and clears the one daily reminder notification.
abstract class ReminderScheduler {
  /// Whether reminders can be shown here: on phones, not on the web.
  bool get supported;

  /// Asks the user to allow notifications, where the system asks; returns
  /// whether they are allowed.
  Future<bool> requestPermission();

  /// Shows [title] and [body] every day at [minutes] after midnight,
  /// local time, in place of any reminder set before.
  Future<void> schedule(int minutes, String title, String body);

  Future<void> cancel();
}

const _reminderId = 1;

/// The reminder through the phone's own notifications.
class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _init() => _ready ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? true;
  }

  @override
  Future<void> schedule(int minutes, String title, String body) async {
    await _init();
    await _plugin.cancel(id: _reminderId);
    await _plugin.zonedSchedule(
      id: _reminderId,
      title: title,
      body: body,
      // In UTC, so no time zone data is needed: the time of day is kept
      // as the phone's clock had it when the reminder was set.
      scheduledDate: tz.TZDateTime.from(
        nextReminder(DateTime.now(), minutes).toUtc(),
        tz.UTC,
      ),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily reminder',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel() async {
    await _init();
    await _plugin.cancel(id: _reminderId);
  }
}

/// The next time, after [now], that is [minutes] after midnight.
DateTime nextReminder(DateTime now, int minutes) {
  var at = DateTime(now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
  if (!at.isAfter(now)) {
    at = DateTime(at.year, at.month, at.day + 1, at.hour, at.minute);
  }
  return at;
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => LocalReminderScheduler(),
);

/// Sets the daily reminder as the settings say, or clears it. Failing
/// to reach the notifications never stops the app.
Future<void> syncReminder(ProviderContainer container, S t) async {
  final scheduler = container.read(reminderSchedulerProvider);
  if (!scheduler.supported) return;
  final settings = container.read(settingsProvider);
  try {
    if (settings.reminderOn) {
      await scheduler.schedule(
        settings.reminderMinutes,
        t.todayWird,
        t.reminderBody,
      );
    } else {
      await scheduler.cancel();
    }
  } catch (e) {
    debugPrint('Daily reminder: $e');
  }
}

/// Turns the daily reminder on, after asking for the time and for
/// leave to notify, or off.
Future<void> setReminder(BuildContext context, bool on) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final t = S.of(context);
  final notifier = container.read(settingsProvider.notifier);
  if (on) {
    final minutes = container.read(settingsProvider).reminderMinutes;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: t.reminderTime,
    );
    if (time == null) return;
    var allowed = true;
    try {
      allowed = await container
          .read(reminderSchedulerProvider)
          .requestPermission();
    } catch (e) {
      debugPrint('Daily reminder: $e');
    }
    if (!allowed) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.reminderNotAllowed)));
      }
      return;
    }
    notifier.update(
      (s) => s.copyWith(
        reminderOn: true,
        reminderMinutes: time.hour * 60 + time.minute,
      ),
    );
  } else {
    notifier.update((s) => s.copyWith(reminderOn: false));
  }
  await syncReminder(container, t);
}

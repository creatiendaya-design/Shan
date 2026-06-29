import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../data/local/app_database.dart';

final _plugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  tz.initializeTimeZones();

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestSoundPermission: true,
    requestBadgePermission: true,
    requestAlertPermission: true,
  );
  await _plugin.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );

  final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.requestNotificationsPermission();
  await androidPlugin?.requestExactAlarmsPermission();
}

// ── Recordatorio diario ───────────────────────────────────────────────────────

const _dailyReminderId = 9999;

/// Programa (o cancela) el recordatorio diario a las 9 PM.
Future<void> setDailyReminder(bool enabled) async {
  if (!enabled) {
    await _plugin.cancel(_dailyReminderId);
    return;
  }
  final now = tz.TZDateTime.now(tz.local);
  var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 21, 0);
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  try {
    await _plugin.zonedSchedule(
      _dailyReminderId,
      '¿Ya registraste tus gastos? 💰',
      'Tómate un minuto para anotar lo de hoy.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'shannon_daily',
          'Recordatorio diario',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  } catch (e) {
    debugPrint('Daily reminder error: $e');
  }
}

// ── Recurrentes ───────────────────────────────────────────────────────────────

/// Cancel all and re-schedule from the current recurring list.
Future<void> rescheduleRecurringNotifications(
    List<RecurringTransaction> recurring) async {
  await _plugin.cancelAll();

  final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
  final now = DateTime.now();

  for (final r in recurring) {
    if (!r.active) continue;

    final due = DateTime.fromMillisecondsSinceEpoch(r.nextDueDateMs);
    final notifyAt = DateTime(due.year, due.month, due.day, 9, 0);
    final notifyBefore = notifyAt.subtract(const Duration(days: 1));

    if (notifyAt.isAfter(now)) {
      await _schedule(
        id: r.id.hashCode & 0x7FFFFFFF,
        title: 'Recurrente hoy',
        body: '${r.name}  •  ${fmt.format(r.amountCents / 100)}',
        scheduledDate: notifyAt,
      );
    }
    if (notifyBefore.isAfter(now)) {
      await _schedule(
        id: (r.id.hashCode ^ 0x1000) & 0x7FFFFFFF,
        title: 'Mañana vence',
        body: '${r.name}  •  ${fmt.format(r.amountCents / 100)}',
        scheduledDate: notifyBefore,
      );
    }
  }
}

// ── Deudas ────────────────────────────────────────────────────────────────────

/// Schedule reminders for unpaid debts due within 7 days.
Future<void> scheduleDebtNotifications(List<Debt> debts) async {
  final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
  final now = DateTime.now();

  for (final d in debts) {
    if (d.paid || d.dueDateMs == null) continue;

    final due = DateTime.fromMillisecondsSinceEpoch(d.dueDateMs!);
    final daysLeft = due.difference(now).inDays;
    if (daysLeft > 7) continue;

    final notifyAt = daysLeft >= 1
        ? DateTime(due.year, due.month, due.day, 9, 0)
        : now.add(const Duration(minutes: 1));

    final direction = d.direction == 'i_owe' ? 'Debes pagar' : 'Te deben';
    final title = daysLeft <= 0
        ? 'Deuda vencida'
        : daysLeft == 1
            ? 'Deuda vence mañana'
            : 'Deuda vence en $daysLeft días';

    await _schedule(
      id: (d.id.hashCode ^ 0x2000) & 0x7FFFFFFF,
      title: title,
      body: '${d.name}  •  $direction ${fmt.format(d.amountCents / 100)}',
      scheduledDate: notifyAt,
      channelId: 'shannon_debts',
      channelName: 'Deudas',
    );
  }
}

// ── Presupuestos ──────────────────────────────────────────────────────────────

/// Send immediate alerts for budgets at 80%+ of their limit.
Future<void> checkBudgetAlerts(
  List<Budget> budgets,
  Map<String, int> spentByCat,
  List<Category> categories,
) async {
  final catMap = {for (final c in categories) c.id: c.name};
  final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 0);

  for (final b in budgets) {
    if (b.categoryId == null || b.limitCents == 0) continue;
    final spent = spentByCat[b.categoryId] ?? 0;
    if (spent == 0) continue;

    final ratio = spent / b.limitCents;
    final catName = catMap[b.categoryId] ?? 'Presupuesto';

    if (ratio >= 1.0) {
      await _immediate(
        id: (b.id.hashCode ^ 0x3000) & 0x7FFFFFFF,
        title: 'Presupuesto superado',
        body: '$catName: ${fmt.format(spent / 100)} de ${fmt.format(b.limitCents / 100)}',
      );
    } else if (ratio >= 0.8) {
      await _immediate(
        id: (b.id.hashCode ^ 0x4000) & 0x7FFFFFFF,
        title: 'Presupuesto al ${(ratio * 100).round()}%',
        body: '$catName: ${fmt.format(spent / 100)} de ${fmt.format(b.limitCents / 100)}',
      );
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<void> _schedule({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledDate,
  String channelId = 'shannon_recurring',
  String channelName = 'Recurrentes',
}) async {
  try {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  } catch (e) {
    // Exact alarms not permitted — retry with inexact (fires within ~1 hour window)
    if (e.toString().contains('exact_alarms_not_permitted')) {
      try {
        final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
        await _plugin.zonedSchedule(
          id, title, body, tzDate,
          NotificationDetails(
            android: AndroidNotificationDetails(channelId, channelName,
                importance: Importance.high, priority: Priority.high,
                icon: '@mipmap/ic_launcher'),
            iOS: const DarwinNotificationDetails(
                presentAlert: true, presentBadge: true, presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e2) {
        debugPrint('Notification fallback error: $e2');
      }
    } else {
      debugPrint('Notification schedule error: $e');
    }
  }
}

Future<void> _immediate({
  required int id,
  required String title,
  required String body,
  String channelId = 'shannon_budgets',
  String channelName = 'Presupuestos',
}) async {
  try {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  } catch (e) {
    debugPrint('Notification error: $e');
  }
}

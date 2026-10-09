import 'dart:io';

import 'reminder_task_xml.dart';

bool get canScheduleReminders => Platform.isWindows;

Future<void> _powershell(
  String script, {
  Map<String, String>? environment,
}) async {
  final result = await Process.run('powershell.exe', [
    '-NoProfile',
    '-NonInteractive',
    '-ExecutionPolicy',
    'Bypass',
    '-Command',
    script,
  ], environment: environment);
  if (result.exitCode != 0) {
    final message = '${result.stderr}'.trim();
    throw ProcessException(
      'powershell',
      const [],
      message.isEmpty ? 'Task Scheduler call failed' : message,
      result.exitCode,
    );
  }
}

/// Creates or replaces the reminders task. With no [nextUtc] only the sign-in
/// trigger remains (for reminders that are already overdue).
Future<void> syncReminderTask(DateTime? nextUtc) async {
  if (!canScheduleReminders) return;
  final user =
      '${Platform.environment['USERDOMAIN'] ?? ''}\\${Platform.environment['USERNAME'] ?? ''}';
  final xml = buildReminderTaskXml(
    exe: Platform.resolvedExecutable,
    userId: user,
    nextUtc: nextUtc != null && nextUtc.isAfter(DateTime.now())
        ? nextUtc
        : null,
  );
  await _powershell(
    "Register-ScheduledTask -TaskName '$reminderTaskName' -Xml \$env:BN_TASK_XML -Force | Out-Null",
    environment: {'BN_TASK_XML': xml},
  );
}

Future<void> removeReminderTask() async {
  if (!canScheduleReminders) return;
  await _powershell(
    "Unregister-ScheduledTask -TaskName '$reminderTaskName' -Confirm:\$false -ErrorAction SilentlyContinue",
  );
}

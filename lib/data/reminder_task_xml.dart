/// Name of the Windows scheduled task that starts BetterNotes for reminders.
const reminderTaskName = 'BetterNotes Reminders';

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Task Scheduler XML that launches `exe --reminders-due` at [nextUtc] (an
/// absolute instant, so time-zone changes do not move it) and shortly after
/// [userId] signs in, so reminders that came due while the PC was off surface.
/// Runs only while the user is signed in, without a password or elevation.
String buildReminderTaskXml({
  required String exe,
  required String userId,
  DateTime? nextUtc,
}) {
  final time = nextUtc == null
      ? ''
      : '<TimeTrigger><StartBoundary>'
            '${nextUtc.toUtc().toIso8601String().split('.').first}Z'
            '</StartBoundary><Enabled>true</Enabled></TimeTrigger>';
  return '<?xml version="1.0" encoding="UTF-16"?>'
      '<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">'
      '<Triggers>$time'
      '<LogonTrigger><Enabled>true</Enabled><UserId>${_escape(userId)}</UserId>'
      '<Delay>PT30S</Delay></LogonTrigger></Triggers>'
      '<Principals><Principal id="Author"><UserId>${_escape(userId)}</UserId>'
      '<LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel>'
      '</Principal></Principals>'
      '<Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>'
      '<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>'
      '<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>'
      '<StartWhenAvailable>true</StartWhenAvailable>'
      '<ExecutionTimeLimit>PT5M</ExecutionTimeLimit></Settings>'
      '<Actions Context="Author"><Exec><Command>${_escape(exe)}</Command>'
      '<Arguments>--reminders-due</Arguments></Exec></Actions></Task>';
}

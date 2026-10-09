import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_info.dart';
import '../data/app_log.dart';
import '../data/local_store.dart';
import '../l10n/l10n.dart';
import '../state/notes_controller.dart';

/// Plain-text report for support. It holds versions, counts, and settings
/// states only: no note text, titles, tags, or account identifiers.
String buildDiagnostics({
  required String platform,
  required String? dataPath,
  required Map<String, Object?> facts,
  required List<String> logLines,
  DateTime? now,
}) {
  final out = StringBuffer()
    ..writeln('$appName $appVersionLabel')
    ..writeln('Platform: $platform')
    ..writeln('Report time: ${(now ?? DateTime.now()).toIso8601String()}')
    ..writeln('Data file: ${dataPath ?? 'unavailable'}');
  for (final entry in facts.entries) {
    out.writeln('${entry.key}: ${entry.value}');
  }
  out.writeln('\nRecent log (${logLines.length} lines):');
  if (logLines.isEmpty) out.writeln('(empty)');
  for (final line in logLines) {
    out.writeln(line);
  }
  return out.toString();
}

Future<String> collectDiagnostics(NotesController c) async {
  final notes = c.notes.length;
  final facts = <String, Object?>{
    'Notes (active)': notes,
    'Archive': c.archiveNotes.length,
    'Trash': c.trash.length,
    'Signed in': c.signedIn,
    'Sync error': c.syncError ?? 'none',
    'Save problem': c.saveFailure ?? 'none',
    'Keep in tray': c.keepInTray,
    'Quick note shortcut': c.quickCaptureKey,
    'Reminder task': c.reminderTaskEnabled,
    'Reminder task error': c.reminderTaskError ?? 'none',
    'Automatic backups': c.autoBackupFolder == null ? 'off' : 'on',
    'Last automatic backup': c.autoBackupLast?.toIso8601String() ?? 'never',
    'Automatic backup error': c.autoBackupError ?? 'none',
    'Fast note opening': c.fastNoteOpening,
    'Trash retention days': c.trashRetentionDays,
  };
  return buildDiagnostics(
    platform: '${defaultTargetPlatform.name}${kIsWeb ? ' (web)' : ''}',
    dataPath: _dataPath(c.store),
    facts: facts,
    logLines: await AppLog.tail(),
  );
}

String? _dataPath(LocalStore store) {
  try {
    final path = store.database.path;
    return path.isEmpty ? null : path;
  } catch (_) {
    return null;
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.controller});
  final NotesController controller;

  @override
  Widget build(BuildContext context) {
    final dataPath = _dataPath(controller.store);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aboutTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(appName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              context.l10n.aboutVersion(appVersion, appBuild),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(context.l10n.aboutTagline),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined),
              title: Text(context.l10n.aboutDataTitle),
              subtitle: SelectableText(
                dataPath ?? context.l10n.aboutDataBrowser,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(context.l10n.aboutLogTitle),
              subtitle: SelectableText(
                AppLog.path ?? context.l10n.aboutLogNone,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('copy-diagnostics'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final copiedMessage = context.l10n.aboutDiagnosticsCopied;
                final text = await collectDiagnostics(controller);
                await Clipboard.setData(ClipboardData(text: text));
                messenger.showSnackBar(SnackBar(content: Text(copiedMessage)));
              },
              icon: const Icon(Icons.copy_outlined),
              label: Text(context.l10n.aboutCopyDiagnostics),
            ),
            const SizedBox(height: 16),
            Text(context.l10n.aboutPrivacy),
          ],
        ),
      ),
    );
  }
}

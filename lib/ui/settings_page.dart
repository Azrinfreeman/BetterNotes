import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_info.dart';
import '../auth/sign_in.dart';
import '../data/backup.dart';
import '../data/auto_backup.dart' as auto_backup;
import '../data/backup_files.dart' as backup_files;
import '../desktop/auto_start.dart';
import '../desktop/tray.dart';
import '../desktop/window_chrome.dart';
import '../state/notes_controller.dart';
import '../l10n/l10n.dart';
import 'about_page.dart';
import 'shortcuts_help.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final NotesController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? _autoStartEnabled;
  bool _loadingAutoStart = false;
  bool _savingAutoStart = false;
  bool _workingFiles = false;

  List<Widget> _autoBackupTiles() {
    final c = widget.controller;
    final last = c.autoBackupLast;
    final status = c.autoBackupRunning
        ? context.l10n.settingsBackingUpNow
        : c.autoBackupError ??
              (last == null
                  ? context.l10n.settingsNoAutomaticBackupHasRun
                  : context.l10n.settingsLastBackup(
                      last.toLocal().toString().substring(0, 16),
                    ));
    return [
      ListTile(
        leading: const Icon(Icons.schedule_outlined),
        title: Text(context.l10n.settingsAutomaticBackups),
        subtitle: Text(
          c.autoBackupFolder == null
              ? context.l10n.settingsOffChooseAFolderTo
              : '${c.autoBackupFolder}\n$status',
        ),
        textColor: c.autoBackupError == null
            ? null
            : Theme.of(context).colorScheme.error,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 4,
            children: [
              TextButton(
                key: const ValueKey('auto-backup-choose'),
                onPressed: () async {
                  final folder = await auto_backup.chooseBackupFolder();
                  if (folder != null) await c.setAutoBackupFolder(folder);
                },
                child: Text(
                  c.autoBackupFolder == null
                      ? context.l10n.settingsChooseFolder
                      : 'Change',
                ),
              ),
              if (c.autoBackupFolder != null)
                TextButton(
                  onPressed: () => c.setAutoBackupFolder(null),
                  child: Text(context.l10n.settingsTurnOff),
                ),
            ],
          ),
        ),
      ),
      if (c.autoBackupFolder != null) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(context.l10n.settingsKeepTheNewestBackups),
              DropdownButton<int>(
                key: const ValueKey('auto-backup-keep'),
                value: const [3, 7, 14, 30].contains(c.autoBackupKeep)
                    ? c.autoBackupKeep
                    : 7,
                items: const [
                  DropdownMenuItem(value: 3, child: Text('3')),
                  DropdownMenuItem(value: 7, child: Text('7')),
                  DropdownMenuItem(value: 14, child: Text('14')),
                  DropdownMenuItem(value: 30, child: Text('30')),
                ],
                onChanged: (keep) {
                  if (keep != null) c.setAutoBackupKeep(keep);
                },
              ),
              TextButton(
                onPressed: c.autoBackupRunning
                    ? null
                    : () => c.runAutoBackup(force: true),
                child: Text(context.l10n.settingsBackUpNow),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  Future<void> _fileAction(Future<String?> Function() action) async {
    if (_workingFiles) return;
    setState(() => _workingFiles = true);
    try {
      final message = await action();
      if (mounted && message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.settingsFileOperationFailed('$error')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _workingFiles = false);
    }
  }

  Future<String?> _exportBackup() async {
    final l10n = context.l10n;
    final bytes = await widget.controller.exportBackup();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final saved = await backup_files.saveBackupFile(
      bytes,
      'BetterNotes-backup-$date.zip',
    );
    return saved ? l10n.settingsBackupExportedKeepThisReadable : null;
  }

  Future<String?> _exportText() async {
    final l10n = context.l10n;
    final text = await widget.controller.exportText();
    final saved = await backup_files.saveBackupFile(
      Uint8List.fromList(utf8.encode(text)),
      'BetterNotes-notes.txt',
      mimeType: 'text/plain',
    );
    return saved ? l10n.settingsTextExportedUseAComplete : null;
  }

  Future<String?> _importBackup() async {
    final owner = widget.controller.ownerId;
    final bytes = await backup_files.pickBackup();
    if (bytes == null) return null;
    final backup = await compute(NoteBackup.validate, bytes);
    if (!mounted) return null;
    var preferences = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.settingsImportBackupAsCopies),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.settingsNotesInTrashImagesExisting(
                    '${backup.notes.length}',
                    '${backup.trashCount}',
                    '${backup.assets.length}',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    context.l10n.settingsRestoreAppearanceAndEditorPreferences,
                  ),
                  value: preferences,
                  onChanged: (value) =>
                      setDialogState(() => preferences = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.bulkCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.settingsImportCopies),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return null;
    await widget.controller.importBackup(
      backup,
      restorePreferences: preferences,
      expectedOwner: owner,
    );
    return 'Imported ${backup.notes.length} note copies.';
  }

  @override
  void initState() {
    super.initState();
    if (AutoStart.isSupported) _loadAutoStart();
  }

  Future<void> _loadAutoStart() async {
    if (_loadingAutoStart) return;
    setState(() => _loadingAutoStart = true);
    try {
      final enabled = await AutoStart.isEnabled();
      if (mounted) setState(() => _autoStartEnabled = enabled);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.settingsCouldNotReadWindowsStartup('$error'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingAutoStart = false);
    }
  }

  Future<void> _setAutoStart(bool enabled) async {
    setState(() => _savingAutoStart = true);
    try {
      await AutoStart.setEnabled(enabled);
      if (mounted) setState(() => _autoStartEnabled = enabled);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.settingsCouldNotChangeWindowsStartup('$error'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingAutoStart = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: WindowTitle(
          child: Text(
            context.l10n.notesHomeSettings,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: const [WindowButtons(), SizedBox(width: 8)],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(
              widget.controller.email ?? context.l10n.notesHomeLocalNotes,
            ),
            subtitle: Text(
              widget.controller.cloudAvailable
                  ? widget.controller.signedIn
                        ? context.l10n.settingsYourNotesCanSyncAcross
                        : context.l10n.settingsSignInWithGoogleTo
                  : context.l10n.settingsGoogleSyncNeedsASupabase,
            ),
          ),
          if (widget.controller.cloudAvailable && !widget.controller.signedIn)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 4, 24, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      await signInWithGoogle(widget.controller.client!);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.settingsSignInFailed('$error'),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(context.l10n.settingsContinueWithGoogle),
                ),
              ),
            ),
          if (widget.controller.signedIn)
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(context.l10n.settingsSignOut),
              onTap: () async {
                try {
                  await widget.controller.signOut();
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$error')));
                  }
                }
              },
            ),
          if (widget.controller.syncError != null)
            ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: Text(context.l10n.settingsSyncNeedsAttention),
              subtitle: Text(widget.controller.syncError!),
              trailing: TextButton(
                onPressed: widget.controller.sync,
                child: Text(context.l10n.noteRetry),
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.settingsAppearance),
                DropdownButton<ThemeMode>(
                  isExpanded: true,
                  value: widget.controller.themeMode,
                  onChanged: (mode) {
                    if (mode != null) widget.controller.setTheme(mode);
                  },
                  items: [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text(context.l10n.settingsSystem),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text(context.l10n.settingsLight),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text(context.l10n.settingsDark),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.delete_outline),
            title: Text(context.l10n.settingsConfirmBeforeDeleting),
            value: widget.controller.confirmDelete,
            onChanged: widget.controller.setConfirmDelete,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.settingsEmptyTrashAutomatically),
                Text(context.l10n.settingsPermanentlyDeletesLocalNotesAfter),
                DropdownButton<int>(
                  key: const ValueKey('trash-retention'),
                  isExpanded: true,
                  value: widget.controller.trashRetentionDays,
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(context.l10n.settingsNever),
                    ),
                    DropdownMenuItem(
                      value: 7,
                      child: Text(context.l10n.settingsAfterDays),
                    ),
                    DropdownMenuItem(
                      value: 30,
                      child: Text(context.l10n.settingsAfterDays2),
                    ),
                    DropdownMenuItem(
                      value: 90,
                      child: Text(context.l10n.settingsAfterDays3),
                    ),
                  ],
                  onChanged: (days) {
                    if (days != null) {
                      widget.controller.setTrashRetentionDays(days);
                    }
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.settingsImagePlacement),
                Text(context.l10n.settingsAppliesToNewImagesExisting),
                DropdownButton<bool>(
                  key: const ValueKey('image-placement'),
                  isExpanded: true,
                  value: widget.controller.inlineImages,
                  items: [
                    DropdownMenuItem(
                      value: false,
                      child: Text(context.l10n.settingsAboveTextCurrent),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text(context.l10n.settingsWithinNote),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    try {
                      await widget.controller.setInlineImages(value);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.settingsCouldNotSaveImagePlacement(
                                '$error',
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          if (AutoStart.isSupported) ...[
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_outlined),
              title: Text(context.l10n.settingsAlwaysShowNoteHeader),
              subtitle: Text(
                context.l10n.settingsKeepNoteActionsVisibleWithout,
              ),
              value: widget.controller.alwaysShowNoteHeader,
              onChanged: (value) async {
                try {
                  await widget.controller.setAlwaysShowNoteHeader(value);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.settingsCouldNotSaveHeaderPreference(
                            '$error',
                          ),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            SwitchListTile(
              key: const ValueKey('reminder-task'),
              secondary: const Icon(Icons.alarm_outlined),
              title: Text(context.l10n.settingsRemindMeWhenBetternotesIs),
              subtitle: Text(
                widget.controller.reminderTaskError ??
                    context.l10n.settingsAddsAWindowsScheduledTask,
                style: widget.controller.reminderTaskError == null
                    ? null
                    : TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              value: widget.controller.reminderTaskEnabled,
              onChanged: (value) async {
                try {
                  await widget.controller.setReminderTaskEnabled(value);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.settingsCouldNotUpdateTheScheduled(
                            '$error',
                          ),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            SwitchListTile(
              key: const ValueKey('keep-in-tray'),
              secondary: const Icon(Icons.dock_outlined),
              title: Text(context.l10n.settingsKeepRunningInTheSystem),
              subtitle: Text(context.l10n.settingsClosingTheNotesWindowHides),
              value: widget.controller.keepInTray,
              onChanged: (value) async {
                try {
                  await widget.controller.setKeepInTray(value);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.settingsCouldNotChangeTrayMode('$error'),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.settingsQuickNoteShortcut),
                  Text(
                    widget.controller.quickCaptureError ??
                        context.l10n.settingsAGlobalShortcutThatOpens,
                    style: widget.controller.quickCaptureError == null
                        ? null
                        : TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  DropdownButton<String>(
                    key: const ValueKey('quick-capture'),
                    isExpanded: true,
                    value: widget.controller.quickCaptureKey,
                    onChanged: (value) async {
                      if (value == null) return;
                      try {
                        await widget.controller.setQuickCaptureKey(value);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error is PlatformException &&
                                        error.code == 'hotkey_in_use'
                                    ? context
                                          .l10n
                                          .settingsAnotherAppAlreadyUsesThat
                                    : context.l10n
                                          .settingsCouldNotSetTheShortcut(
                                            '$error',
                                          ),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    items: [
                      for (final entry in quickCapturePresets.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value.label),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SwitchListTile(
              key: const ValueKey('fast-note-opening'),
              secondary: const Icon(Icons.bolt_outlined),
              title: Text(context.l10n.settingsFastNoteOpening),
              subtitle: Text(context.l10n.settingsKeepOneIdleNoteWindow),
              value: widget.controller.fastNoteOpening,
              onChanged: (value) async {
                try {
                  await widget.controller.setFastNoteOpening(value);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.settingsCouldNotSaveThisPreference(
                            '$error',
                          ),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.settingsWindowButtons),
                  Text(context.l10n.settingsAppliesToAllBetternotesWindows),
                  DropdownButton<bool>(
                    key: const ValueKey('window-buttons'),
                    isExpanded: true,
                    value: widget.controller.customWindowButtons,
                    onChanged: (value) async {
                      if (value == null) return;
                      try {
                        await widget.controller.setCustomWindowButtons(value);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.l10n.settingsCouldNotSaveWindowButtons(
                                  '$error',
                                ),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    items: [
                      DropdownMenuItem(
                        value: false,
                        child: Text(context.l10n.settingsWindows),
                      ),
                      DropdownMenuItem(
                        value: true,
                        child: Text(context.l10n.windowChromeBetternotes),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_autoStartEnabled == null)
              ListTile(
                leading: const Icon(Icons.power_settings_new_outlined),
                title: Text(context.l10n.settingsStartWithWindows),
                subtitle: Text(
                  _loadingAutoStart
                      ? context.l10n.settingsCheckingWindowsStartupSetting
                      : context.l10n.settingsCouldNotReadWindowsStartup2,
                ),
                trailing: _loadingAutoStart
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: _loadAutoStart,
                        child: Text(context.l10n.noteRetry),
                      ),
              )
            else
              SwitchListTile(
                secondary: const Icon(Icons.power_settings_new_outlined),
                title: Text(context.l10n.settingsStartWithWindows),
                subtitle: Text(context.l10n.settingsOpenBetternotesWhenYouSign),
                value: _autoStartEnabled!,
                onChanged: _savingAutoStart ? null : _setAutoStart,
              ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(context.l10n.settingsBackupAndRestore),
            subtitle: Text(
              context.l10n.settingsCompleteBackupsIncludeTrashFormatting,
            ),
            trailing: _workingFiles
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(),
                  )
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(context.l10n.settingsExportCompleteBackup),
            onTap: _workingFiles ? null : () => _fileAction(_exportBackup),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: Text(context.l10n.settingsImportBackup),
            subtitle: backup_files.canImportBackup
                ? Text(context.l10n.settingsReviewAndAddCopiesWithout)
                : Text(context.l10n.settingsImportIsNotAvailableOn),
            enabled: !_workingFiles && backup_files.canImportBackup,
            onTap: _workingFiles || !backup_files.canImportBackup
                ? null
                : () => _fileAction(_importBackup),
          ),
          if (auto_backup.canAutoBackup) ..._autoBackupTiles(),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(context.l10n.settingsExportActiveNotesAsText),
            subtitle: Text(context.l10n.settingsTextOnlyUseAComplete),
            onTap: _workingFiles ? null : () => _fileAction(_exportText),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.keyboard_outlined),
            title: Text(context.l10n.settingsKeyboardShortcuts),
            subtitle: Text(context.l10n.settingsEditingSearchAndWindowControls),
            onTap: () => showShortcutsHelp(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.l10n.aboutTitle),
            subtitle: Text(context.l10n.settingsAboutSubtitle(appVersionLabel)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AboutPage(controller: widget.controller),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

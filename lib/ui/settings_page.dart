import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/sign_in.dart';
import '../data/backup.dart';
import '../data/backup_files.dart' as backup_files;
import '../desktop/auto_start.dart';
import '../desktop/window_chrome.dart';
import '../state/notes_controller.dart';
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
          SnackBar(content: Text('File operation failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _workingFiles = false);
    }
  }

  Future<String?> _exportBackup() async {
    final bytes = await widget.controller.exportBackup();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final saved = await backup_files.saveBackupFile(
      bytes,
      'BetterNotes-backup-$date.zip',
    );
    return saved
        ? 'Backup exported. Keep this readable file in a safe place.'
        : null;
  }

  Future<String?> _exportText() async {
    final text = await widget.controller.exportText();
    final saved = await backup_files.saveBackupFile(
      Uint8List.fromList(utf8.encode(text)),
      'BetterNotes-notes.txt',
      mimeType: 'text/plain',
    );
    return saved
        ? 'Text exported. Use a complete backup to restore images and formatting.'
        : null;
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
          title: const Text('Import backup as copies?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${backup.notes.length} notes (${backup.trashCount} in Trash), ${backup.assets.length} images.\n\nExisting notes are kept. Importing the same backup again creates more copies.',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Restore appearance and editor preferences',
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import copies'),
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
          content: Text('Could not read Windows startup setting: $error'),
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
          SnackBar(content: Text('Could not change Windows startup: $error')),
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
        title: const WindowTitle(
          child: Text('Settings', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        actions: const [WindowButtons(), SizedBox(width: 8)],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(widget.controller.email ?? 'Local notes'),
            subtitle: Text(
              widget.controller.cloudAvailable
                  ? widget.controller.signedIn
                        ? 'Your notes can sync across devices.'
                        : 'Sign in with Google to sync your notes.'
                  : 'Google sync needs a Supabase project connection.',
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
                          SnackBar(content: Text('Sign-in failed: $error')),
                        );
                      }
                    }
                  },
                  child: const Text('Continue with Google'),
                ),
              ),
            ),
          if (widget.controller.signedIn)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
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
              title: const Text('Sync needs attention'),
              subtitle: Text(widget.controller.syncError!),
              trailing: TextButton(
                onPressed: widget.controller.sync,
                child: const Text('Retry'),
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Appearance'),
                DropdownButton<ThemeMode>(
                  isExpanded: true,
                  value: widget.controller.themeMode,
                  onChanged: (mode) {
                    if (mode != null) widget.controller.setTheme(mode);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.delete_outline),
            title: const Text('Confirm before deleting'),
            value: widget.controller.confirmDelete,
            onChanged: widget.controller.setConfirmDelete,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Image placement'),
                const Text(
                  'Applies to new images. Existing images stay in place.',
                ),
                DropdownButton<bool>(
                  key: const ValueKey('image-placement'),
                  isExpanded: true,
                  value: widget.controller.inlineImages,
                  items: const [
                    DropdownMenuItem(
                      value: false,
                      child: Text('Above text (current)'),
                    ),
                    DropdownMenuItem(value: true, child: Text('Within note')),
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
                              'Could not save image placement: $error',
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
              title: const Text('Always show note header'),
              subtitle: const Text(
                'Keep note actions visible without hovering.',
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
                          'Could not save header preference: $error',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            SwitchListTile(
              key: const ValueKey('fast-note-opening'),
              secondary: const Icon(Icons.bolt_outlined),
              title: const Text('Fast note opening'),
              subtitle: const Text(
                'Keep one idle note window ready. Uses some memory; turn off '
                'to open notes a little slower.',
              ),
              value: widget.controller.fastNoteOpening,
              onChanged: (value) async {
                try {
                  await widget.controller.setFastNoteOpening(value);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not save this preference: $error'),
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
                  const Text('Window buttons'),
                  const Text('Applies to all BetterNotes windows.'),
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
                                'Could not save window buttons: $error',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: false, child: Text('Windows')),
                      DropdownMenuItem(value: true, child: Text('BetterNotes')),
                    ],
                  ),
                ],
              ),
            ),
            if (_autoStartEnabled == null)
              ListTile(
                leading: const Icon(Icons.power_settings_new_outlined),
                title: const Text('Start with Windows'),
                subtitle: Text(
                  _loadingAutoStart
                      ? 'Checking Windows startup setting'
                      : 'Could not read Windows startup setting',
                ),
                trailing: _loadingAutoStart
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: _loadAutoStart,
                        child: const Text('Retry'),
                      ),
              )
            else
              SwitchListTile(
                secondary: const Icon(Icons.power_settings_new_outlined),
                title: const Text('Start with Windows'),
                subtitle: const Text(
                  'Open BetterNotes when you sign in to Windows.',
                ),
                value: _autoStartEnabled!,
                onChanged: _savingAutoStart ? null : _setAutoStart,
              ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup and restore'),
            subtitle: const Text(
              'Complete backups include Trash, formatting, images, and drawings. Exported files are readable and unencrypted.',
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
            title: const Text('Export complete backup'),
            onTap: _workingFiles ? null : () => _fileAction(_exportBackup),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Import backup'),
            subtitle: backup_files.canImportBackup
                ? const Text(
                    'Review and add copies without replacing existing notes.',
                  )
                : const Text('Import is not available on this platform.'),
            enabled: !_workingFiles && backup_files.canImportBackup,
            onTap: _workingFiles || !backup_files.canImportBackup
                ? null
                : () => _fileAction(_importBackup),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Export active notes as text'),
            subtitle: const Text(
              'Text only; use a complete backup for restoration.',
            ),
            onTap: _workingFiles ? null : () => _fileAction(_exportText),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.keyboard_outlined),
            title: const Text('Keyboard shortcuts'),
            subtitle: const Text('Editing, search, and window controls.'),
            onTap: () => showShortcutsHelp(context),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('BetterNotes'),
            subtitle: Text('A colorful home for little ideas.'),
          ),
        ],
      ),
    ),
  );
}

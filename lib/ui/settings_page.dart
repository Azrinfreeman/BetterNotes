import 'package:flutter/material.dart';

import '../auth/sign_in.dart';
import '../desktop/auto_start.dart';
import '../desktop/window_chrome.dart';
import '../state/notes_controller.dart';

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
        title: const WindowTitle(child: Text('Settings')),
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
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Appearance'),
            trailing: DropdownButton<ThemeMode>(
              value: widget.controller.themeMode,
              onChanged: (mode) {
                if (mode != null) widget.controller.setTheme(mode);
              },
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
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
            ListTile(
              leading: const Icon(Icons.web_asset_outlined),
              title: const Text('Window buttons'),
              subtitle: const Text('Applies to all BetterNotes windows.'),
              trailing: DropdownButton<bool>(
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

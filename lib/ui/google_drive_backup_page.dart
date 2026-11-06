import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;

import '../data/backup.dart';
import '../data/device_label.dart';
import '../data/google_drive_account.dart';
import '../data/google_drive_auth.dart';
import '../data/google_drive_backup.dart';
import '../data/google_drive_client.dart';
import '../data/google_drive_config.dart';
import '../data/google_drive_errors.dart';
import '../l10n/l10n.dart';
import '../state/notes_controller.dart';

class GoogleDriveBackupPage extends StatefulWidget {
  const GoogleDriveBackupPage({
    super.key,
    required this.controller,
    this.initialClient,
  });
  final NotesController controller;

  /// An already authenticated client, used by tests to skip browser sign-in.
  @visibleForTesting
  final http.Client? initialClient;

  @override
  State<GoogleDriveBackupPage> createState() => _GoogleDriveBackupPageState();
}

class _GoogleDriveBackupPageState extends State<GoogleDriveBackupPage> {
  GoogleDriveAuthorization? _authorization;
  http.Client? _client;
  GoogleDriveAccount? _account;
  List<DriveSnapshot> _snapshots = [];
  bool _busy = false;
  bool _signInCancelled = false;
  String? _status;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _client = widget.initialClient;
    widget.controller.addListener(_onController);
    if (_client == null) unawaited(_restoreSession());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _authorization?.cancel();
    _client?.close();
    super.dispose();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  /// Reuses a sign-in saved for automatic backup so the screen opens connected.
  Future<void> _restoreSession() async {
    final token = await widget.controller.driveSessions.readRefreshToken();
    if (token == null || !mounted) return;
    final client = googleDriveClientFromRefreshToken(token);
    setState(() => _client = client);
    try {
      final account = await GoogleDriveAccount.fetch(client);
      final items = await GoogleDriveBackup(client).list();
      if (!mounted) return;
      setState(() {
        _account = account;
        _snapshots = items;
      });
    } catch (error) {
      if (!mounted) return;
      if (classifyDriveError(error) == DriveFailure.denied) {
        final message = context.l10n.driveSessionExpired;
        client.close();
        setState(() => _client = null);
        await widget.controller.forgetDriveSession();
        _notice(message, failed: true);
      }
      // Transient failures keep the client; Refresh reports the error.
    }
  }

  void _notice(String message, {bool failed = false}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _failed = failed;
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
      _failed = false;
      _signInCancelled = false;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      final l10n = context.l10n;
      final cancelled = _signInCancelled;
      setState(() {
        _failed = !cancelled;
        _status = cancelled ? l10n.driveSignInCancelled : _messageFor(error);
      });
    } finally {
      _signInCancelled = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(Object error) {
    final l10n = context.l10n;
    switch (classifyDriveError(error)) {
      case DriveFailure.notConfigured:
        return l10n.driveErrorNotConfigured;
      case DriveFailure.denied:
        // Google's own reason (e.g. invalid_client) makes setup mistakes
        // diagnosable instead of looking like a user cancellation.
        final detail = error is oauth2.AuthorizationException
            ? ' (${error.error}${error.description == null ? '' : ': ${error.description}'})'
            : '';
        return '${l10n.driveErrorDenied}$detail';
      case DriveFailure.timedOut:
        return l10n.driveErrorTimedOut;
      case DriveFailure.network:
        return l10n.driveErrorNetwork;
      case DriveFailure.integrity:
        return l10n.driveErrorIntegrity;
      case DriveFailure.other:
        // Export and verification failures explain themselves.
        if (error is StateError && error.message.isNotEmpty) {
          return error.message;
        }
        // Surface Google's own reason (e.g. 403 API not enabled) so setup
        // problems are diagnosable.
        if (error is drive.DetailedApiRequestError) {
          return '${l10n.driveErrorGeneric} (${error.status}: ${error.message})';
        }
        return l10n.driveErrorGeneric;
    }
  }

  Future<void> _connect() => _perform(() async {
    final authorization = GoogleDriveAuthorization(
      clientId: googleDriveDesktopClientId,
      clientSecret: googleDriveDesktopClientSecret,
    );
    _authorization = authorization;
    try {
      final client = await authorization.connect();
      if (!mounted) {
        client.close();
        return;
      }
      final account = await GoogleDriveAccount.fetch(client);
      if (!mounted) {
        client.close();
        return;
      }
      _client?.close();
      setState(() {
        _client = client;
        _account = account;
      });
      final refreshToken = client.credentials.refreshToken;
      if (widget.controller.driveAutoEnabled && refreshToken != null) {
        await widget.controller.saveDriveSession(
          refreshToken: refreshToken,
          email: account?.email,
        );
      }
      await _refresh();
    } finally {
      _authorization = null;
    }
  });

  Future<void> _setAuto(bool enabled) {
    final l10n = context.l10n;
    return _perform(() async {
      final controller = widget.controller;
      if (!enabled) {
        await controller.setDriveAutoEnabled(false);
        _notice(l10n.driveAutoOff);
        return;
      }
      final client = _client;
      final token = client is oauth2.Client
          ? client.credentials.refreshToken
          : null;
      if (token == null) {
        _notice(l10n.driveAutoNeedsSignIn, failed: true);
        return;
      }
      await controller.saveDriveSession(
        refreshToken: token,
        email: _account?.email,
      );
      if (!await controller.setDriveAutoEnabled(true)) {
        _notice(l10n.driveAutoNeedsSignIn, failed: true);
        return;
      }
      _notice(l10n.driveAutoOn);
    });
  }

  Future<void> _disconnect() async {
    final l10n = context.l10n;
    _client?.close();
    setState(() {
      _client = null;
      _account = null;
      _snapshots = [];
    });
    try {
      await widget.controller.forgetDriveSession();
    } catch (_) {
      _notice(l10n.driveErrorGeneric, failed: true);
    }
  }

  String _autoStatus() {
    final l10n = context.l10n;
    final controller = widget.controller;
    if (controller.driveAutoRunning) return l10n.driveAutoRunning;
    final error = controller.driveAutoError;
    if (error != null) return error;
    final last = controller.driveAutoLast;
    if (last == null) return l10n.driveAutoPending;
    return l10n.driveAutoLastAt(last.toLocal().toString().substring(0, 16));
  }

  Future<void> _refresh() async {
    final items = await GoogleDriveBackup(_client!).list();
    if (mounted) setState(() => _snapshots = items);
  }

  Future<void> _backup() => _perform(() async {
    late final Uint8List bytes;
    try {
      bytes = await widget.controller.exportBackup();
    } on StateError catch (error) {
      _notice(error.message, failed: true);
      return;
    }
    final drive = GoogleDriveBackup(_client!);
    await drive.upload(bytes, device: localDeviceLabel);
    // Retention is per device: this never deletes another machine's backups.
    final pruned = await drive.pruneDevice(device: localDeviceLabel);
    await _refresh();
    if (!mounted) return;
    final l10n = context.l10n;
    if (pruned.failed > 0) {
      _notice(l10n.drivePruneFailed(pruned.failed), failed: true);
    } else if (pruned.removed > 0) {
      _notice(l10n.driveUploadedPruned(pruned.removed));
    } else {
      _notice(l10n.driveUploaded);
    }
  });

  Future<void> _cleanPending() => _perform(() async {
    final result = await GoogleDriveBackup(_client!).discardPending();
    await _refresh();
    if (!mounted) return;
    if (result.failed > 0) {
      _notice(
        context.l10n.drivePendingPartlyRemoved(result.removed, result.failed),
        failed: true,
      );
      return;
    }
    _notice(
      result.removed == 0
          ? context.l10n.drivePendingNone
          : context.l10n.drivePendingRemoved(result.removed),
    );
  });

  Future<void> _import(DriveSnapshot snapshot) => _perform(() async {
    final l10n = context.l10n;
    final owner = widget.controller.ownerId;
    final bytes = await GoogleDriveBackup(_client!).download(snapshot);
    final backup = await compute(NoteBackup.validate, bytes);
    if (!mounted) return;
    var preferences = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(l10n.driveImportTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.driveImportSummary(
                    backup.notes.length,
                    backup.trashCount,
                    backup.assets.length,
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.driveRestorePreferences),
                  value: preferences,
                  onChanged: (value) =>
                      update(() => preferences = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.driveCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.driveImportCopies),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await widget.controller.importBackup(
      backup,
      restorePreferences: preferences,
      expectedOwner: owner,
    );
    _notice(l10n.driveImported(backup.notes.length));
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final configured = googleDriveDesktopClientId.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.driveTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.driveIntro),
          const SizedBox(height: 4),
          Text(l10n.driveRetentionNote, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          if (_client == null)
            if (!configured)
              Text(l10n.driveNotConfigured)
            else
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _busy ? null : _connect,
                  child: Text(l10n.driveConnect),
                ),
              )
          else ...[
            Text(
              _account == null
                  ? l10n.driveAccountUnknown
                  : l10n.driveAccount(_account!.email),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : _backup,
                  child: Text(l10n.driveBackupNow),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _perform(_refresh),
                  child: Text(l10n.driveRefresh),
                ),
                TextButton(
                  onPressed: _busy ? null : _cleanPending,
                  child: Text(l10n.driveCleanPending),
                ),
                TextButton(
                  onPressed: _busy ? null : _disconnect,
                  child: Text(l10n.driveDisconnect),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.driveAutoTitle),
              subtitle: Text(l10n.driveAutoSubtitle),
              value: widget.controller.driveAutoEnabled,
              onChanged: _busy ? null : _setAuto,
            ),
            if (widget.controller.driveAutoEnabled)
              Text(
                _autoStatus(),
                style: widget.controller.driveAutoError != null
                    ? TextStyle(color: theme.colorScheme.error)
                    : theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            if (_snapshots.isEmpty)
              Text(l10n.driveNoBackups)
            else ...[
              Text(
                l10n.driveSnapshotsHeader,
                style: theme.textTheme.titleSmall,
              ),
              for (final snapshot in _snapshots)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(snapshot.device),
                  subtitle: Text(
                    l10n.driveSnapshotDetails(
                      snapshot.createdAt.toLocal().toString().substring(0, 16),
                      (snapshot.size / 1024 / 1024).toStringAsFixed(1),
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: _busy ? null : () => _import(snapshot),
                    child: Text(l10n.driveImport),
                  ),
                ),
            ],
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            if (_authorization != null)
              TextButton(
                onPressed: () {
                  _signInCancelled = true;
                  _authorization?.cancel();
                },
                child: Text(l10n.driveCancelSignIn),
              ),
          ],
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _status!,
                  style: _failed
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';

import '../data/html_paste.dart';

/// Shares a single completed copy operation between shortcuts and menus.
class NoteQuillController extends quill.QuillController {
  NoteQuillController({
    required super.document,
    required super.selection,
    required super.config,
    required this.noteId,
    required this.onClipboardError,
  });

  final String noteId;
  final void Function(Object error) onClipboardError;
  static const _clipboard = MethodChannel('betternotes/clipboard');
  static String? _localCopy;
  Future<void>? _copying;
  bool _disposed = false;

  bool get _windows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Quill groups nearby changes by time; isolate cleanup on both sides.
  void applyCleanup(Delta change, TextSelection mappedSelection) {
    if (readOnly || change.isEmpty) return;
    document.history.lastRecorded = 0;
    try {
      compose(change, selection, quill.ChangeSource.local);
      updateSelection(mappedSelection, quill.ChangeSource.local);
    } finally {
      document.history.lastRecorded = 0;
    }
  }

  @override
  bool clipboardSelection(bool copy) {
    if (!selection.isValid || selection.isCollapsed || (!copy && readOnly)) {
      return false;
    }
    unawaited(copySelection(copy: copy));
    return true;
  }

  Future<void> copySelection({bool copy = true}) async {
    if (_copying != null) return _copying;
    final selected = selection;
    if (!selected.isValid || selected.isCollapsed || (!copy && readOnly)) {
      return;
    }
    final before = jsonEncode(document.toDelta().toJson());
    final delta = document.toDelta().slice(selected.start, selected.end);
    final text = document.getPlainText(
      selected.start,
      selected.end - selected.start,
      // Match Quill's existing selection serialization for embedded objects.
      // ignore: invalid_use_of_internal_member
      includeEmbeds: true,
    );
    final data = jsonEncode({
      'version': 1,
      'noteId': noteId,
      'text': text,
      'delta': delta.toJson(),
    });
    Future<void> write() async {
      try {
        if (_windows) {
          await _nativeCall<void>('write', {
            'text': text,
            'data': data,
            'html': clipboardHtml(deltaToHtml(delta)),
          });
        } else {
          await Clipboard.setData(ClipboardData(text: text));
          _localCopy = data;
        }
        if (!copy &&
            !_disposed &&
            !readOnly &&
            selection == selected &&
            jsonEncode(document.toDelta().toJson()) == before) {
          replaceText(
            selected.start,
            selected.end - selected.start,
            '',
            TextSelection.collapsed(offset: selected.start),
          );
        }
      } catch (error) {
        if (!_disposed) onClipboardError(error);
      }
    }

    final operation = write();
    _copying = operation;
    try {
      await operation;
    } finally {
      _copying = null;
    }
  }

  Future<T?> _nativeCall<T>(String method, [Object? args]) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _clipboard.invokeMethod<T>(method, args);
      } on PlatformException catch (error) {
        if (error.code != 'clipboard_busy' || attempt == 3) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    }
  }

  /// Called by the existing paste hook, after image and URL handling:
  /// BetterNotes' own copy first, then HTML from other programs.
  Future<bool> pasteCopiedText() async =>
      await _pasteOwnCopy() || await _pasteHtml();

  /// Formatted paste from other programs (Windows "HTML Format").
  Future<bool> _pasteHtml() async {
    if (!_windows) return false;
    await _copying;
    if (_disposed || readOnly) return false;
    final selected = selection;
    if (!selected.isValid) return false;
    final before = jsonEncode(document.toDelta().toJson());
    try {
      final raw = await _nativeCall<String>('read_html');
      if (raw == null || raw.isEmpty) return false;
      final fragment = htmlFragmentFromClipboard(raw);
      final delta = fragment == null ? null : htmlToNoteDelta(fragment);
      if (delta == null ||
          _disposed ||
          selection != selected ||
          jsonEncode(document.toDelta().toJson()) != before) {
        return false;
      }
      replaceText(selected.start, selected.end - selected.start, delta, null);
      updateSelection(
        TextSelection.collapsed(
          offset:
              selected.start +
              delta.toList().fold<int>(0, (length, op) => length + op.length!),
        ),
        quill.ChangeSource.local,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _pasteOwnCopy() async {
    await _copying;
    if (_disposed || readOnly) return false;
    final selected = selection;
    final before = jsonEncode(document.toDelta().toJson());
    try {
      final raw = _windows ? await _nativeCall<String>('read') : _localCopy;
      if (raw == null || raw.isEmpty) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (_disposed ||
          selection != selected ||
          !selected.isValid ||
          jsonEncode(document.toDelta().toJson()) != before ||
          data['version'] != 1 ||
          text == null ||
          text != data['text']) {
        return false;
      }
      final operations = List<dynamic>.from(data['delta'] as List);
      // Image IDs belong to a note. Reuse only within that note; another note
      // gets the text rather than an inaccessible attachment reference.
      if (data['noteId'] != noteId &&
          operations.any((op) => (op as Map)['insert'] is! String)) {
        return false;
      }
      final delta = Delta.fromJson(operations);
      if (delta.isEmpty || delta.toList().any((op) => !op.isInsert)) {
        return false;
      }
      replaceText(selected.start, selected.end - selected.start, delta, null);
      updateSelection(
        TextSelection.collapsed(
          offset:
              selected.start +
              delta.toList().fold<int>(0, (length, op) => length + op.length!),
        ),
        quill.ChangeSource.local,
      );
      return true;
    } catch (_) {
      // Foreign/malformed custom data must not prevent ordinary text paste.
      return false;
    }
  }

  @override
  Future<bool> clipboardPaste({void Function()? updateEditor}) async {
    await _copying;
    if (_disposed) return true;
    // Keep Quill's current public paste entry point behind this adapter.
    // ignore: experimental_member_use
    return super.clipboardPaste(updateEditor: updateEditor);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

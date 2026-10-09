import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:share_plus/share_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../data/clipboard_image.dart';
import '../data/backup_files.dart' show saveBackupFile;
import '../data/markdown_export.dart';
import '../data/note.dart';
import '../data/pdf_export.dart';
import '../state/note_editor_store.dart';
import 'drawing_page.dart';
import 'find_bar.dart';
import 'note_desktop_header.dart';
import 'note_details_dialog.dart';
import 'note_image_embed.dart';
import 'shortcuts_help.dart';
import 'version_history.dart';
import 'text_color_dialog.dart';
import 'text_style_panel.dart';

class NotePage extends StatefulWidget {
  const NotePage({
    super.key,
    required this.controller,
    required this.noteId,
    this.onClose,
    this.closeRequests,
    this.clipboardImageReader,
    this.onNewNote,
    this.onFindNotes,
  });
  final NoteEditorStore controller;
  final String noteId;
  final Future<void> Function()? onClose;
  final ValueListenable<int>? closeRequests;
  final Future<Uint8List?> Function()? clipboardImageReader;
  final Future<void> Function()? onNewNote;
  final Future<void> Function()? onFindNotes;

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> with WidgetsBindingObserver {
  late final quill.QuillController _editor;
  final FocusNode _editorFocus = FocusNode();
  final _quillKey = GlobalKey<quill.QuillEditorState>();
  final _findText = TextEditingController();
  final _findFocus = FocusNode();
  bool _finding = false;
  bool _showTextStyle = false;
  List<({int start, int end})> _matches = [];
  int _matchIndex = -1;
  final Set<String> _inlineIds = {};
  bool _addingImage = false;
  bool _secondaryPointer = false;

  bool get _desktopEditorMenu =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void>? _imageOperation;
  Timer? _saveTimer;
  bool _closing = false;
  bool _closeInProgress = false;
  Timer? _headerTimer;
  bool _headerHovered = false;
  bool _headerFocused = false;
  bool _headerBusy = false;
  bool _headerVisible = true;
  bool _touchHeader = false;
  bool _alwaysOnTop = false;
  Future<void>? _saving;
  String? _saveError;
  late String _observedDocument;
  late String _savedDocument;
  bool _disposed = false;

  bool get _desktopNote =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.windows &&
      widget.onClose != null;

  bool get _keepHeaderVisible =>
      widget.controller.alwaysShowNoteHeader ||
      _touchHeader ||
      MediaQuery.accessibleNavigationOf(context) ||
      MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    final note = widget.controller.noteById(widget.noteId)!;
    _observedDocument = _savedDocument = jsonEncode(note.delta);
    _inlineIds.addAll(inlineImageIds(note.delta));
    _editor = quill.QuillController(
      document: quill.Document.fromJson(note.delta),
      selection: const TextSelection.collapsed(offset: 0),
      config: quill.QuillControllerConfig(
        // Quill's paste hook serializes image handling with normal text paste.
        // ignore: experimental_member_use
        clipboardConfig: quill.QuillClipboardConfig(
          // ignore: experimental_member_use
          onClipboardPaste: _pasteClipboard,
        ),
      ),
    );
    _editor.addListener(_scheduleSave);
    widget.controller.registerEditor(widget.noteId, _flush);
    WidgetsBinding.instance.addObserver(this);
    widget.closeRequests?.addListener(_onExternalClose);
    HardwareKeyboard.instance.addHandler(_handleAppKey);
    if (_desktopNote) {
      _hideHeaderLater();
      unawaited(_readAlwaysOnTop());
    }
  }

  Future<void> _readAlwaysOnTop() async {
    try {
      final pinned = await windowManager.isAlwaysOnTop();
      if (mounted) setState(() => _alwaysOnTop = pinned);
    } catch (error) {
      if (mounted) _message('Could not read always on top: $error');
    }
  }

  Future<void> _toggleAlwaysOnTop() async {
    try {
      final pinned = !_alwaysOnTop;
      await windowManager.setAlwaysOnTop(pinned);
      if (mounted) setState(() => _alwaysOnTop = pinned);
    } catch (error) {
      if (mounted) _message('Could not change always on top: $error');
    }
  }

  void _showHeader() {
    _headerTimer?.cancel();
    if (!_headerVisible) setState(() => _headerVisible = true);
  }

  void _hideHeaderLater() {
    _headerTimer?.cancel();
    _headerTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted &&
          !_keepHeaderVisible &&
          !_headerHovered &&
          !_headerFocused &&
          !_headerBusy) {
        setState(() => _headerVisible = false);
      }
    });
  }

  void _setHeaderBusy(bool busy) {
    _headerBusy = busy;
    if (busy) {
      _showHeader();
    } else {
      _hideHeaderLater();
    }
  }

  void _openFind() {
    setState(() => _finding = true);
    _updateMatches(select: true);
    _findFocus.requestFocus();
  }

  void _dismissFind() {
    setState(() => _finding = false);
    _editorFocus.requestFocus();
  }

  void _updateMatches({bool select = false}) {
    final query = _findText.text;
    final text = _editor.document.toPlainText();
    _matches = query.isEmpty
        ? []
        : RegExp(RegExp.escape(query), caseSensitive: false)
              .allMatches(text)
              .map((match) => (start: match.start, end: match.end))
              .toList();
    _matchIndex = _matches.isEmpty ? -1 : 0;
    if (select && _matches.isNotEmpty) _selectMatch();
    if (select && _matches.isEmpty) {
      _editor.skipRequestKeyboard = true;
      _editor.updateSelection(
        TextSelection.collapsed(offset: _editor.selection.baseOffset),
        quill.ChangeSource.local,
      );
      _editor.skipRequestKeyboard = false;
    }
    if (mounted) setState(() {});
  }

  void _selectMatch() {
    final match = _matches[_matchIndex];
    _editor.skipRequestKeyboard = true;
    _editor.updateSelection(
      TextSelection(baseOffset: match.start, extentOffset: match.end),
      quill.ChangeSource.local,
    );
    _editor.skipRequestKeyboard = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final editorContext = _quillKey.currentContext;
      if (editorContext != null) {
        unawaited(Scrollable.ensureVisible(editorContext));
      }
      _quillKey.currentState?.editableTextKey.currentState?.bringIntoView(
        TextPosition(offset: match.start),
      );
    });
  }

  void _nextMatch(int direction) {
    if (_matches.isEmpty) return;
    setState(() => _matchIndex = (_matchIndex + direction) % _matches.length);
    _selectMatch();
  }

  Future<void> _editDetails(Note note) async {
    try {
      final details = await showNoteDetailsDialog(
        context,
        note,
        suggestions: widget.controller.availableTags,
      );
      if (details == null) return;
      await _flush();
      final current = widget.controller.noteById(note.id);
      if (current != null) {
        await widget.controller.save(
          current.copyWith(title: details.title, tags: details.tags.split(',')),
        );
      }
    } catch (error) {
      if (mounted) _message('Could not save details: $error');
    }
  }

  Future<void> _organizationAction(String value, Note note) async {
    if (value == 'help') {
      await showShortcutsHelp(context);
      return;
    }
    if (value == 'details') {
      await _editDetails(note);
      return;
    }
    if (value == 'find') {
      _openFind();
      return;
    }
    if (value == 'history') {
      await showVersionHistory(context, widget.controller, note);
      return;
    }
    if (value == 'markdown' || value == 'pdf') {
      try {
        await _flush();
        final current = widget.controller.noteById(note.id) ?? note;
        final file = value == 'pdf'
            ? await exportPdf(current, widget.controller.image)
            : await exportMarkdown([current], widget.controller.image);
        final saved = await saveBackupFile(
          file.bytes,
          file.name,
          mimeType: file.mimeType,
        );
        if (saved && mounted) _message('Exported "${file.name}".');
      } catch (error) {
        if (mounted) _message('Could not export: $error');
      }
      return;
    }
    if (value == 'duplicate') {
      try {
        final copy = await widget.controller.duplicate(note.id);
        if (copy != null && mounted) {
          _message('Duplicated as "${copy.displayTitle}".');
        }
      } catch (error) {
        if (mounted) _message('Could not duplicate note: $error');
      }
      return;
    }
    try {
      await _flush();
      final current = widget.controller.noteById(note.id);
      if (current == null) return;
      if (value == 'favorite') {
        await widget.controller.save(
          current.copyWith(favorite: !current.favorite),
        );
      }
      if (value == 'archive') {
        await widget.controller.archive(note.id);
        await _close();
      }
    } catch (error) {
      if (mounted) _message('Could not update note: $error');
    }
  }

  List<PopupMenuEntry<String>> _organizationItems(Note note) => [
    PopupMenuItem(
      enabled: false,
      height: 32,
      child: Text(_statsLabel(), style: Theme.of(context).textTheme.bodySmall),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem(value: 'details', child: Text('Title and tags')),
    PopupMenuItem(
      value: 'favorite',
      child: Text(note.favorite ? 'Remove favorite' : 'Favorite'),
    ),
    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate note')),
    const PopupMenuItem(value: 'history', child: Text('Version history')),
    const PopupMenuItem(value: 'markdown', child: Text('Export as Markdown')),
    const PopupMenuItem(value: 'pdf', child: Text('Export as PDF (to print)')),
    const PopupMenuItem(value: 'archive', child: Text('Archive note')),
    const PopupMenuItem(value: 'find', child: Text('Find in note (Ctrl+H)')),
    const PopupMenuItem(value: 'help', child: Text('Keyboard shortcuts (F1)')),
    const PopupMenuDivider(),
  ];

  String _statsLabel() {
    final stats = textStats(_editor.document.toPlainText());
    String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
    return '${plural(stats.words, 'word')} · '
        '${plural(stats.characters, 'character')}'
        '${stats.minutes > 0 ? ' · ${stats.minutes} min read' : ''}';
  }

  Future<void> _headerMenuAction(String value, Note note) async {
    try {
      if (value == 'share') {
        await SharePlus.instance.share(ShareParams(text: note.textForExport));
      } else if (value == 'delete') {
        await _delete(note);
      } else if (value == 'minimize') {
        await windowManager.minimize();
      } else {
        await _organizationAction(value, note);
      }
    } finally {
      if (mounted) _setHeaderBusy(false);
    }
  }

  void _onExternalClose() => unawaited(_close());

  bool _handleAppKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        mounted &&
        (ModalRoute.of(context)?.isCurrent ?? false) &&
        event.logicalKey == LogicalKeyboardKey.f1) {
      unawaited(showShortcutsHelp(context));
      return true;
    }
    if (event is KeyDownEvent &&
        mounted &&
        (ModalRoute.of(context)?.isCurrent ?? false) &&
        _finding &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _dismissFind();
      return true;
    }
    if (event is! KeyDownEvent ||
        !mounted ||
        !(ModalRoute.of(context)?.isCurrent ?? false) ||
        !(HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      return false;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyH:
        _openFind();
        return true;
      case LogicalKeyboardKey.keyV:
        if (HardwareKeyboard.instance.isShiftPressed && _editorFocus.hasFocus) {
          unawaited(_pastePlainText());
          return true;
        }
        // The focused editor awaits image paste before falling back to text.
        if (!_editorFocus.hasFocus && !_findFocus.hasFocus) {
          unawaited(_pasteImage(silentWhenEmpty: true));
        }
        return false;
      case LogicalKeyboardKey.keyN:
        if (widget.onNewNote != null) {
          unawaited(widget.onNewNote!());
          return true;
        }
        break;
      case LogicalKeyboardKey.keyF:
        if (widget.onFindNotes != null) {
          unawaited(_findLibrary());
          return true;
        }
        break;
      case LogicalKeyboardKey.keyW:
        unawaited(_close());
        return true;
      case LogicalKeyboardKey.keyD:
        final note = widget.controller.noteById(widget.noteId);
        if (note != null) unawaited(_delete(note));
        return note != null;
      case LogicalKeyboardKey.keyT:
        if (!_editorFocus.hasFocus) return false;
        final strike = quill.Attribute.strikeThrough;
        final active = _editor.getSelectionStyle().attributes.containsKey(
          strike.key,
        );
        _editor.formatSelection(
          active ? quill.Attribute.clone(strike, null) : strike,
        );
        return true;
    }
    return false;
  }

  void _scheduleSave() {
    final delta = _editor.document.toDelta().toJson();
    final encoded = jsonEncode(delta);
    if (encoded == _observedDocument) return; // Selection is not an edit.
    _observedDocument = encoded;
    if (_finding) _updateMatches();
    _inlineIds.addAll(inlineImageIds(delta));
    if (mounted) setState(() {});
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), _autoSave);
  }

  Future<void> _findLibrary() async {
    try {
      await _flush();
      await widget.onFindNotes!();
    } catch (_) {
      if (mounted) {
        _message('Save failed. Retry before returning to your notes.');
      }
    }
  }

  void _autoSave() async {
    try {
      await _persist();
    } catch (_) {
      /* Retry remains available. */
    }
  }

  Future<void> _flush() async {
    _saveTimer?.cancel();
    final adding = _imageOperation;
    if (adding != null) await adding;
    await _persist();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _autoSave();
  }

  Future<void> _persist() {
    if (_saving != null) return _saving!;
    final future = _saveDocument();
    _saving = future;
    if (mounted) setState(() {});
    return future.whenComplete(() {
      _saving = null;
      if (mounted) setState(() {});
    });
  }

  Future<void> _saveDocument() async {
    while (!_disposed && !_closing) {
      final note = widget.controller.noteById(widget.noteId);
      if (note == null || note.archivedAt != null || _closing) return;
      final delta = _editor.document.toDelta().toJson();
      final plainText = _editor.document
          .toPlainText()
          .replaceAll('\uFFFC', '')
          .trimRight();
      final images = <String>{
        ...note.images.where((id) => !_inlineIds.contains(id)),
        ...inlineImageIds(delta),
      }.toList();
      if (plainText == note.plainText &&
          jsonEncode(delta) == jsonEncode(note.delta) &&
          listEquals(images, note.images)) {
        _savedDocument = jsonEncode(delta);
        _saveError = null;
        return;
      }
      try {
        await widget.controller.save(
          note.copyWith(delta: delta, plainText: plainText, images: images),
        );
        _savedDocument = jsonEncode(delta);
        _saveError = null;
        if (jsonEncode(_editor.document.toDelta().toJson()) == _savedDocument) {
          _observedDocument = _savedDocument;
          return;
        }
      } catch (error) {
        _saveError = 'Save failed. Your edits are still open.';
        rethrow;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    widget.controller.unregisterEditor(widget.noteId);
    WidgetsBinding.instance.removeObserver(this);
    _headerTimer?.cancel();
    _saveTimer?.cancel();
    widget.closeRequests?.removeListener(_onExternalClose);
    HardwareKeyboard.instance.removeHandler(_handleAppKey);
    _editor.removeListener(_scheduleSave);
    _editor.dispose();
    _editorFocus.dispose();
    _findText.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closeInProgress) return;
    _closeInProgress = true;
    try {
      await _flush();
      if (!mounted) return;
      setState(() => _closing = true);
      if (widget.onClose != null) {
        await widget.onClose!();
      } else if (mounted) {
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.of(context).pop();
      }
    } catch (_) {
      _closing = false;
      if (mounted) {
        _message('Save failed. Retry saving before closing, or keep editing.');
      }
    } finally {
      _closeInProgress = false;
    }
  }

  Future<void> _delete(Note note) async {
    if (widget.controller.confirmDelete) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete this note?'),
          content: const Text(
            'Move this note to Trash? You can restore it later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (result != true) return;
    }
    try {
      await _flush();
      await widget.controller.delete(
        widget.controller.noteById(note.id) ?? note,
      );
      _closing = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Moved to Trash'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  await widget.controller.restore(note.id);
                } catch (error) {
                  if (mounted) _message('Could not restore: $error');
                }
              },
            ),
          ),
        );
      }
      if (widget.onClose != null) {
        await widget.onClose!();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      _closing = false;
      if (mounted) _message('Could not move to Trash: $error');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) return;
      final bytes = await prepareNoteImage(await image.readAsBytes());
      await _addImage(bytes);
    } catch (error) {
      if (mounted) _message('Could not add image: $error');
    }
  }

  static final _urlPattern = RegExp(r'^https?://\S+$', caseSensitive: false);

  /// Image first; then a URL pasted over a selection becomes a link on that
  /// text. Returning false lets the editor perform its normal text paste.
  Future<bool> _pasteClipboard() async {
    if (await _pasteImage(silentWhenEmpty: true)) return true;
    final selection = _editor.selection;
    if (!selection.isValid || selection.isCollapsed) return false;
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text == null || !_urlPattern.hasMatch(text)) return false;
    _editor.formatText(
      selection.start,
      selection.end - selection.start,
      quill.LinkAttribute(text),
    );
    return true;
  }

  /// Ctrl+Shift+V: inserts clipboard text without any formatting.
  Future<void> _pastePlainText() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || text.isEmpty || !mounted) return;
    final selection = _editor.selection;
    final start = selection.isValid ? selection.start : 0;
    final end = selection.isValid ? selection.end : 0;
    _editor.replaceText(
      start,
      end - start,
      text,
      TextSelection.collapsed(offset: start + text.length),
    );
  }

  Future<bool> _pasteImage({bool silentWhenEmpty = false}) async {
    if (_addingImage) return true;
    try {
      final bytes =
          await (widget.clipboardImageReader?.call() ?? Pasteboard.image);
      if (bytes == null) {
        if (!silentWhenEmpty && mounted) _message('No image on the clipboard.');
        return false;
      }
      final normalized = await prepareClipboardImage(bytes);
      final note = widget.controller.noteById(widget.noteId);
      if (!mounted || note == null) return false;
      await _addImage(normalized);
      return true;
    } catch (error) {
      if (mounted && !silentWhenEmpty) {
        _message('Could not paste image: $error');
      }
      return false;
    }
  }

  Future<void> _addImage(Uint8List bytes) async {
    if (!mounted || _closing || _addingImage) return;
    setState(() => _addingImage = true);
    final finished = Completer<void>();
    _imageOperation = finished.future;
    try {
      await _persist();
      final note = widget.controller.noteById(widget.noteId);
      if (!mounted || _closing || note == null) return;
      if (!widget.controller.inlineImages) {
        await widget.controller.addImage(note, bytes);
        return;
      }
      final id = await widget.controller.cacheImage(bytes);
      if (!mounted || _closing) return;
      _inlineIds.add(id);
      final selection = _editor.selection;
      final start = selection.start.clamp(0, _editor.document.length - 1);
      final end = selection.end.clamp(start, _editor.document.length - 1);
      final text = _editor.document.toPlainText();
      final leadingBreak = start > 0 && text[start - 1] != '\n';
      // One Delta keeps the paragraph split and image in one undo operation.
      final insertion = _editor.document.toDelta().slice(0, 0);
      if (leadingBreak) insertion.insert('\n');
      insertion
        ..insert(quill.BlockEmbed.image(id).toJson())
        ..insert('\n');
      _editor.replaceText(
        start,
        end - start,
        insertion,
        TextSelection.collapsed(offset: start + (leadingBreak ? 1 : 0) + 2),
      );
      _editorFocus.requestFocus();
      await _persist();
    } finally {
      finished.complete();
      _imageOperation = null;
      if (mounted) {
        setState(() => _addingImage = false);
      } else {
        _addingImage = false;
      }
    }
  }

  void _removeInlineImage(int offset) {
    _editor.replaceText(offset, 1, '', TextSelection.collapsed(offset: offset));
    _editorFocus.requestFocus();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _changeColor(Note note) async {
    _setHeaderBusy(true);
    try {
      final index = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Note color',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < noteColors.length; i++)
                      IconButton.filledTonal(
                        tooltip: noteColorNames[i],
                        style: IconButton.styleFrom(
                          backgroundColor: Color(noteColors[i]),
                          foregroundColor: const Color(0xFF2E2631),
                        ),
                        onPressed: () => Navigator.pop(context, i),
                        icon: Icon(
                          i == note.colorIndex ? Icons.check : Icons.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (index != null) {
        final current = widget.controller.noteById(note.id);
        if (current != null) {
          await widget.controller.save(current.copyWith(colorIndex: index));
        }
      }
    } finally {
      if (mounted) _setHeaderBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final note = widget.controller.noteById(widget.noteId);
      if (note == null) return const SizedBox.shrink();
      final noteColor = Color(noteColors[note.colorIndex % noteColors.length]);
      final saveStatus = _saveError != null
          ? 'Save failed'
          : _saving != null || _observedDocument != _savedDocument
          ? 'Saving…'
          : 'Saved locally';
      return PopScope(
        canPop: _closing,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_close());
        },
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyW, control: true):
                _close,
            const SingleActivator(LogicalKeyboardKey.keyD, control: true): () =>
                _delete(note),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              appBar: _desktopNote
                  ? NoteDesktopHeader(
                      note: note,
                      visible: _headerVisible || _keepHeaderVisible,
                      alwaysOnTop: _alwaysOnTop,
                      menuItems: [
                        ..._organizationItems(note),
                        const PopupMenuItem(
                          value: 'minimize',
                          child: Text('Minimize'),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Text('Share text'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete note'),
                        ),
                      ],
                      onHover: (hovered) {
                        _headerHovered = hovered;
                        hovered ? _showHeader() : _hideHeaderLater();
                      },
                      onFocusChange: (focused) {
                        _headerFocused = focused;
                        focused ? _showHeader() : _hideHeaderLater();
                      },
                      onNewNote: widget.onNewNote == null
                          ? null
                          : () => unawaited(widget.onNewNote!()),
                      onChangeColor: () => _changeColor(note),
                      onToggleAlwaysOnTop: _toggleAlwaysOnTop,
                      onMenuOpened: () => _setHeaderBusy(true),
                      onMenuCanceled: () => _setHeaderBusy(false),
                      onMenuSelected: (value) =>
                          unawaited(_headerMenuAction(value, note)),
                      onClose: _close,
                    )
                  : AppBar(
                      leading: IconButton(
                        tooltip: 'Close note',
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _close,
                      ),
                      title: Text(
                        note.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      actions: [
                        IconButton(
                          tooltip: 'Change color',
                          icon: const Icon(Icons.palette_outlined),
                          onPressed: () => _changeColor(note),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'More actions',
                          onSelected: (value) async {
                            if (value == 'share') {
                              await SharePlus.instance.share(
                                ShareParams(text: note.textForExport),
                              );
                            } else if (value == 'delete') {
                              await _delete(note);
                            } else {
                              await _organizationAction(value, note);
                            }
                          },
                          itemBuilder: (_) => [
                            ..._organizationItems(note),
                            const PopupMenuItem(
                              value: 'share',
                              child: Text('Share text'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete note'),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                      ],
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(5),
                        child: Container(height: 5, color: noteColor),
                      ),
                    ),
              body: Listener(
                onPointerDown: (event) {
                  if (event.kind == PointerDeviceKind.touch && !_touchHeader) {
                    setState(() => _touchHeader = true);
                    _showHeader();
                  }
                },
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 790),
                      child: Column(
                        children: [
                          if (_finding)
                            FindBar(
                              textController: _findText,
                              focusNode: _findFocus,
                              matches: _matches.length,
                              index: _matchIndex,
                              onQueryChanged: () =>
                                  _updateMatches(select: true),
                              onStep: _nextMatch,
                              onClose: _dismissFind,
                            ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                for (final imageId in note.images.where(
                                  (id) => !_inlineIds.contains(id),
                                ))
                                  NoteImageCard(
                                    controller: widget.controller,
                                    noteId: note.id,
                                    imageId: imageId,
                                    onRemove: () =>
                                        widget.controller.removeImage(
                                          widget.controller.noteById(note.id)!,
                                          imageId,
                                        ),
                                  ),
                                if (note.strokes.isNotEmpty)
                                  InkPreview(
                                    strokes: note.strokes,
                                    onTap: () => _editInk(note),
                                  ),
                                Listener(
                                  onPointerDown: (event) => _secondaryPointer =
                                      event.kind == PointerDeviceKind.mouse &&
                                      event.buttons == kSecondaryMouseButton,
                                  onPointerUp: (event) {
                                    if (!_secondaryPointer ||
                                        !_desktopEditorMenu) {
                                      return;
                                    }
                                    _secondaryPointer = false;
                                    // Let Quill finish selecting the clicked word.
                                    final position = event.position;
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted) {
                                            unawaited(
                                              _showEditorMenu(position),
                                            );
                                          }
                                        });
                                    WidgetsBinding.instance.scheduleFrame();
                                  },
                                  child: SizedBox(
                                    height: 420,
                                    child: quill.QuillEditor.basic(
                                      key: _quillKey,
                                      controller: _editor,
                                      focusNode: _editorFocus,
                                      config: quill.QuillEditorConfig(
                                        // Windows/desktop uses _showEditorMenu: its
                                        // popup route is reliable in note windows,
                                        // where the overlay menu ignored clicks.
                                        contextMenuBuilder: (context, state) =>
                                            _desktopEditorMenu
                                            ? const SizedBox.shrink()
                                            : AdaptiveTextSelectionToolbar.buttonItems(
                                                anchors:
                                                    state.contextMenuAnchors,
                                                buttonItems: [
                                                  ...state
                                                      .contextMenuButtonItems,
                                                  if (!_editor
                                                      .selection
                                                      .isCollapsed)
                                                    ContextMenuButtonItem(
                                                      label: 'Change color',
                                                      onPressed: () {
                                                        state.hideToolbar();
                                                        _chooseTextColor(
                                                          quill.Attribute.color,
                                                        );
                                                      },
                                                    ),
                                                ],
                                              ),
                                        embedBuilders: [
                                          NoteImageEmbedBuilder(
                                            store: widget.controller,
                                            noteId: note.id,
                                            onRemove: _removeInlineImage,
                                          ),
                                        ],
                                        placeholder: 'Write a note...',
                                        padding: const EdgeInsets.all(4),
                                        // Resolve Windows Backspace in the editor's
                                        // own Actions scope, including held-key repeats.
                                        customShortcuts:
                                            !kIsWeb &&
                                                defaultTargetPlatform ==
                                                    TargetPlatform.windows
                                            ? const {
                                                SingleActivator(
                                                  LogicalKeyboardKey.backspace,
                                                ): DeleteCharacterIntent(
                                                  forward: false,
                                                ),
                                                SingleActivator(
                                                  LogicalKeyboardKey.backspace,
                                                  shift: true,
                                                ): DeleteCharacterIntent(
                                                  forward: false,
                                                ),
                                                SingleActivator(
                                                  LogicalKeyboardKey.backspace,
                                                  control: true,
                                                ): DeleteToNextWordBoundaryIntent(
                                                  forward: false,
                                                ),
                                              }
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainer,
                            child: Column(
                              children: [
                                if (_saveError != null)
                                  Semantics(
                                    liveRegion: true,
                                    child: ListTile(
                                      dense: true,
                                      title: const Text(
                                        'Save failed. Keep editing or retry.',
                                      ),
                                      trailing: TextButton(
                                        onPressed: _autoSave,
                                        child: const Text('Retry'),
                                      ),
                                    ),
                                  ),
                                quill.QuillSimpleToolbar(
                                  controller: _editor,
                                  config: const quill.QuillSimpleToolbarConfig(
                                    showFontFamily: false,
                                    showFontSize: false,
                                    showSmallButton: false,
                                    showLineHeightButton: false,
                                    showInlineCode: false,
                                    showColorButton: false,
                                    showBackgroundColorButton: false,
                                    showClearFormat: false,
                                    showAlignmentButtons: false,
                                    showHeaderStyle: false,
                                    showListNumbers: false,
                                    showListCheck: true,
                                    showCodeBlock: false,
                                    showQuote: false,
                                    showIndent: false,
                                    showLink: false,
                                    showDirection: false,
                                    showSearchButton: false,
                                    showSubscript: false,
                                    showSuperscript: false,
                                    showDividers: false,
                                    multiRowsDisplay: true,
                                  ),
                                ),
                                if (_showTextStyle)
                                  TextStylePanel(
                                    editor: _editor,
                                    onChooseColor: _chooseTextColor,
                                  ),
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Text style options',
                                      isSelected: _showTextStyle,
                                      icon: const Icon(Icons.text_format),
                                      onPressed: () => setState(() {
                                        _showTextStyle = !_showTextStyle;
                                      }),
                                    ),
                                    IconButton(
                                      tooltip: 'Add image',
                                      icon: const Icon(
                                        Icons.add_photo_alternate_outlined,
                                      ),
                                      onPressed: () =>
                                          _pickImage(ImageSource.gallery),
                                    ),
                                    IconButton(
                                      tooltip: 'Paste image from clipboard',
                                      icon: const Icon(
                                        Icons.content_paste_outlined,
                                      ),
                                      onPressed: _pasteImage,
                                    ),
                                    if (!kIsWeb &&
                                        (defaultTargetPlatform ==
                                                TargetPlatform.android ||
                                            defaultTargetPlatform ==
                                                TargetPlatform.iOS))
                                      IconButton(
                                        tooltip: 'Take photo',
                                        icon: const Icon(
                                          Icons.camera_alt_outlined,
                                        ),
                                        onPressed: () =>
                                            _pickImage(ImageSource.camera),
                                      ),
                                    IconButton(
                                      tooltip: 'Draw',
                                      icon: const Icon(Icons.draw_outlined),
                                      onPressed: () => _editInk(note),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 16,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: _addingImage || _saving != null
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        semanticsLabel:
                                                            'Saving locally',
                                                      ),
                                                )
                                              : Semantics(
                                                  child: Tooltip(
                                                    message: saveStatus,
                                                    child: Text(
                                                      saveStatus,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Future<void> _showEditorMenu(Offset position) async {
    final selection = _editor.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'cut',
          enabled: hasSelection,
          child: const Text('Cut'),
        ),
        PopupMenuItem(
          value: 'copy',
          enabled: hasSelection,
          child: const Text('Copy'),
        ),
        const PopupMenuItem(value: 'paste', child: Text('Paste')),
        const PopupMenuItem(value: 'all', child: Text('Select all')),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'color',
          enabled: hasSelection,
          child: const Text('Change color'),
        ),
        PopupMenuItem(
          value: 'highlight',
          enabled: hasSelection,
          child: const Text('Highlight color'),
        ),
      ],
    );
    if (choice == null || !mounted) return;
    try {
      if (_editor.selection != selection && selection.isValid) {
        _editor.updateSelection(selection, quill.ChangeSource.local);
      }
      switch (choice) {
        case 'cut':
          // ignore: experimental_member_use
          _editor.clipboardSelection(false);
        case 'copy':
          // ignore: experimental_member_use
          _editor.clipboardSelection(true);
        case 'paste':
          // ignore: experimental_member_use
          await _editor.clipboardPaste();
        case 'all':
          _editor.updateSelection(
            TextSelection(
              baseOffset: 0,
              extentOffset: _editor.document.length - 1,
            ),
            quill.ChangeSource.local,
          );
        case 'color':
          await _chooseTextColor(quill.Attribute.color, selection);
        case 'highlight':
          await _chooseTextColor(quill.Attribute.background, selection);
      }
    } catch (error) {
      if (mounted) _message('Could not complete that action: $error');
    }
    if (mounted) _editorFocus.requestFocus();
  }

  Future<void> _chooseTextColor(
    quill.Attribute attribute, [
    TextSelection? knownSelection,
  ]) async {
    try {
      await _pickTextColor(attribute, knownSelection);
    } catch (error) {
      if (mounted) _message('Could not change text color: $error');
    }
  }

  Future<void> _pickTextColor(
    quill.Attribute attribute,
    TextSelection? knownSelection,
  ) async {
    final selection = knownSelection ?? _editor.selection;
    if (!_editor.selection.isValid || _editor.selection != selection) {
      _editor.updateSelection(selection, quill.ChangeSource.local);
    }
    final color = await showTextColorDialog(
      context,
      title: attribute.key == quill.Attribute.color.key
          ? 'Text color'
          : 'Highlight color',
      initialColor:
          _editor.getSelectionStyle().attributes[attribute.key]?.value
              as String?,
    );
    if (!mounted || color == null) return;
    // Updating an unchanged caret resets Quill's pending typing styles.
    if (_editor.selection != selection) {
      _editor.updateSelection(selection, quill.ChangeSource.local);
    }
    _editor.formatSelection(
      quill.Attribute.clone(attribute, color.isEmpty ? null : color),
    );
    _editorFocus.requestFocus();
  }

  Future<void> _editInk(Note note) async {
    final strokes = await Navigator.of(context).push<List<InkStroke>>(
      MaterialPageRoute(builder: (_) => DrawingPage(initial: note.strokes)),
    );
    if (strokes != null) {
      final current = widget.controller.noteById(note.id);
      if (current != null) {
        await widget.controller.save(current.copyWith(strokes: strokes));
      }
    }
  }
}

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
import '../data/note.dart';
import '../state/note_editor_store.dart';
import 'drawing_page.dart';
import 'notes_home.dart';
import 'shortcuts_help.dart';
import 'text_color_dialog.dart';

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
          onClipboardPaste: () => _pasteImage(silentWhenEmpty: true),
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

  Widget _findBar() => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  shift: true,
                ): () =>
                    _nextMatch(-1),
              },
              child: TextField(
                key: const ValueKey('find-in-note'),
                controller: _findText,
                focusNode: _findFocus,
                decoration: const InputDecoration(
                  hintText: 'Find in this note (Ctrl+H)',
                  border: InputBorder.none,
                ),
                onChanged: (_) => _updateMatches(select: true),
                onSubmitted: (_) {
                  _nextMatch(1);
                  _findFocus.requestFocus();
                },
              ),
            ),
          ),
          Text(
            _matches.isEmpty ? '0/0' : '${_matchIndex + 1}/${_matches.length}',
            semanticsLabel: '${_matches.length} matches',
          ),
          IconButton(
            tooltip: 'Previous match',
            onPressed: _matches.isEmpty ? null : () => _nextMatch(-1),
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            tooltip: 'Next match',
            onPressed: _matches.isEmpty ? null : () => _nextMatch(1),
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
          IconButton(
            tooltip: 'Close find',
            onPressed: _dismissFind,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );

  Future<void> _editDetails(Note note) async {
    final title = TextEditingController(text: note.title);
    final tags = TextEditingController(text: note.tags.join(', '));
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Title and tags'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey('note-title'),
                  controller: title,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Title (optional)',
                    hintText: 'Uses the first text line when blank',
                  ),
                ),
                TextField(
                  key: const ValueKey('note-tags'),
                  controller: tags,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    hintText: 'work, ideas, personal',
                  ),
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
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
      await _flush();
      final current = widget.controller.noteById(note.id);
      if (current != null) {
        await widget.controller.save(
          current.copyWith(title: title.text, tags: tags.text.split(',')),
        );
      }
    } catch (error) {
      if (mounted) _message('Could not save details: $error');
    } finally {
      // Let the dialog finish its closing animation before disposing fields.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      title.dispose();
      tags.dispose();
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
    const PopupMenuItem(value: 'details', child: Text('Title and tags')),
    PopupMenuItem(
      value: 'favorite',
      child: Text(note.favorite ? 'Remove favorite' : 'Favorite'),
    ),
    const PopupMenuItem(value: 'archive', child: Text('Archive note')),
    const PopupMenuItem(value: 'find', child: Text('Find in note (Ctrl+H)')),
    const PopupMenuItem(value: 'help', child: Text('Keyboard shortcuts (F1)')),
    const PopupMenuDivider(),
  ];

  PreferredSizeWidget _desktopHeader(Note note) => PreferredSize(
    preferredSize: const Size.fromHeight(48),
    child: MouseRegion(
      key: const ValueKey('note-header-hover'),
      onEnter: (_) {
        _headerHovered = true;
        _showHeader();
      },
      onExit: (_) {
        _headerHovered = false;
        _hideHeaderLater();
      },
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (focused) {
          _headerFocused = focused;
          if (focused) {
            _showHeader();
          } else {
            _hideHeaderLater();
          }
        },
        child: AnimatedOpacity(
          key: const ValueKey('note-header-opacity'),
          opacity: _headerVisible || _keepHeaderVisible ? 1 : 0,
          alwaysIncludeSemantics: true,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !_headerVisible && !_keepHeaderVisible,
            child: Material(
              color: Color(noteColors[note.colorIndex % noteColors.length]),
              child: IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF2E2631),
                  ),
                ),
                child: IconTheme(
                  data: const IconThemeData(color: Color(0xFF2E2631)),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (widget.onNewNote != null)
                          IconButton(
                            tooltip: 'New note',
                            onPressed: widget.onNewNote,
                            icon: const Icon(Icons.add),
                          ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (_) =>
                                unawaited(windowManager.startDragging()),
                            onDoubleTap: () async {
                              if (await windowManager.isMaximized()) {
                                await windowManager.unmaximize();
                              } else {
                                await windowManager.maximize();
                              }
                            },
                            child: Semantics(
                              label: note.displayTitle,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Change color',
                          onPressed: () => _changeColor(note),
                          icon: const Icon(Icons.palette_outlined),
                        ),
                        IconButton(
                          tooltip: _alwaysOnTop
                              ? 'Turn off always on top'
                              : 'Always on top',
                          isSelected: _alwaysOnTop,
                          onPressed: _toggleAlwaysOnTop,
                          icon: const Icon(Icons.push_pin_outlined),
                          selectedIcon: const Icon(Icons.push_pin),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'More actions',
                          onOpened: () => _setHeaderBusy(true),
                          onCanceled: () => _setHeaderBusy(false),
                          onSelected: (value) async {
                            try {
                              if (value == 'share') {
                                await SharePlus.instance.share(
                                  ShareParams(text: note.textForExport),
                                );
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
                          },
                          itemBuilder: (_) => [
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
                        ),
                        IconButton(
                          tooltip: 'Close note',
                          onPressed: _close,
                          icon: const Icon(Icons.close),
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
    ),
  );

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
      final bytes = await image.readAsBytes();
      if (bytes.length > maxNoteImageBytes) {
        if (mounted) _message('Choose an image under 8 MB.');
        return;
      }
      await _addImage(bytes);
    } catch (error) {
      if (mounted) _message('Could not add image: $error');
    }
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
                  ? _desktopHeader(note)
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
                          if (_finding) _findBar(),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                for (final imageId in note.images.where(
                                  (id) => !_inlineIds.contains(id),
                                ))
                                  _NoteImageCard(
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
                                SizedBox(
                                  height: 420,
                                  child: quill.QuillEditor.basic(
                                    key: _quillKey,
                                    controller: _editor,
                                    focusNode: _editorFocus,
                                    config: quill.QuillEditorConfig(
                                      contextMenuBuilder: (context, state) =>
                                          AdaptiveTextSelectionToolbar.buttonItems(
                                            anchors: state.contextMenuAnchors,
                                            buttonItems: [
                                              ...state.contextMenuButtonItems,
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
                                        _NoteImageEmbedBuilder(
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
                                if (_showTextStyle) _textStyleToolbar(),
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

  Widget _textStyleToolbar() => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .25,
    ),
    child: SingleChildScrollView(
      key: const ValueKey('text-style-panel'),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select text to style it, or choose a style before typing.',
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              quill.QuillToolbarFontSizeButton(
                controller: _editor,
                options: const quill.QuillToolbarFontSizeButtonOptions(
                  items: {
                    'Default': '0',
                    '12': '12',
                    '14': '14',
                    '16': '16',
                    '18': '18',
                    '24': '24',
                    '32': '32',
                    '48': '48',
                  },
                  defaultItemColor: null,
                ),
              ),
              IconButton(
                tooltip: 'Text color',
                icon: const Icon(Icons.format_color_text),
                onPressed: () => _chooseTextColor(quill.Attribute.color),
              ),
              IconButton(
                tooltip: 'Highlight color',
                icon: const Icon(Icons.format_color_fill),
                onPressed: () => _chooseTextColor(quill.Attribute.background),
              ),
              quill.QuillToolbarSelectHeaderStyleDropdownButton(
                controller: _editor,
              ),
              quill.QuillToolbarToggleStyleButton(
                controller: _editor,
                attribute: quill.Attribute.ol,
              ),
              quill.QuillToolbarToggleStyleButton(
                controller: _editor,
                attribute: quill.Attribute.blockQuote,
              ),
              quill.QuillToolbarToggleStyleButton(
                controller: _editor,
                attribute: quill.Attribute.inlineCode,
              ),
              quill.QuillToolbarClearFormatButton(controller: _editor),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _chooseTextColor(quill.Attribute attribute) async {
    final selection = _editor.selection;
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

class _NoteImageEmbedBuilder extends quill.EmbedBuilder {
  const _NoteImageEmbedBuilder({
    required this.store,
    required this.noteId,
    required this.onRemove,
  });

  final NoteEditorStore store;
  final String noteId;
  final void Function(int) onRemove;

  @override
  String get key => quill.BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) =>
      _NoteImageCard(
        controller: store,
        noteId: noteId,
        imageId: embedContext.node.value.data as String,
        inline: true,
        onRemove: () => onRemove(embedContext.node.documentOffset),
      );
}

class _NoteImageCard extends StatelessWidget {
  const _NoteImageCard({
    required this.controller,
    required this.noteId,
    required this.imageId,
    required this.onRemove,
    this.inline = false,
  });

  final NoteEditorStore controller;
  final String noteId;
  final String imageId;
  final VoidCallback onRemove;
  final bool inline;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey('${inline ? 'inline' : 'above'}-image-$imageId'),
    padding: const EdgeInsets.only(bottom: 12),
    child: Stack(
      children: [
        InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.9,
                height: MediaQuery.sizeOf(context).height * 0.75,
                child: NoteImage(
                  controller: controller,
                  noteId: noteId,
                  imageId: imageId,
                ),
              ),
            ),
          ),
          child: inline
              ? ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 64,
                    maxHeight: 300,
                  ),
                  child: NoteImage(
                    controller: controller,
                    noteId: noteId,
                    imageId: imageId,
                  ),
                )
              : SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: NoteImage(
                    controller: controller,
                    noteId: noteId,
                    imageId: imageId,
                  ),
                ),
        ),
        Positioned(
          right: 5,
          top: 5,
          child: IconButton.filledTonal(
            tooltip: 'Remove image',
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ),
      ],
    ),
  );
}

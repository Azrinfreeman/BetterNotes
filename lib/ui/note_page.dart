import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

class _NotePageState extends State<NotePage> {
  late final quill.QuillController _editor;
  final FocusNode _editorFocus = FocusNode();
  final Set<String> _inlineIds = {};
  bool _addingImage = false;
  Timer? _saveTimer;
  bool _closing = false;
  bool _closeInProgress = false;
  Timer? _headerTimer;
  bool _headerHovered = false;
  bool _headerFocused = false;
  bool _headerBusy = false;
  bool _headerVisible = true;
  bool _alwaysOnTop = false;

  bool get _desktopNote =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.windows &&
      widget.onClose != null;

  @override
  void initState() {
    super.initState();
    final note = widget.controller.noteById(widget.noteId)!;
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
      if (mounted && !_headerHovered && !_headerFocused && !_headerBusy) {
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
          opacity: _headerVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !_headerVisible,
            child: Material(
              color: Color(noteColors[note.colorIndex % noteColors.length]),
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
                          child: const SizedBox.expand(),
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
                                ShareParams(text: note.plainText),
                              );
                            } else if (value == 'delete') {
                              await _delete(note);
                            } else if (value == 'minimize') {
                              await windowManager.minimize();
                            }
                          } finally {
                            if (mounted) _setHeaderBusy(false);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'minimize',
                            child: Text('Minimize'),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: Text('Share text'),
                          ),
                          PopupMenuItem(
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
  );

  void _onExternalClose() => unawaited(_close());

  bool _handleAppKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        !mounted ||
        !(ModalRoute.of(context)?.isCurrent ?? false) ||
        !(HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      return false;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyV:
        // The focused editor awaits image paste before falling back to text.
        if (!_editorFocus.hasFocus) {
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
          unawaited(widget.onFindNotes!());
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
    _inlineIds.addAll(inlineImageIds(_editor.document.toDelta().toJson()));
    if (mounted) setState(() {});
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), _persist);
  }

  Future<void> _persist() async {
    final note = widget.controller.noteById(widget.noteId);
    if (note == null || _closing) return;
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
      return;
    }
    await widget.controller.save(
      note.copyWith(delta: delta, plainText: plainText, images: images),
    );
  }

  @override
  void dispose() {
    _headerTimer?.cancel();
    _saveTimer?.cancel();
    widget.closeRequests?.removeListener(_onExternalClose);
    HardwareKeyboard.instance.removeHandler(_handleAppKey);
    unawaited(_persist());
    _editor.removeListener(_scheduleSave);
    _editor.dispose();
    _editorFocus.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closeInProgress) return;
    _closeInProgress = true;
    _saveTimer?.cancel();
    await _persist();
    _closing = true;
    if (widget.onClose != null) {
      await widget.onClose!();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete(Note note) async {
    if (widget.controller.confirmDelete) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete this note?'),
          content: const Text('This note will be removed from your devices.'),
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
    _closing = true;
    await widget.controller.delete(note);
    if (widget.onClose != null) {
      await widget.onClose!();
    } else if (mounted) {
      Navigator.of(context).pop();
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
    _addingImage = true;
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
      _addingImage = false;
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
      final saveStatus = widget.controller.syncing
          ? 'Syncing…'
          : widget.controller.signedIn
          ? 'Saved'
          : 'Saved here';
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyW, control: true): _close,
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
                    title: Text(noteTime(note.updatedAt)),
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
                              ShareParams(text: note.plainText),
                            );
                          } else if (value == 'delete') {
                            await _delete(note);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'share',
                            child: Text('Share text'),
                          ),
                          PopupMenuItem(
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
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 790),
                  child: Column(
                    children: [
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
                                onRemove: () => widget.controller.removeImage(
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
                                controller: _editor,
                                focusNode: _editorFocus,
                                config: quill.QuillEditorConfig(
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
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: Column(
                          children: [
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
                                showListCheck: false,
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
                            Row(
                              children: [
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
                                    icon: const Icon(Icons.camera_alt_outlined),
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
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Tooltip(
                                        message: saveStatus,
                                        child: Text(
                                          saveStatus,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
      );
    },
  );

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

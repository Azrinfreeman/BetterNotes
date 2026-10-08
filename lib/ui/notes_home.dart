import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/note.dart';
import '../desktop/window_chrome.dart';
import '../state/note_editor_store.dart';
import '../state/notes_controller.dart';
import 'note_page.dart';
import 'settings_page.dart';

class NotesHome extends StatefulWidget {
  const NotesHome({
    super.key,
    required this.controller,
    this.openNoteWindow,
    this.searchRequests,
  });
  final NotesController controller;
  final Future<void> Function(String)? openNoteWindow;
  final ValueListenable<int>? searchRequests;

  @override
  State<NotesHome> createState() => _NotesHomeState();
}

class _NotesHomeState extends State<NotesHome> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.searchRequests?.addListener(_focusSearch);
  }

  void _focusSearch() => _searchFocus.requestFocus();

  @override
  void dispose() {
    widget.searchRequests?.removeListener(_focusSearch);
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _newNote() async {
    final note = await widget.controller.create();
    if (!mounted) return;
    await _openNote(note.id);
  }

  Future<void> _openNote(String noteId) async {
    if (widget.openNoteWindow != null) {
      await widget.openNoteWindow!(noteId);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotePage(
          controller: widget.controller,
          noteId: noteId,
          onNewNote: _newNote,
          onFindNotes: _findNotes,
        ),
      ),
    );
  }

  Future<void> _findNotes() async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): _newNote,
      const SingleActivator(LogicalKeyboardKey.keyF, control: true):
          _searchFocus.requestFocus,
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        appBar: AppBar(
          title: const WindowTitle(
            child: Text(
              'BetterNotes',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          actions: [
            AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) => IconButton(
                tooltip: widget.controller.syncError == null
                    ? widget.controller.signedIn
                          ? 'Sync notes'
                          : 'Local notes'
                    : 'Sync needs attention',
                icon: Icon(
                  widget.controller.syncError != null
                      ? Icons.cloud_off_outlined
                      : widget.controller.syncing
                      ? Icons.sync
                      : widget.controller.signedIn
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_outlined,
                ),
                onPressed: widget.controller.signedIn
                    ? widget.controller.sync
                    : () => _openSettings(),
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
            ),
            const WindowButtons(),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _newNote,
          icon: const Icon(Icons.add),
          label: const Text('New note'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    Text(
                      'Your notes',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _search,
                      focusNode: _searchFocus,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search your notes',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: widget.controller,
                        builder: (context, _) {
                          final query = _search.text.trim().toLowerCase();
                          final notes = widget.controller.notes
                              .where(
                                (note) => note.plainText.toLowerCase().contains(
                                  query,
                                ),
                              )
                              .toList();
                          if (notes.isEmpty) {
                            return _EmptyState(
                              searching: query.isNotEmpty,
                              onCreate: _newNote,
                            );
                          }
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth > 760
                                  ? 3
                                  : constraints.maxWidth > 500
                                  ? 2
                                  : 1;
                              return GridView.builder(
                                padding: const EdgeInsets.only(bottom: 100),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 14,
                                      mainAxisExtent: 218,
                                    ),
                                itemCount: notes.length,
                                itemBuilder: (context, index) => NoteCard(
                                  note: notes[index],
                                  controller: widget.controller,
                                  onOpen: () => _openNote(notes[index].id),
                                ),
                              );
                            },
                          );
                        },
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
  );

  void _openSettings() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsPage(controller: widget.controller),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching, required this.onCreate});
  final bool searching;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          searching ? Icons.search_off : Icons.sticky_note_2_outlined,
          size: 60,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 18),
        Text(
          searching ? 'No matching notes' : 'A fresh space for your ideas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          searching
              ? 'Try another word or clear the search.'
              : 'Keep a thought close. Start with a note.',
        ),
        if (!searching) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create a note'),
          ),
        ],
      ],
    ),
  );
}

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.controller,
    this.onOpen,
  });
  final Note note;
  final NotesController controller;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final color = Color(noteColors[note.colorIndex % noteColors.length]);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final preview = note.plainText.isNotEmpty
        ? note.plainText
        : note.images.isNotEmpty
        ? 'Image note'
        : note.strokes.isNotEmpty
        ? 'Ink note'
        : 'Empty note';
    return Semantics(
      container: true,
      label:
          '$preview. Updated ${noteTime(note.updatedAt)}. '
          '${noteColorNames[note.colorIndex % noteColorNames.length]} note.',
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: dark ? Theme.of(context).colorScheme.surfaceContainerHigh : null,
        child: InkWell(
          onTap:
              onOpen ??
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      NotePage(controller: controller, noteId: note.id),
                ),
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 7, color: color),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        noteTime(note.updatedAt),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    PopupMenuButton<int>(
                      tooltip: 'Note options',
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (value) async {
                        if (value >= 0) {
                          await controller.save(
                            note.copyWith(colorIndex: value),
                          );
                          return;
                        }
                        if (controller.confirmDelete) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete this note?'),
                              content: const Text(
                                'This note will be removed from your devices.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                        }
                        await controller.delete(note);
                      },
                      itemBuilder: (_) => [
                        for (var i = 0; i < noteColors.length; i++)
                          PopupMenuItem<int>(
                            value: i,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Color(noteColors[i]),
                                ),
                                const SizedBox(width: 10),
                                Text(noteColorNames[i]),
                              ],
                            ),
                          ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<int>(
                          value: -1,
                          child: Text('Delete note'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (note.images.isNotEmpty)
                SizedBox(
                  height: 72,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: NoteImage(
                      controller: controller,
                      noteId: note.id,
                      imageId: note.images.first,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                  child: Text(
                    note.plainText.isEmpty
                        ? note.images.isNotEmpty
                              ? 'Image note'
                              : note.strokes.isNotEmpty
                              ? 'Ink note'
                              : 'Empty note'
                        : note.plainText,
                    maxLines: note.images.isEmpty ? 6 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                      color: note.plainText.isEmpty
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String noteTime(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'AM' : 'PM'}';
  }
  return '${local.day} ${_months[local.month - 1]}';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class NoteImage extends StatefulWidget {
  const NoteImage({
    super.key,
    required this.controller,
    required this.noteId,
    required this.imageId,
    this.fit = BoxFit.contain,
  });

  final NoteEditorStore controller;
  final String noteId;
  final String imageId;
  final BoxFit fit;

  @override
  State<NoteImage> createState() => _NoteImageState();
}

class _NoteImageState extends State<NoteImage> {
  late Future<Uint8List?> _image;

  @override
  void initState() {
    super.initState();
    _image = widget.controller.image(widget.noteId, widget.imageId);
  }

  @override
  void didUpdateWidget(NoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId ||
        oldWidget.imageId != widget.imageId) {
      _image = widget.controller.image(widget.noteId, widget.imageId);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _image,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: Icon(Icons.image_outlined));
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          snapshot.data!,
          fit: widget.fit,
          width: double.infinity,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
        ),
      );
    },
  );
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/note.dart';
import '../desktop/window_chrome.dart';
import '../state/note_editor_store.dart';
import '../state/notes_controller.dart';
import 'note_page.dart';
import 'settings_page.dart';
import 'shortcuts_help.dart';

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
  final _libraryScroll = ScrollController();
  bool _creating = false;
  final Set<String> _openingNotes = {};
  late int _lastDeletion;

  @override
  void initState() {
    super.initState();
    _lastDeletion = widget.controller.deletionSerial;
    widget.controller.addListener(_deletedNote);
    widget.searchRequests?.addListener(_focusSearch);
  }

  void _focusSearch() => _searchFocus.requestFocus();

  Future<void> _options({
    LibraryView? view,
    NoteSort? sort,
    List<String>? tags,
    bool reset = false,
  }) async {
    try {
      await widget.controller.setLibraryOptions(
        view: view,
        sort: sort,
        tags: tags,
        reset: reset,
      );
      if (mounted) {
        setState(() {});
        if (reset) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _libraryScroll.hasClients) _libraryScroll.jumpTo(0);
          });
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save filters: $error')),
        );
      }
    }
  }

  Future<void> _chooseTags() async {
    final selected = widget.controller.selectedTags.toSet();
    final available = {...widget.controller.availableTags, ...selected};
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Match all selected tags',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final tag in available)
                            FilterChip(
                              label: Text(tag),
                              selected: selected.contains(tag),
                              onSelected: (checked) => refresh(() {
                                if (checked) {
                                  selected.add(tag);
                                } else {
                                  selected.remove(tag);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => refresh(selected.clear),
                        child: const Text('Clear tags'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, selected.toList()),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result != null) await _options(tags: result);
  }

  void _deletedNote() {
    final controller = widget.controller;
    if (_lastDeletion == controller.deletionSerial) return;
    _lastDeletion = controller.deletionSerial;
    final id = controller.recentlyDeletedId;
    if (id == null || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Moved to Trash'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await controller.restore(id);
            } catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not restore: $error')),
                );
              }
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.searchRequests?.removeListener(_focusSearch);
    widget.controller.removeListener(_deletedNote);
    _search.dispose();
    _searchFocus.dispose();
    _libraryScroll.dispose();
    super.dispose();
  }

  Future<void> _newNote() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final note = await widget.controller.create();
      if (!mounted) return;
      // A route stays pending until it closes; allow New note inside its editor.
      if (widget.openNoteWindow == null) setState(() => _creating = false);
      await _openNote(note.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create note: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _openNote(String noteId) async {
    if (!_openingNotes.add(noteId)) return;
    try {
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open note: $error')));
      }
    } finally {
      _openingNotes.remove(noteId);
    }
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
      const SingleActivator(LogicalKeyboardKey.f1): () =>
          showShortcutsHelp(context),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
          onPressed: _creating ? null : _newNote,
          icon: _creating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: const Text('New note'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: CustomScrollView(
                  controller: _libraryScroll,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          AnimatedBuilder(
                            animation: widget.controller,
                            builder: (context, _) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final entry in const {
                                        LibraryView.notes: 'Notes',
                                        LibraryView.favorites: 'Favorites',
                                        LibraryView.archive: 'Archive',
                                        LibraryView.trash: 'Trash',
                                        LibraryView.allActive: 'All active',
                                      }.entries)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: ChoiceChip(
                                            label: Text(entry.value),
                                            selected:
                                                widget.controller.libraryView ==
                                                entry.key,
                                            onSelected: (_) =>
                                                _options(view: entry.key),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                LayoutBuilder(
                                  builder: (context, constraints) => Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      SizedBox(
                                        width:
                                            constraints.maxWidth < 400 ||
                                                MediaQuery.textScalerOf(context)
                                                        .scale(14) >
                                                    20
                                            ? constraints.maxWidth
                                            : constraints.maxWidth - 148,
                                        child: DropdownButton<NoteSort>(
                                          value: widget.controller.noteSort,
                                          isExpanded: true,
                                          onChanged: (sort) =>
                                              _options(sort: sort),
                                          items: const [
                                            DropdownMenuItem(
                                              value: NoteSort.updated,
                                              child: Text(
                                                'Recently edited',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: NoteSort.created,
                                              child: Text(
                                                'Newest created',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: NoteSort.title,
                                              child: Text(
                                                'Title A–Z',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          _search.clear();
                                          _options(reset: true);
                                        },
                                        child: const Text('Reset filters'),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget
                                        .controller
                                        .availableTags
                                        .isNotEmpty ||
                                    widget.controller.selectedTags.isNotEmpty)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: _chooseTags,
                                      icon: const Icon(Icons.label_outline),
                                      label: Text(
                                        widget.controller.selectedTags.isEmpty
                                            ? 'Filter by tags'
                                            : 'Tags: ${widget.controller.selectedTags.join(', ')}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          AnimatedBuilder(
                            animation: widget.controller,
                            builder: (context, _) =>
                                widget.controller.saveFailure == null
                                ? const SizedBox.shrink()
                                : Semantics(
                                    liveRegion: true,
                                    child: ListTile(
                                      leading: const Icon(Icons.error_outline),
                                      title: Text(
                                        widget.controller.saveFailure!,
                                      ),
                                      trailing: TextButton(
                                        onPressed: () async {
                                          try {
                                            await widget.controller
                                                .flushAllEditors();
                                          } catch (error) {
                                            widget.controller.reportSaveFailure(
                                              'Save failed: $error',
                                            );
                                          }
                                        },
                                        child: const Text('Retry'),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _search,
                            focusNode: _searchFocus,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search titles and text in this view',
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
                          if (_search.text.isNotEmpty &&
                              widget.controller.libraryView !=
                                  LibraryView.allActive)
                            TextButton(
                              onPressed: () =>
                                  _options(view: LibraryView.allActive),
                              child: const Text(
                                'Search all active notes, including Archive',
                              ),
                            ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                    AnimatedBuilder(
                      animation: widget.controller,
                      builder: (context, _) {
                        final query = _search.text.trim().toLowerCase();
                        final notes = widget.controller.librarySearch(query);
                        final showTrash =
                            widget.controller.libraryView == LibraryView.trash;
                        if (notes.isEmpty) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(
                              searching: query.isNotEmpty,
                              onCreate: _newNote,
                              message: showTrash
                                  ? query.isEmpty
                                        ? 'Trash is empty'
                                        : 'No matching notes in Trash'
                                  : widget.controller.libraryView !=
                                            LibraryView.notes ||
                                        widget
                                            .controller
                                            .selectedTags
                                            .isNotEmpty
                                  ? 'No notes match this view and filters'
                                  : null,
                              onReset:
                                  query.isNotEmpty ||
                                      widget
                                          .controller
                                          .selectedTags
                                          .isNotEmpty ||
                                      widget.controller.libraryView !=
                                          LibraryView.notes
                                  ? () {
                                      _search.clear();
                                      _options(reset: true);
                                    }
                                  : null,
                            ),
                          );
                        }
                        return SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.crossAxisExtent > 760
                                ? 3
                                : constraints.crossAxisExtent > 500
                                ? 2
                                : 1;
                            return SliverPadding(
                              padding: const EdgeInsets.only(bottom: 100),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 14,
                                      mainAxisExtent:
                                          270 +
                                          (MediaQuery.textScalerOf(context)
                                                              .scale(14) /
                                                          14 -
                                                      1)
                                                  .clamp(0, 3) *
                                              140,
                                    ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => showTrash
                                      ? _TrashCard(
                                          note: notes[index],
                                          controller: widget.controller,
                                        )
                                      : notes[index].archivedAt != null
                                      ? _ArchiveCard(
                                          note: notes[index],
                                          controller: widget.controller,
                                        )
                                      : NoteCard(
                                          key: ValueKey(notes[index].id),
                                          note: notes[index],
                                          controller: widget.controller,
                                          onOpen: () =>
                                              _openNote(notes[index].id),
                                        ),
                                  childCount: notes.length,
                                ),
                              ),
                            );
                          },
                        );
                      },
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
  const _EmptyState({
    required this.searching,
    required this.onCreate,
    this.message,
    this.onReset,
  });
  final bool searching;
  final VoidCallback onCreate;
  final String? message;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 100),
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
            message ??
                (searching
                    ? 'No matching notes'
                    : 'A fresh space for your ideas'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            searching
                ? 'Try another word or clear the search.'
                : message != null
                ? 'Choose another view or reset filters to see your notes.'
                : 'Keep a thought close. Start with a note.',
            textAlign: TextAlign.center,
          ),
          if (onReset != null)
            TextButton(onPressed: onReset, child: const Text('Show all notes')),
          if (!searching && message == null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create a note'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _TrashCard extends StatelessWidget {
  const _TrashCard({required this.note, required this.controller});
  final Note note;
  final NotesController controller;

  Future<void> _command(BuildContext context, bool permanent) async {
    if (permanent) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permanently delete this note?'),
          content: const Text(
            'This cannot be undone. A previously exported backup will keep its copy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete permanently'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      if (permanent) {
        await controller.purge(note.id);
      } else {
        await controller.restore(note.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              permanent ? 'Note permanently deleted' : 'Note restored to Notes',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey(note.id),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.deletedAt == null
                ? 'In Trash'
                : 'Deleted ${noteTime(note.deletedAt!)}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              note.displayTitle,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => _command(context, false),
                icon: const Icon(Icons.restore),
                label: const Text('Restore'),
              ),
              IconButton(
                tooltip: note.ownerId == guestOwner
                    ? 'Delete permanently'
                    : 'Account Trash retains sync records',
                onPressed: note.ownerId == guestOwner
                    ? () => _command(context, true)
                    : null,
                icon: const Icon(Icons.delete_forever_outlined),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({required this.note, required this.controller});
  final Note note;
  final NotesController controller;

  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey(note.id),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              note.plainText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              try {
                await controller.archive(note.id, archived: false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Note restored from Archive')),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not restore: $error')),
                  );
                }
              }
            },
            icon: const Icon(Icons.unarchive_outlined),
            label: const Text('Restore from Archive'),
          ),
        ],
      ),
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
    final preview = note.title.trim().isEmpty
        ? note.plainText.trimLeft().split('\n').skip(1).join('\n')
        : note.plainText;
    return Semantics(
      container: true,
      label:
          '${note.displayTitle}. $preview. Updated ${noteTime(note.updatedAt)}. '
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
                        if (value == -2 || value == -3) {
                          try {
                            if (value == -2) {
                              await controller.save(
                                note.copyWith(favorite: !note.favorite),
                              );
                            } else {
                              await controller.archive(note.id);
                            }
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not update note: $error',
                                  ),
                                ),
                              );
                            }
                          }
                          return;
                        }
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
                                'Move this note to Trash? You can restore it later.',
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
                        try {
                          await controller.flushAllEditors();
                          await controller.delete(note);
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not move to Trash: $error',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem<int>(
                          value: -2,
                          child: Text(
                            note.favorite ? 'Remove favorite' : 'Favorite',
                          ),
                        ),
                        const PopupMenuItem<int>(
                          value: -3,
                          child: Text('Archive note'),
                        ),
                        const PopupMenuDivider(),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    if (note.favorite)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.star,
                          size: 16,
                          semanticLabel: 'Favorite',
                        ),
                      ),
                    Expanded(
                      child: Text(
                        note.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (note.tasks.total > 0 || note.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    [
                      if (note.tasks.total > 0)
                        '${note.tasks.done}/${note.tasks.total} tasks',
                      if (note.tags.isNotEmpty) note.tags.join(', '),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
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
                      thumbnail: true,
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                  child: Text(
                    preview,
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
    this.thumbnail = false,
  });

  final NoteEditorStore controller;
  final String noteId;
  final String imageId;
  final BoxFit fit;
  final bool thumbnail;

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
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: Icon(Icons.image_outlined, semanticLabel: 'Loading image'),
        );
      }
      if (!snapshot.hasData || snapshot.hasError) return _unavailableImage();
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          snapshot.data!,
          fit: widget.fit,
          width: double.infinity,
          cacheHeight: widget.thumbnail
              ? (72 * MediaQuery.devicePixelRatioOf(context)).ceil()
              : null,
          semanticLabel: 'Attached note image',
          errorBuilder: (_, _, _) => _unavailableImage(),
        ),
      );
    },
  );

  Widget _unavailableImage() => Center(
    child: widget.thumbnail
        ? const Tooltip(
            message: 'Image unavailable. Open the note to retry or restore from a backup.',
            child: Icon(
              Icons.broken_image_outlined,
              semanticLabel: 'Image unavailable',
            ),
          )
        : SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Image unavailable', textAlign: TextAlign.center),
                const Text(
                  'Retry loading or restore a copy from a complete backup.',
                  textAlign: TextAlign.center,
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _image = widget.controller.image(
                      widget.noteId,
                      widget.imageId,
                    );
                  }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry image'),
                ),
              ],
            ),
          ),
  );
}

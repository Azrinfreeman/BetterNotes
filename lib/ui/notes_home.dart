import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/note.dart';
import '../data/templates.dart';
import '../desktop/window_chrome.dart';
import '../state/notes_controller.dart';
export 'note_cards.dart';
import 'note_cards.dart';
import 'note_page.dart';
import 'settings_page.dart';
import 'bulk_actions.dart';
import 'shortcuts_help.dart';
import 'tag_manager.dart';

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

  Future<void> _applyFilter(SavedFilter filter) async {
    _search.text = filter.query;
    setState(_selected.clear);
    await _options(view: filter.view, sort: filter.sort, tags: filter.tags);
  }

  Future<void> _saveFilter() async {
    final field = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save this search'),
          content: TextField(
            key: const ValueKey('filter-name'),
            controller: field,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Name',
              helperText: 'Keeps the search text, view, sort, and tags. Same name replaces.',
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, field.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty) return;
      await widget.controller.saveFilter(name, _search.text);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save search: $error')),
        );
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      field.dispose();
    }
  }

  Widget _savedFilters() {
    final filters = widget.controller.savedFilters;
    final custom =
        _search.text.trim().isNotEmpty ||
        widget.controller.selectedTags.isNotEmpty ||
        widget.controller.libraryView != LibraryView.notes ||
        widget.controller.noteSort != NoteSort.updated;
    if (filters.isEmpty && !custom) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final filter in filters)
            InputChip(
              key: ValueKey('saved-filter-${filter.name}'),
              label: Text(filter.name),
              avatar: const Icon(Icons.bookmark_outline, size: 18),
              onPressed: () => _applyFilter(filter),
              deleteIcon: const Icon(Icons.close, size: 18),
              deleteButtonTooltipMessage: 'Delete saved search ${filter.name}',
              onDeleted: () => widget.controller.deleteFilter(filter.name),
            ),
          if (custom)
            ActionChip(
              avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('Save search'),
              onPressed: _saveFilter,
            ),
        ],
      ),
    );
  }

  Future<void> _options({
    LibraryView? view,
    NoteSort? sort,
    List<String>? tags,
    bool? compact,
    bool reset = false,
  }) async {
    try {
      await widget.controller.setLibraryOptions(
        view: view,
        sort: sort,
        tags: tags,
        compact: compact,
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
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await showTagManager(context, widget.controller);
                          refresh(() {
                            final now = widget.controller.availableTags;
                            available
                              ..clear()
                              ..addAll(now);
                            selected.retainAll(now);
                          });
                        },
                        child: const Text('Manage tags'),
                      ),
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

  final Set<String> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  void _tapNote(String id) {
    if (_selecting || HardwareKeyboard.instance.isControlPressed) {
      _toggle(id);
    } else {
      _openNote(id);
    }
  }

  Future<void> _bulk(Future<int> Function() action, String done) async {
    try {
      final count = await action();
      if (!mounted) return;
      setState(_selected.clear);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$done: $count note(s).')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update notes: $error')),
        );
      }
    }
  }

  Future<void> _bulkTrash() async {
    final ids = _selected.toList();
    if (widget.controller.confirmDelete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Move ${ids.length} note(s) to Trash?'),
          content: const Text('You can restore them from Trash later.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Move to Trash'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _bulk(() => widget.controller.bulkTrash(ids), 'Moved to Trash');
  }

  Future<void> _bulkMore(String choice) async {
    final ids = _selected.toList();
    switch (choice) {
      case 'all':
        setState(() {
          _selected.addAll(
            widget.controller
                .librarySearch(_search.text)
                .where((note) => !note.deleted && note.archivedAt == null)
                .map((note) => note.id),
          );
        });
      case 'unfavorite':
        await _bulk(
          () => widget.controller.bulkFavorite(ids, false),
          'Removed favorite',
        );
      case 'color':
        final color = await pickNoteColor(context);
        if (color != null && mounted) {
          await _bulk(
            () => widget.controller.bulkColor(ids, color),
            'Color changed',
          );
        }
      case 'tags':
        final tags = await askTagsToAdd(
          context,
          widget.controller.availableTags,
        );
        if (tags != null && mounted) {
          await _bulk(
            () => widget.controller.bulkAddTags(ids, tags),
            'Tags added',
          );
        }
      case 'export':
        await _bulk(() async {
          final message = await exportNotesMarkdown(widget.controller, [
            for (final id in ids)
              if (widget.controller.noteById(id) case final Note note) note,
          ]);
          return message == null ? 0 : ids.length;
        }, 'Exported');
    }
  }

  PreferredSizeWidget _selectionBar(BuildContext context) => AppBar(
    leading: IconButton(
      tooltip: 'Clear selection',
      icon: const Icon(Icons.close),
      onPressed: () => setState(_selected.clear),
    ),
    title: Text('${_selected.length} selected'),
    actions: [
      IconButton(
        tooltip: 'Favorite selected',
        icon: const Icon(Icons.star_outline),
        onPressed: () => _bulk(
          () => widget.controller.bulkFavorite(_selected.toList(), true),
          'Favorited',
        ),
      ),
      IconButton(
        tooltip: 'Archive selected',
        icon: const Icon(Icons.archive_outlined),
        onPressed: () => _bulk(
          () => widget.controller.bulkArchive(_selected.toList()),
          'Archived',
        ),
      ),
      IconButton(
        tooltip: 'Move selected to Trash',
        icon: const Icon(Icons.delete_outline),
        onPressed: _bulkTrash,
      ),
      PopupMenuButton<String>(
        tooltip: 'More selection actions',
        onSelected: _bulkMore,
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'all', child: Text('Select all shown')),
          PopupMenuItem(value: 'color', child: Text('Set color')),
          PopupMenuItem(value: 'tags', child: Text('Add tags')),
          PopupMenuItem(value: 'unfavorite', child: Text('Remove favorite')),
          PopupMenuItem(value: 'export', child: Text('Export as Markdown')),
        ],
      ),
      const WindowButtons(),
      const SizedBox(width: 8),
    ],
  );

  Widget _libraryItem(Note note, bool showTrash) {
    if (showTrash) {
      return TrashCard(note: note, controller: widget.controller);
    }
    if (note.archivedAt != null) {
      return ArchiveCard(note: note, controller: widget.controller);
    }
    final selected = _selected.contains(note.id);
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onLongPress: () => _toggle(note.id),
      child: Stack(
        children: [
          Positioned.fill(
            child: widget.controller.compactView
                ? CompactNoteTile(
                    key: ValueKey(note.id),
                    note: note,
                    selected: selected,
                    onOpen: () => _tapNote(note.id),
                  )
                : NoteCard(
                    key: ValueKey(note.id),
                    note: note,
                    controller: widget.controller,
                    onOpen: () => _tapNote(note.id),
                  ),
          ),
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: primary, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (selected)
            Positioned(
              top: 8,
              right: 8,
              child: IgnorePointer(
                child: Icon(
                  Icons.check_circle,
                  color: primary,
                  semanticLabel: 'Selected',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _newNote([NoteTemplate? template]) async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final note = template == null
          ? await widget.controller.create()
          : await widget.controller.createFromTemplate(template);
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
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (_selecting) setState(_selected.clear);
      },
      const SingleActivator(LogicalKeyboardKey.f1): () =>
          showShortcutsHelp(context),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): _newNote,
      const SingleActivator(LogicalKeyboardKey.keyF, control: true):
          _searchFocus.requestFocus,
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        appBar: _selecting
            ? _selectionBar(context)
            : AppBar(
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
                  PopupMenuButton<NoteTemplate>(
                    tooltip: 'New note from template',
                    icon: const Icon(Icons.note_add_outlined),
                    enabled: !_creating,
                    onSelected: _newNote,
                    itemBuilder: (_) => [
                      for (final template in noteTemplates)
                        PopupMenuItem(
                          value: template,
                          child: Text(template.name),
                        ),
                    ],
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
                                      IconButton(
                                        tooltip: widget.controller.compactView
                                            ? 'Card view'
                                            : 'Compact list view',
                                        icon: Icon(
                                          widget.controller.compactView
                                              ? Icons.grid_view_outlined
                                              : Icons.view_list_outlined,
                                        ),
                                        onPressed: () => _options(
                                          compact:
                                              !widget.controller.compactView,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _savedFilters(),
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
                            child: EmptyState(
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
                        if (widget.controller.compactView && !showTrash) {
                          return SliverPadding(
                            padding: const EdgeInsets.only(bottom: 100),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: SizedBox(
                                    height: notes[index].archivedAt != null
                                        ? 270
                                        : 72 *
                                              MediaQuery.textScalerOf(context)
                                                  .scale(1)
                                                  .clamp(1, 3),
                                    child: _libraryItem(
                                      notes[index],
                                      showTrash,
                                    ),
                                  ),
                                ),
                                childCount: notes.length,
                              ),
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
                                  (context, index) =>
                                      _libraryItem(notes[index], showTrash),
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

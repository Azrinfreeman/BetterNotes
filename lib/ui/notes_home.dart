import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
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
import 'theme/notes_theme.dart';
import 'theme/notes_chrome.dart';

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
  bool _filtersOpen = false;
  bool _sidebarOpen = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
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
          title: Text(context.l10n.notesHomeSaveThisSearch),
          content: TextField(
            key: const ValueKey('filter-name'),
            controller: field,
            autofocus: true,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: context.l10n.notesHomeName,
              helperText: context.l10n.notesHomeKeepsTheSearchTextView,
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.bulkCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, field.text),
              child: Text(context.l10n.noteDetailsSave),
            ),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty) return;
      await widget.controller.saveFilter(name, _search.text);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.notesHomeCouldNotSaveSearch('$error')),
          ),
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
              deleteButtonTooltipMessage: context.l10n
                  .notesHomeDeleteSavedSearch(filter.name),
              onDeleted: () => widget.controller.deleteFilter(filter.name),
            ),
          if (custom)
            ActionChip(
              avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: Text(context.l10n.notesHomeSaveSearch),
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
    bool? favoritesFirst,
    bool reset = false,
  }) async {
    try {
      await widget.controller.setLibraryOptions(
        view: view,
        sort: sort,
        tags: tags,
        compact: compact,
        favoritesFirst: favoritesFirst,
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
          SnackBar(
            content: Text(context.l10n.notesHomeCouldNotSaveFilters('$error')),
          ),
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
                    context.l10n.notesHomeMatchAllSelectedTags,
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
                        child: Text(context.l10n.notesHomeManageTags),
                      ),
                      TextButton(
                        onPressed: () => refresh(selected.clear),
                        child: Text(context.l10n.notesHomeClearTags),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, selected.toList()),
                        child: Text(context.l10n.notesHomeApply),
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
        content: Text(context.l10n.noteMovedToTrash),
        // A snackbar with an action stays until dismissed unless told not to.
        persist: false,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: context.l10n.noteUndo,
          onPressed: () async {
            try {
              await controller.restore(id);
            } catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.noteCouldNotRestore('$error')),
                  ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.notesHomeNoteS(done, '$count'))),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.notesHomeCouldNotUpdateNotes('$error')),
          ),
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
          title: Text(context.l10n.notesHomeMoveNoteSToTrash('${ids.length}')),
          content: Text(context.l10n.notesHomeYouCanRestoreThemFrom),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.bulkCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.notesHomeMoveToTrash),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _bulk(
      () => widget.controller.bulkTrash(ids),
      context.l10n.bulkDoneMovedToTrash,
    );
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
          context.l10n.bulkDoneRemovedFavorite,
        );
      case 'color':
        final color = await pickNoteColor(context);
        if (color != null && mounted) {
          await _bulk(
            () => widget.controller.bulkColor(ids, color),
            context.l10n.bulkDoneColorChanged,
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
            context.l10n.bulkDoneTagsAdded,
          );
        }
      case 'export':
        await _bulk(() async {
          final message = await exportNotesMarkdown(
            widget.controller,
            context.l10n,
            [
              for (final id in ids)
                if (widget.controller.noteById(id) case final Note note) note,
            ],
          );
          return message == null ? 0 : ids.length;
        }, context.l10n.bulkDoneExported);
    }
  }

  PreferredSizeWidget _selectionBar(BuildContext context) => AppBar(
    leading: IconButton(
      tooltip: context.l10n.notesHomeClearSelection,
      icon: const Icon(Icons.close),
      onPressed: () => setState(_selected.clear),
    ),
    title: Text(context.l10n.notesHomeSelected('${_selected.length}')),
    actions: [
      IconButton(
        tooltip: context.l10n.notesHomeFavoriteSelected,
        icon: const Icon(Icons.star_outline),
        onPressed: () => _bulk(
          () => widget.controller.bulkFavorite(_selected.toList(), true),
          context.l10n.bulkDoneFavorited,
        ),
      ),
      IconButton(
        tooltip: context.l10n.notesHomeArchiveSelected,
        icon: const Icon(Icons.archive_outlined),
        onPressed: () => _bulk(
          () => widget.controller.bulkArchive(_selected.toList()),
          context.l10n.bulkDoneArchived,
        ),
      ),
      IconButton(
        tooltip: context.l10n.notesHomeMoveSelectedToTrash,
        icon: const Icon(Icons.delete_outline),
        onPressed: _bulkTrash,
      ),
      PopupMenuButton<String>(
        tooltip: context.l10n.notesHomeMoreSelectionActions,
        onSelected: _bulkMore,
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'all',
            child: Text(context.l10n.notesHomeSelectAllShown),
          ),
          PopupMenuItem(value: 'color', child: Text(context.l10n.bulkSetColor)),
          PopupMenuItem(value: 'tags', child: Text(context.l10n.bulkAddTags)),
          PopupMenuItem(
            value: 'unfavorite',
            child: Text(context.l10n.notesHomeRemoveFavorite),
          ),
          PopupMenuItem(
            value: 'export',
            child: Text(context.l10n.noteExportAsMarkdown),
          ),
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
                    sort: widget.controller.noteSort,
                    onOpen: () => _tapNote(note.id),
                  )
                : NoteCard(
                    key: ValueKey(note.id),
                    note: note,
                    controller: widget.controller,
                    sort: widget.controller.noteSort,
                    onOpen: () => _tapNote(note.id),
                  ),
          ),
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: primary, width: 2),
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
                  semanticLabel: context.l10n.notesHomeSelected2,
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
          SnackBar(
            content: Text(context.l10n.notesHomeCouldNotCreateNote('$error')),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.notesHomeCouldNotOpenNote('$error')),
          ),
        );
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

  Map<LibraryView, String> get _views => {
    LibraryView.notes: context.l10n.viewNotes,
    LibraryView.allActive: context.l10n.notesHomeAllActive,
    LibraryView.favorites: context.l10n.viewFavorites,
    LibraryView.reminders: context.l10n.viewReminders,
    LibraryView.archive: context.l10n.viewArchive,
    LibraryView.trash: context.l10n.viewTrash,
  };

  static const _viewIcons = {
    LibraryView.notes: Icons.notes_rounded,
    LibraryView.allActive: Icons.library_books_outlined,
    LibraryView.favorites: Icons.star_outline_rounded,
    LibraryView.reminders: Icons.notifications_none_rounded,
    LibraryView.archive: Icons.archive_outlined,
    LibraryView.trash: Icons.delete_outline_rounded,
  };

  Widget _navigation({bool drawer = false}) => Material(
    color: NotesColors.of(context).sidebar,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final entry in _views.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      key: ValueKey('library-view-${entry.key.name}'),
                      leading: Icon(_viewIcons[entry.key], size: 20),
                      title: Text(entry.value),
                      selected: widget.controller.libraryView == entry.key,
                      onTap: () {
                        _options(view: entry.key);
                        if (drawer) Navigator.of(context).pop();
                      },
                    ),
                  ),
                if (widget.controller.savedFilters.isNotEmpty) ...[
                  const Divider(),
                  for (final filter in widget.controller.savedFilters)
                    ListTile(
                      key: ValueKey('saved-filter-${filter.name}'),
                      leading: const Icon(Icons.bookmark_outline, size: 18),
                      title: Text(
                        filter.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        _applyFilter(filter);
                        if (drawer) Navigator.of(context).pop();
                      },
                      trailing: IconButton(
                        tooltip: context.l10n.notesHomeDeleteSavedSearch(
                          filter.name,
                        ),
                        onPressed: () =>
                            widget.controller.deleteFilter(filter.name),
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ),
                ],
                if (widget.controller.availableTags.isNotEmpty) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.label_outline, size: 20),
                    title: Text(context.l10n.notesHomeFilterByTags),
                    onTap: () {
                      if (drawer) Navigator.of(context).pop();
                      _chooseTags();
                    },
                  ),
                  for (final tag in widget.controller.availableTags)
                    ListTile(
                      dense: true,
                      title: Text(
                        tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: widget.controller.selectedTags.contains(tag),
                      leading: const Icon(Icons.tag, size: 16),
                      onTap: () {
                        _options(
                          tags: widget.controller.selectedTags.contains(tag)
                              ? []
                              : [tag],
                        );
                        if (drawer) Navigator.of(context).pop();
                      },
                    ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(context.l10n.notesHomeSettings),
              onTap: () {
                if (drawer) Navigator.of(context).pop();
                _openSettings();
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sortControls() => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: constraints.maxWidth < 440 ? constraints.maxWidth : 240,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<NoteSort>(
              key: const ValueKey('sort-order'),
              value: widget.controller.noteSort,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              onChanged: (sort) => _options(sort: sort),
              items: [
                for (final entry in {
                  NoteSort.updated: context.l10n.notesHomeRecentlyEdited,
                  NoteSort.updatedOldest: context.l10n.sortUpdatedOldest,
                  NoteSort.created: context.l10n.notesHomeNewestCreated,
                  NoteSort.createdOldest: context.l10n.sortCreatedOldest,
                  NoteSort.title: context.l10n.notesHomeTitleAZ,
                  NoteSort.titleDesc: context.l10n.sortTitleDesc,
                  NoteSort.reminder: context.l10n.sortReminder,
                  NoteSort.color: context.l10n.sortColor,
                  NoteSort.length: context.l10n.sortLength,
                }.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
        FilterChip(
          key: const ValueKey('favorites-first'),
          label: Text(context.l10n.sortFavoritesFirst),
          selected: widget.controller.favoritesFirst,
          onSelected: (value) => _options(favoritesFirst: value),
        ),
        if (_search.text.isNotEmpty ||
            widget.controller.selectedTags.isNotEmpty ||
            widget.controller.noteSort != NoteSort.updated)
          TextButton(
            onPressed: () {
              _search.clear();
              _options(reset: true);
            },
            child: Text(context.l10n.notesHomeResetFilters),
          ),
      ],
    ),
  );

  Widget _searchField() => TextField(
    controller: _search,
    focusNode: _searchFocus,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      hintText: context.l10n.notesHomeSearchTitlesAndTextIn,
      prefixIcon: const Icon(Icons.search, size: 20),
      suffixIcon: _search.text.isEmpty
          ? null
          : IconButton(
              tooltip: context.l10n.notesHomeClearSearch,
              icon: const Icon(Icons.close),
              onPressed: () {
                _search.clear();
                setState(() {});
              },
            ),
    ),
  );

  Widget _collectionHeader(bool sidebar) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  _views[widget.controller.libraryView]!,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            IconButton(
              tooltip: context.l10n.libraryFilters,
              isSelected: _filtersOpen,
              onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
              icon: const Icon(Icons.tune_rounded),
            ),
            IconButton(
              tooltip: widget.controller.compactView
                  ? context.l10n.notesHomeCardView
                  : context.l10n.notesHomeCompactListView,
              onPressed: () =>
                  _options(compact: !widget.controller.compactView),
              icon: Icon(
                widget.controller.compactView
                    ? Icons.grid_view_outlined
                    : Icons.view_list_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _searchField(),
        if (_search.text.isNotEmpty &&
            widget.controller.libraryView != LibraryView.allActive)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _options(view: LibraryView.allActive),
              child: Text(context.l10n.notesHomeSearchAllActiveNotesIncluding),
            ),
          ),
        const SizedBox(height: 8),
        _sortControls(),
        NotesSpringPanel(
          open: _filtersOpen || widget.controller.selectedTags.isNotEmpty,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _chooseTags,
              icon: const Icon(Icons.label_outline),
              label: Text(
                widget.controller.selectedTags.isEmpty
                    ? context.l10n.notesHomeFilterByTags
                    : context.l10n.notesHomeTags(
                        widget.controller.selectedTags.join(', '),
                      ),
              ),
            ),
          ),
        ),
        // Save-search stays near the query; saved searches live in navigation.
        if (!sidebar) _savedFilters(),
        if (sidebar &&
            (_search.text.isNotEmpty ||
                widget.controller.selectedTags.isNotEmpty ||
                widget.controller.libraryView != LibraryView.notes ||
                widget.controller.noteSort != NoteSort.updated))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saveFilter,
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: Text(context.l10n.notesHomeSaveSearch),
            ),
          ),
        if (widget.controller.autoBackupError != null)
          _notice(
            widget.controller.autoBackupError!,
            Icons.backup_outlined,
            _openSettings,
            context.l10n.notesHomeSettings,
            warning: true,
          ),
        if (widget.controller.saveFailure != null)
          _notice(
            widget.controller.saveFailure!,
            Icons.error_outline,
            () async {
              try {
                await widget.controller.flushAllEditors();
              } catch (error) {
                widget.controller.reportSaveFailure('Save failed: $error');
              }
            },
            context.l10n.noteRetry,
          ),
      ],
    ),
  );

  Widget _notice(
    String message,
    IconData icon,
    VoidCallback action,
    String label, {
    bool warning = false,
  }) {
    final colors = NotesColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: ListTile(
        tileColor: warning ? colors.warningSurface : scheme.errorContainer,
        textColor: warning ? colors.warning : scheme.onErrorContainer,
        iconColor: warning ? colors.warning : scheme.onErrorContainer,
        leading: Icon(icon),
        title: Text(message),
        trailing: TextButton(onPressed: action, child: Text(label)),
      ),
    );
  }

  Widget _collectionSliver() => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final query = _search.text.trim().toLowerCase();
      final notes = widget.controller.librarySearch(query);
      final showTrash = widget.controller.libraryView == LibraryView.trash;
      if (notes.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            searching: query.isNotEmpty,
            onCreate: _newNote,
            message: showTrash
                ? query.isEmpty
                      ? context.l10n.notesHomeTrashIsEmpty
                      : context.l10n.notesHomeNoMatchingNotesInTrash
                : widget.controller.libraryView != LibraryView.notes ||
                      widget.controller.selectedTags.isNotEmpty
                ? context.l10n.notesHomeNoNotesMatchThisView
                : null,
            onReset:
                query.isNotEmpty ||
                    widget.controller.selectedTags.isNotEmpty ||
                    widget.controller.libraryView != LibraryView.notes
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
                  child: _libraryItem(notes[index], showTrash),
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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent:
                    270 +
                    (MediaQuery.textScalerOf(context).scale(14) / 14 - 1).clamp(
                          0,
                          3,
                        ) *
                        140,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _libraryItem(notes[index], showTrash),
                childCount: notes.length,
              ),
            ),
          );
        },
      );
    },
  );

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
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final sidebar =
                constraints.maxWidth >= 720 &&
                _sidebarOpen &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.5;
            return Scaffold(
              key: _scaffoldKey,
              drawer: sidebar
                  ? null
                  : Drawer(
                      shape: const RoundedRectangleBorder(),
                      child: _navigation(drawer: true),
                    ),
              appBar: _selecting
                  ? _selectionBar(context)
                  : AppBar(
                      leading: IconButton(
                        tooltip: context.l10n.libraryNavigation,
                        onPressed: () {
                          if (sidebar) {
                            setState(() => _sidebarOpen = false);
                          } else if (constraints.maxWidth >= 720 &&
                              MediaQuery.textScalerOf(context).scale(1) <=
                                  1.5) {
                            setState(() => _sidebarOpen = true);
                          } else {
                            _scaffoldKey.currentState?.openDrawer();
                          }
                        },
                        icon: const Icon(Icons.view_sidebar_outlined),
                      ),
                      title: WindowTitle(
                        child: Text(context.l10n.windowChromeBetternotes),
                      ),
                      actions: [
                        IconButton(
                          tooltip: widget.controller.syncError != null
                              ? context.l10n.settingsSyncNeedsAttention
                              : widget.controller.signedIn
                              ? context.l10n.notesHomeSyncNotes
                              : context.l10n.notesHomeLocalNotes,
                          icon: Icon(
                            widget.controller.syncError != null
                                ? Icons.cloud_off_outlined
                                : widget.controller.syncing
                                ? Icons.sync
                                : widget.controller.signedIn
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_outlined,
                          ),
                          color: widget.controller.syncError != null
                              ? Theme.of(context).colorScheme.error
                              : null,
                          onPressed: widget.controller.signedIn
                              ? widget.controller.sync
                              : _openSettings,
                        ),
                        if (constraints.maxWidth >= 480) ...[
                          FilledButton.icon(
                            onPressed: _creating ? null : _newNote,
                            icon: const Icon(Icons.edit_square, size: 18),
                            label: Text(context.l10n.noteDesktopHeaderNewNote),
                          ),
                          const SizedBox(width: 4),
                        ] else
                          IconButton(
                            tooltip: context.l10n.noteDesktopHeaderNewNote,
                            onPressed: _creating ? null : _newNote,
                            icon: const Icon(Icons.edit_square),
                          ),
                        PopupMenuButton<NoteTemplate>(
                          tooltip: context.l10n.notesHomeNewNoteFromTemplate,
                          icon: const Icon(Icons.expand_more),
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
                        if (!sidebar)
                          IconButton(
                            tooltip: context.l10n.notesHomeSettings,
                            onPressed: _openSettings,
                            icon: const Icon(Icons.settings_outlined),
                          ),
                        const WindowButtons(),
                        const SizedBox(width: 8),
                      ],
                    ),
              body: SafeArea(
                child: Row(
                  children: [
                    if (sidebar) ...[
                      SizedBox(width: wide ? 248 : 216, child: _navigation()),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ],
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: wide ? 24 : 16,
                        ),
                        child: CustomScrollView(
                          controller: _libraryScroll,
                          slivers: [
                            SliverToBoxAdapter(
                              child: _collectionHeader(sidebar),
                            ),
                            _collectionSliver(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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

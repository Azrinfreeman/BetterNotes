import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute, listEquals;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/cloud_sync.dart';
import '../data/app_log.dart';
import '../data/auto_backup.dart' as auto_backup;
import '../data/backup.dart';
import '../data/local_store.dart';
import '../data/clipboard_image.dart';
import '../data/image_shrink.dart';
import '../data/note.dart';
import '../data/sticky_import.dart';
import '../data/revision.dart';
import '../data/templates.dart';
import 'note_editor_store.dart';

enum LibraryView { notes, favorites, archive, trash, allActive, reminders }

/// How the library is ordered. The `*Oldest`/`Desc` values reverse their
/// pair; names of the original three stay stable because they are saved.
enum NoteSort {
  updated,
  updatedOldest,
  created,
  createdOldest,
  title,
  titleDesc,
  reminder,
  color,
  length,
}

/// A named combination of search text, view, sort, and tags.
class SavedFilter {
  const SavedFilter({
    required this.name,
    this.query = '',
    this.view = LibraryView.notes,
    this.sort = NoteSort.updated,
    this.tags = const [],
  });

  final String name;
  final String query;
  final LibraryView view;
  final NoteSort sort;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
    'name': name,
    'query': query,
    'view': view.name,
    'sort': sort.name,
    'tags': tags,
  };

  factory SavedFilter.fromJson(Map<dynamic, dynamic> json) => SavedFilter(
    name: json['name'] as String? ?? '',
    query: json['query'] as String? ?? '',
    view:
        LibraryView.values
            .where((view) => view.name == json['view'])
            .firstOrNull ??
        LibraryView.notes,
    sort:
        NoteSort.values
            .where((sort) => sort.name == json['sort'])
            .firstOrNull ??
        NoteSort.updated,
    tags: normalizeTags(
      (json['tags'] as List? ?? const []).whereType<String>(),
    ),
  );
}

class NotesController extends NoteEditorStore {
  NotesController(this.store, this.client) {
    if (client != null) {
      _authSubscription = client!.auth.onAuthStateChange.listen((event) {
        _handleAuthChange(event.session?.user.id);
      });
    }
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => sync());
  }

  final LocalStore store;
  final SupabaseClient? client;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _poll;
  Timer? _debounce;
  String? _lastOwner;

  List<Note> _notes = [];
  Map<String, Note> _byId = {};
  Map<String, String> _searchText = {};
  List<Note>? _activeCache;
  List<Note>? _trashCache;
  List<Note>? _archiveCache;
  List<Note>? _libraryCache;
  List<String>? _tagsCache;
  LibraryView libraryView = LibraryView.notes;
  NoteSort noteSort = NoteSort.updated;
  List<String> selectedTags = [];
  bool compactView = false;
  bool favoritesFirst = true;
  String? autoBackupFolder;
  int autoBackupKeep = 7;
  DateTime? autoBackupLast;
  String? autoBackupError;
  bool autoBackupRunning = false;
  Timer? _autoBackupTimer;

  /// How often an automatic backup is due.
  Duration autoBackupInterval = const Duration(hours: 24);
  List<SavedFilter> savedFilters = const [];
  int trashRetentionDays = 0;
  Future<void>? _writes;
  final Map<String, DateTime> _lastRevision = {};

  /// Minimum time between automatic checkpoints of one note.
  Duration revisionInterval = const Duration(minutes: 5);
  final Map<String, int> _generations = {};

  List<Note> get notes => _activeCache ??= _sorted(false);
  List<Note> get trash => _trashCache ??= _sorted(true);
  List<Note> get archiveNotes => _archiveCache ??= List.unmodifiable(
    _notes.where((note) => !note.deleted && note.archivedAt != null).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );
  @override
  List<String> get availableTags =>
      _tagsCache ??= normalizeTags(_notes.expand((note) => note.tags));

  List<Note> _sorted(bool deleted) => List.unmodifiable(
    _notes
        .where(
          (note) =>
              note.deleted == deleted && (deleted || note.archivedAt == null),
        )
        .toList()
      ..sort((a, b) {
        if (!deleted && a.favorite != b.favorite) return a.favorite ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      }),
  );

  List<Note> librarySearch(String query) {
    final collection = _libraryCache ??= _libraryCollection();
    final normalized = query.trim().toLowerCase();
    return normalized.isEmpty
        ? collection
        : collection
              .where((note) => _searchText[note.id]!.contains(normalized))
              .toList();
  }

  List<Note> _libraryCollection() {
    final collection = switch (libraryView) {
      LibraryView.notes || LibraryView.favorites => notes,
      LibraryView.archive => archiveNotes,
      LibraryView.trash => trash,
      LibraryView.allActive => _notes.where((note) => !note.deleted).toList(),
      LibraryView.reminders => [
        for (final note in _notes)
          if (!note.deleted && note.archivedAt == null && note.remindAt != null)
            note,
      ],
    };
    final results = collection
        .where(
          (note) =>
              (libraryView != LibraryView.favorites || note.favorite) &&
              selectedTags.every(note.tags.contains),
        )
        .toList();
    results.sort((a, b) {
      if (libraryView == LibraryView.reminders) {
        // Upcoming first, then reminders that already fired.
        if (a.reminderFired != b.reminderFired) return a.reminderFired ? 1 : -1;
        return a.remindAt!.compareTo(b.remindAt!);
      }
      if (favoritesFirst &&
          libraryView != LibraryView.trash &&
          a.favorite != b.favorite) {
        return a.favorite ? -1 : 1;
      }
      final order = switch (noteSort) {
        NoteSort.updated => b.updatedAt.compareTo(a.updatedAt),
        NoteSort.updatedOldest => a.updatedAt.compareTo(b.updatedAt),
        NoteSort.created => b.createdAt.compareTo(a.createdAt),
        NoteSort.createdOldest => a.createdAt.compareTo(b.createdAt),
        NoteSort.title => a.displayTitle.toLowerCase().compareTo(
          b.displayTitle.toLowerCase(),
        ),
        NoteSort.titleDesc => b.displayTitle.toLowerCase().compareTo(
          a.displayTitle.toLowerCase(),
        ),
        // Soonest reminder first; notes without one follow, newest edit first.
        NoteSort.reminder =>
          a.remindAt != null && b.remindAt != null
              ? a.remindAt!.compareTo(b.remindAt!)
              : a.remindAt != null
              ? -1
              : b.remindAt != null
              ? 1
              : b.updatedAt.compareTo(a.updatedAt),
        NoteSort.color =>
          a.colorIndex != b.colorIndex
              ? a.colorIndex.compareTo(b.colorIndex)
              : b.updatedAt.compareTo(a.updatedAt),
        NoteSort.length => b.plainText.length.compareTo(a.plainText.length),
      };
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return List.unmodifiable(results);
  }

  Future<void> setLibraryOptions({
    LibraryView? view,
    NoteSort? sort,
    List<String>? tags,
    bool? compact,
    bool? favoritesFirst,
    bool reset = false,
  }) => _enqueue(() async {
    final nextView = reset ? LibraryView.notes : view ?? libraryView;
    final nextSort = reset ? NoteSort.updated : sort ?? noteSort;
    final nextTags = reset ? <String>[] : normalizeTags(tags ?? selectedTags);
    final nextCompact = compact ?? compactView;
    final nextFavoritesFirst = favoritesFirst ?? this.favoritesFirst;
    await store.setSetting('libraryOptions', {
      'view': nextView.name,
      'sort': nextSort.name,
      'tags': nextTags,
      'compact': nextCompact,
      'favoritesFirst': nextFavoritesFirst,
    });
    compactView = nextCompact;
    this.favoritesFirst = nextFavoritesFirst;
    libraryView = nextView;
    noteSort = nextSort;
    selectedTags = nextTags;
    _libraryCache = null;
    notifyListeners();
  });

  List<Note> search(String query, {bool inTrash = false}) {
    final collection = inTrash ? trash : notes;
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return collection;
    return collection
        .where((note) => _searchText[note.id]!.contains(normalized))
        .toList();
  }

  void _index() {
    _byId = {for (final note in _notes) note.id: note};
    _searchText = {
      for (final note in _notes)
        note.id: '${note.title}\n${note.plainText}'.toLowerCase(),
    };
    _activeCache = null;
    _trashCache = null;
    _archiveCache = null;
    _libraryCache = null;
    _tagsCache = null;
  }

  /// Like [_replace] for local-only metadata: no cloud sync is scheduled.
  void _replaceQuietly(Note note) {
    final index = _notes.indexWhere((value) => value.id == note.id);
    if (index < 0) return;
    _notes[index] = note;
    _byId[note.id] = note;
    _activeCache = null;
    _trashCache = null;
    _archiveCache = null;
    _libraryCache = null;
    notifyListeners();
  }

  void _replace(Note note) {
    final index = _notes.indexWhere((value) => value.id == note.id);
    if (index < 0) {
      _notes.add(note);
    } else {
      _notes[index] = note;
    }
    _byId[note.id] = note;
    _searchText[note.id] = '${note.title}\n${note.plainText}'.toLowerCase();
    _activeCache = null;
    _trashCache = null;
    _archiveCache = null;
    _libraryCache = null;
    _tagsCache = null;
    notifyListeners();
    _scheduleSync();
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final previous = _writes;
    final result = previous == null
        ? Future<T>.sync(action)
        : previous.then((_) => action());
    late final Future<void> tail;
    void completed() {
      if (identical(_writes, tail)) _writes = null;
    }

    tail = result.then<void>(
      (_) => completed(),
      onError: (Object error, StackTrace stack) => completed(),
    );
    _writes = tail;
    return result;
  }

  Future<void> waitForWrites() => _writes ?? Future<void>.value();
  @override
  Note? noteById(String id) {
    final note = _byId[id];
    return note?.deleted == false ? note : null;
  }

  String get ownerId => client?.auth.currentUser?.id ?? guestOwner;
  String? get email => client?.auth.currentUser?.email;
  bool get cloudAvailable => client != null;
  @override
  bool get signedIn => client?.auth.currentUser != null;

  @override
  ThemeMode themeMode = ThemeMode.system;
  @override
  bool confirmDelete = true;
  @override
  bool customWindowButtons = false;
  @override
  bool reduceTransparency = true;
  @override
  bool inlineImages = false;
  Set<String> stickyImported = {};
  @override
  ImageQuality imageQuality = ImageQuality.balanced;
  @override
  bool alwaysShowNoteHeader = false;
  bool fastNoteOpening = true;
  Future<void> Function()? applyFastNoteOpening;
  Future<void> Function()? applyTray;

  /// Called after reminders change so the desktop shell can refresh its
  /// scheduled task. Failures never block the change itself.
  Future<void> Function()? remindersChanged;
  bool reminderTaskEnabled = false;
  String? reminderTaskError;
  Future<void> Function()? applyQuickCapture;
  bool keepInTray = false;
  String quickCaptureKey = 'off';
  String? quickCaptureError;
  @override
  bool syncing = false;
  String? syncError;
  DateTime? lastSynced;
  int deletionSerial = 0;
  String? recentlyDeletedId;
  String? saveFailure;
  Future<void> Function()? flushDesktopEditors;
  Future<void> Function(String)? flushDesktopEditor;

  void reportSaveFailure(String message) {
    saveFailure = message;
    AppLog.write('ERROR', 'Save problem', message);
    notifyListeners();
  }

  Future<void> flushAllEditors() async {
    await flushEditors();
    await flushDesktopEditors?.call();
    await waitForWrites();
    saveFailure = null;
    notifyListeners();
  }

  Future<void> load() async {
    final schema = await store.getSetting<int>('localSchemaVersion') ?? 0;
    if (schema > 2) {
      throw StateError('This database needs a newer version of BetterNotes.');
    }
    final theme = await store.getSetting<String>('theme');
    themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    confirmDelete = await store.getSetting<bool>('confirmDelete') ?? true;
    customWindowButtons =
        await store.getSetting<bool>('customWindowButtons') ?? false;
    reduceTransparency =
        await store.getSetting<bool>('reduceTransparency') ?? true;
    inlineImages = await store.getSetting<bool>('inlineImages') ?? false;
    stickyImported = {
      ...?(await store.getSetting<List>('stickyImported'))?.whereType<String>(),
    };
    final imageQualityName = await store.getSetting<String>('imageQuality');
    imageQuality =
        ImageQuality.values
            .where((value) => value.name == imageQualityName)
            .firstOrNull ??
        ImageQuality.balanced;
    alwaysShowNoteHeader =
        await store.getSetting<bool>('alwaysShowNoteHeader') ?? false;
    fastNoteOpening = await store.getSetting<bool>('fastNoteOpening') ?? true;
    final options = await store.getSetting<Map>('libraryOptions');
    if (options != null) {
      libraryView =
          LibraryView.values
              .where((view) => view.name == options['view'])
              .firstOrNull ??
          LibraryView.notes;
      noteSort =
          NoteSort.values
              .where((sort) => sort.name == options['sort'])
              .firstOrNull ??
          NoteSort.updated;
      selectedTags = normalizeTags(
        (options['tags'] as List? ?? const []).whereType<String>(),
      );
      compactView = options['compact'] as bool? ?? false;
      favoritesFirst = options['favoritesFirst'] as bool? ?? true;
    }
    _lastOwner = ownerId;
    if (signedIn) await store.moveGuestNotes(ownerId);
    trashRetentionDays = await store.getSetting<int>('trashRetentionDays') ?? 0;
    keepInTray = await store.getSetting<bool>('keepInTray') ?? false;
    reminderTaskEnabled = await store.getSetting<bool>('reminderTask') ?? false;
    quickCaptureKey =
        await store.getSetting<String>('quickCaptureKey') ?? 'off';
    autoBackupFolder = await store.getSetting<String>('autoBackupFolder');
    autoBackupKeep = await store.getSetting<int>('autoBackupKeep') ?? 7;
    autoBackupError = await store.getSetting<String>('autoBackupError');
    autoBackupLast = DateTime.tryParse(
      await store.getSetting<String>('autoBackupLast') ?? '',
    );
    _scheduleAutoBackup();
    savedFilters = [
      for (final value
          in await store.getSetting<List>('savedFilters') ?? const [])
        if (value is Map && (value['name'] as String?)?.isNotEmpty == true)
          SavedFilter.fromJson(value),
    ];
    await reload();
    await purgeExpiredTrash();
    // Metadata is additive; legacy records remain intact and decode with defaults.
    if (schema < 2) await store.setSetting('localSchemaVersion', 2);
    if (signedIn) unawaited(sync());
  }

  Future<void> reload() async {
    _notes = await store.notesFor(ownerId);
    _index();
    notifyListeners();
  }

  Future<Note> create() => _enqueue(() async {
    final note = Note.fresh(ownerId);
    await store.putNote(note);
    _replace(note);
    return note;
  });

  Future<Note> createFromTemplate(NoteTemplate template) => _enqueue(() async {
    final note = Note.fresh(ownerId).copyWith(
      title: template.title,
      delta: template.delta,
      plainText: template.plainText,
    );
    await store.putNote(note);
    _replace(note);
    return note;
  });

  /// Copies a note with a new ID, copying image bytes under new IDs so the two
  /// notes never share assets.
  @override
  Future<Note?> duplicate(String id) async {
    await flushEditor(id);
    await flushDesktopEditor?.call(id);
    return _enqueue(() async {
      final source = noteById(id);
      if (source == null || source.ownerId != ownerId) return null;
      final ids = {...source.images, ...inlineImageIds(source.delta)};
      final remap = <String, String>{};
      for (final imageId in ids) {
        final bytes = await store.getImage(imageId);
        if (bytes == null) continue;
        final copyId = const Uuid().v4();
        await store.putImage(copyId, bytes);
        remap[imageId] = copyId;
      }
      final now = DateTime.now().toUtc();
      final base = Note.fresh(ownerId);
      final copy = base.copyWith(
        delta: remapInlineImages(source.delta, remap),
        plainText: source.plainText,
        colorIndex: source.colorIndex,
        images: [for (final image in source.images) remap[image] ?? image],
        strokes: source.strokes,
        title: source.title.trim().isEmpty ? '' : '${source.title.trim()} copy',
        tags: source.tags,
        createdAt: now,
        updatedAt: now,
      );
      await store.putNote(copy);
      _replace(copy);
      return copy;
    });
  }

  /// Notes (not in Trash) using each tag, for the tag manager.
  Map<String, int> get tagCounts {
    final counts = <String, int>{};
    for (final note in _notes) {
      if (note.deleted) continue;
      for (final tag in note.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Renames [from] to [to] on every note; if [to] already exists the tags
  /// merge. An empty [to] deletes the tag.
  Future<int> renameTag(String from, String to) async {
    final source = normalizeTags([from]);
    if (source.isEmpty) return 0;
    final target = normalizeTags([to]);
    await flushAllEditors();
    final changed = await _enqueue(() async {
      var changed = 0;
      for (final note in List<Note>.of(_notes)) {
        if (!note.tags.contains(source.single)) continue;
        final tags = [
          for (final tag in note.tags)
            if (tag != source.single) tag,
          ...target,
        ];
        final updated = note.copyWith(
          tags: tags,
          updatedAt: DateTime.now().toUtc(),
          dirty: true,
        );
        await store.putNote(updated);
        _generations[note.id] = (_generations[note.id] ?? 0) + 1;
        _replace(updated);
        changed++;
      }
      return changed;
    });
    if (selectedTags.contains(source.single)) {
      await setLibraryOptions(
        tags: [
          for (final tag in selectedTags)
            if (tag != source.single) tag,
          ...target,
        ],
      );
    }
    return changed;
  }

  Future<int> deleteTag(String tag) => renameTag(tag, '');

  @override
  Future<void> save(Note note) {
    final generation = _generations[note.id] ?? 0;
    final previous = noteById(note.id);
    if (note.ownerId != ownerId ||
        previous == null ||
        note.deleted ||
        previous.archivedAt != null) {
      return Future<void>.value();
    }
    return _enqueue(() async {
      final current = noteById(note.id);
      if (current == null ||
          generation != (_generations[note.id] ?? 0) ||
          note.ownerId != ownerId) {
        return;
      }
      // Apply only fields changed by this caller; queued text saves must not
      // undo a color/image change that was made while storage was busy.
      final changed = current.copyWith(
        title: note.title == previous.title ? null : note.title.trim(),
        favorite: note.favorite == previous.favorite ? null : note.favorite,
        tags: listEquals(note.tags, previous.tags) ? null : note.tags,
        delta: listEquals(note.delta, previous.delta) ? null : note.delta,
        plainText: note.plainText == previous.plainText ? null : note.plainText,
        colorIndex: note.colorIndex == previous.colorIndex
            ? null
            : note.colorIndex,
        images: listEquals(note.images, previous.images) ? null : note.images,
        strokes: listEquals(note.strokes, previous.strokes)
            ? null
            : note.strokes,
        updatedAt: DateTime.now().toUtc(),
        dirty: true,
      );
      await _checkpoint(current, changed);
      await store.putNote(changed);
      _replace(changed);
    });
  }

  /// Keeps [before] as a revision when the content changed and the last
  /// checkpoint is old enough. History is best effort and never blocks a save.
  Future<void> _checkpoint(Note before, Note after) async {
    if (listEquals(before.delta, after.delta) && before.title == after.title) {
      return;
    }
    if (before.plainText.trim().isEmpty && before.images.isEmpty) return;
    try {
      final now = DateTime.now().toUtc();
      var last = _lastRevision[before.id];
      if (last == null) {
        final existing = await store.revisionsFor(before.id);
        last = existing.isEmpty
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : existing.first.createdAt;
        _lastRevision[before.id] = last;
      }
      if (now.difference(last) < revisionInterval) return;
      await store.addRevision(
        NoteRevision.capture(before, const Uuid().v4(), now),
      );
      _lastRevision[before.id] = now;
    } catch (_) {
      // A failed checkpoint must not lose the user's edit.
    }
  }

  @override
  Future<List<NoteRevision>> revisions(String noteId) async {
    final note = noteById(noteId);
    if (note == null || note.ownerId != ownerId) return const [];
    return store.revisionsFor(noteId);
  }

  /// Creates a new note from an earlier version. The current note and the
  /// version itself are never changed; images are copied under new IDs.
  @override
  Future<Note?> restoreRevision(String revisionId) => _enqueue(() async {
    final revision = await store.revisionById(revisionId);
    if (revision == null) return null;
    final source = noteById(revision.noteId);
    if (source == null || source.ownerId != ownerId) return null;
    final remap = <String, String>{};
    for (final imageId in revision.imageIds) {
      final bytes = await store.getImage(imageId);
      if (bytes == null) continue;
      final copyId = const Uuid().v4();
      await store.putImage(copyId, bytes);
      remap[imageId] = copyId;
    }
    final now = DateTime.now().toUtc();
    final stamp = revision.createdAt
        .toLocal()
        .toIso8601String()
        .substring(0, 16)
        .replaceFirst('T', ' ');
    final label = revision.title.trim().isEmpty
        ? source.displayTitle
        : revision.title.trim();
    final copy = Note.fresh(ownerId).copyWith(
      title: '$label (version $stamp)',
      delta: remapInlineImages(revision.delta, remap),
      plainText: revision.plainText,
      colorIndex: revision.colorIndex,
      images: [for (final image in revision.images) remap[image] ?? image],
      tags: revision.tags,
      createdAt: now,
      updatedAt: now,
    );
    await store.putNote(copy);
    _replace(copy);
    return copy;
  });

  @override
  Future<void> delete(Note note) => _enqueue(() async {
    final current = noteById(note.id);
    if (current == null || current.ownerId != ownerId) return;
    final now = DateTime.now().toUtc();
    final deleted = current.copyWith(
      deleted: true,
      deletedAt: now,
      updatedAt: now,
      dirty: true,
    );
    await store.putNote(deleted);
    recentlyDeletedId = note.id;
    deletionSerial++;
    _generations[note.id] = (_generations[note.id] ?? 0) + 1;
    _replace(deleted);
  });

  @override
  Future<void> archive(String id, {bool archived = true}) async {
    if (archived) {
      await flushEditor(id);
      await flushDesktopEditor?.call(id);
    }
    await _enqueue(() async {
      final current = noteById(id);
      if (current == null || current.ownerId != ownerId) return;
      final changed = current.copyWith(
        archivedAt: archived ? DateTime.now().toUtc() : null,
        clearArchive: !archived,
        updatedAt: DateTime.now().toUtc(),
        dirty: true,
      );
      await store.putNote(changed);
      _generations[id] = (_generations[id] ?? 0) + 1;
      _replace(changed);
    });
  }

  @override
  Future<void> restore(String id) => _enqueue(() async {
    final current = _byId[id];
    if (current == null || !current.deleted || current.ownerId != ownerId) {
      return;
    }
    final restored = current.copyWith(
      deleted: false,
      updatedAt: DateTime.now().toUtc(),
      dirty: true,
    );
    await store.putNote(restored);
    _generations[id] = (_generations[id] ?? 0) + 1;
    _replace(restored);
  });

  Future<void> purge(String id) => _enqueue(() async {
    final current = _byId[id];
    if (current == null || !current.deleted) return;
    if (current.ownerId != guestOwner) {
      throw StateError(
        'Account Trash keeps sync tombstones. Permanent deletion is available for local notes only.',
      );
    }
    await store.deleteNote(id);
    _notes.removeWhere((note) => note.id == id);
    _index();
    // Retain cached assets: an editor's undo history may still reference them.
    notifyListeners();
  });

  @override
  Future<void> addImage(Note note, Uint8List bytes) async {
    final imageId = await cacheImage(bytes);
    final current = noteById(note.id);
    if (current != null) {
      await save(current.copyWith(images: [...current.images, imageId]));
    }
  }

  @override
  Future<String> cacheImage(Uint8List bytes) async {
    final imageId = const Uuid().v4();
    await store.putImage(imageId, bytes);
    return imageId;
  }

  @override
  Future<void> removeImage(Note note, String imageId) async {
    await save(
      note.copyWith(images: note.images.where((id) => id != imageId).toList()),
    );
  }

  @override
  Future<Uint8List?> image(String noteId, String imageId) async {
    final cached = await store.getImage(imageId);
    if (cached != null) return cached;
    if (!signedIn) return null;
    try {
      final bytes = Uint8List.fromList(
        await CloudSync(client!, store).downloadImage(ownerId, noteId, imageId),
      );
      await store.putImage(imageId, bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> setTheme(ThemeMode value) async {
    themeMode = value;
    await store.setSetting('theme', value.name);
    notifyListeners();
  }

  Future<void> setReduceTransparency(bool value) async {
    await store.setSetting('reduceTransparency', value);
    reduceTransparency = value;
    notifyListeners();
  }

  Future<void> setConfirmDelete(bool value) async {
    confirmDelete = value;
    await store.setSetting('confirmDelete', value);
    notifyListeners();
  }

  Future<void> setCustomWindowButtons(bool value) async {
    await store.setSetting('customWindowButtons', value);
    customWindowButtons = value;
    notifyListeners();
  }

  /// One-time copy of Windows Sticky Notes into new notes. Each Sticky Note is
  /// imported once (its ID is remembered), so running this again only adds
  /// notes created since. Pictures become attached images; the original
  /// Sticky Notes data is never modified.
  Future<StickyImportResult> importStickyNotes(
    StickySource source, {
    void Function(int done, int total)? onProgress,
  }) async {
    final all = await source.notes();
    final pending = [
      for (final sticky in all)
        if (!stickyImported.contains(sticky.id)) sticky,
    ];
    var imported = 0, empty = 0, pictures = 0, failedPictures = 0;
    for (var i = 0; i < pending.length; i++) {
      onProgress?.call(i, pending.length);
      final sticky = pending[i];
      final content = parseStickyText(sticky.text);
      final imageIds = <String>[];
      for (final file in sticky.mediaFiles) {
        try {
          final bytes = await source.media(file);
          if (bytes == null) {
            failedPictures++;
            continue;
          }
          imageIds.add(
            await cacheImage(
              await prepareNoteImage(bytes, quality: imageQuality),
            ),
          );
          pictures++;
        } catch (_) {
          failedPictures++;
        }
      }
      if (content.plainText.trim().isEmpty && imageIds.isEmpty) {
        empty++;
        stickyImported = {...stickyImported, sticky.id};
        continue;
      }
      await _enqueue(() async {
        final now = DateTime.now().toUtc();
        final note = Note.fresh(ownerId).copyWith(
          delta: content.delta,
          plainText: content.plainText,
          colorIndex: stickyColorIndex(sticky.theme),
          images: imageIds,
          tags: ['sticky notes'],
          createdAt: sticky.createdAt ?? sticky.updatedAt ?? now,
          updatedAt: sticky.updatedAt ?? sticky.createdAt ?? now,
        );
        await store.putNote(note);
        _replace(note);
      });
      stickyImported = {...stickyImported, sticky.id};
      imported++;
    }
    await store.setSetting('stickyImported', stickyImported.toList());
    onProgress?.call(pending.length, pending.length);
    return StickyImportResult(
      found: all.length,
      imported: imported,
      alreadyImported: all.length - pending.length,
      empty: empty,
      pictures: pictures,
      failedPictures: failedPictures,
    );
  }

  Future<void> setImageQuality(ImageQuality value) async {
    await store.setSetting('imageQuality', value.name);
    imageQuality = value;
    notifyListeners();
  }

  /// Re-encodes every stored picture with the current quality setting and
  /// returns what would change. Nothing is written until [applyImageShrink].
  Future<ImageShrinkPlan> planImageShrink({
    void Function(int done, int total)? onProgress,
  }) async {
    final ids = await store.imageIds();
    final replacements = <String, Uint8List>{};
    var before = 0;
    var after = 0;
    for (var i = 0; i < ids.length; i++) {
      onProgress?.call(i, ids.length);
      final bytes = await store.getImage(ids[i]);
      if (bytes == null) continue;
      before += bytes.length;
      Uint8List? smaller;
      if (imageQuality != ImageQuality.original && !_isGif(bytes)) {
        smaller = await compute(shrinkRequest, (bytes, imageQuality.index));
      }
      if (smaller != null && smaller.length < bytes.length * 0.9) {
        replacements[ids[i]] = smaller;
        after += smaller.length;
      } else {
        after += bytes.length;
      }
    }
    onProgress?.call(ids.length, ids.length);
    return ImageShrinkPlan(
      total: ids.length,
      before: before,
      after: after,
      replacements: replacements,
    );
  }

  /// Replaces the stored bytes of each picture in [plan]. Cannot be undone.
  Future<void> applyImageShrink(ImageShrinkPlan plan) => _enqueue(() async {
    for (final entry in plan.replacements.entries) {
      await store.putImage(entry.key, entry.value);
    }
  });

  static bool _isGif(Uint8List bytes) =>
      bytes.length > 3 && bytes[0] == 0x47 && bytes[1] == 0x49;

  Future<void> setInlineImages(bool value) async {
    await store.setSetting('inlineImages', value);
    inlineImages = value;
    notifyListeners();
  }

  /// Saves (or replaces, by case-insensitive name) the current search setup.
  Future<void> saveFilter(String name, String query) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final filter = SavedFilter(
      name: trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed,
      query: query.trim(),
      view: libraryView,
      sort: noteSort,
      tags: selectedTags,
    );
    final next = [
      for (final value in savedFilters)
        if (value.name.toLowerCase() != filter.name.toLowerCase()) value,
      filter,
    ];
    await _storeFilters(next);
  }

  Future<void> deleteFilter(String name) => _storeFilters([
    for (final value in savedFilters)
      if (value.name != name) value,
  ]);

  Future<void> _storeFilters(List<SavedFilter> next) async {
    await store.setSetting('savedFilters', [
      for (final value in next) value.toJson(),
    ]);
    savedFilters = List.unmodifiable(next);
    notifyListeners();
  }

  void _scheduleAutoBackup() {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = null;
    if (autoBackupFolder == null || !auto_backup.canAutoBackup) return;
    _autoBackupTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => unawaited(runAutoBackup()),
    );
    // Give startup a moment before the first check.
    unawaited(Future<void>.delayed(const Duration(seconds: 20), runAutoBackup));
  }

  Future<void> setAutoBackupFolder(String? folder) async {
    if (folder == null) {
      await store.deleteSetting('autoBackupFolder');
    } else {
      await store.setSetting('autoBackupFolder', folder);
    }
    autoBackupFolder = folder;
    autoBackupError = null;
    await store.deleteSetting('autoBackupError');
    notifyListeners();
    _scheduleAutoBackup();
  }

  Future<void> setAutoBackupKeep(int keep) async {
    await store.setSetting('autoBackupKeep', keep);
    autoBackupKeep = keep;
    notifyListeners();
  }

  /// Writes a backup to the chosen folder when one is due (or [force]d).
  /// Failures are recorded for the library and Settings to show.
  Future<bool> runAutoBackup({bool force = false}) async {
    final folder = autoBackupFolder;
    if (folder == null || autoBackupRunning || !auto_backup.canAutoBackup) {
      return false;
    }
    final last = autoBackupLast;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < autoBackupInterval) {
      return false;
    }
    autoBackupRunning = true;
    notifyListeners();
    try {
      final bytes = await exportBackup();
      final now = DateTime.now();
      await auto_backup.writeAutoBackup(folder, bytes, now, autoBackupKeep);
      autoBackupLast = now;
      autoBackupError = null;
      await store.setSetting('autoBackupLast', now.toUtc().toIso8601String());
      await store.deleteSetting('autoBackupError');
      return true;
    } catch (error) {
      autoBackupError = 'Automatic backup failed: $error';
      AppLog.write('ERROR', 'Automatic backup failed', error);
      await store.setSetting('autoBackupError', autoBackupError!);
      return false;
    } finally {
      autoBackupRunning = false;
      notifyListeners();
    }
  }

  /// Reminders that are due now and have not been shown yet.
  List<Note> dueReminders([DateTime? now]) {
    final at = (now ?? DateTime.now()).toUtc();
    return [
      for (final note in _notes)
        if (note.ownerId == ownerId && note.reminderDue(at)) note,
    ]..sort((a, b) => a.remindAt!.compareTo(b.remindAt!));
  }

  /// The earliest reminder that has not been shown yet.
  DateTime? get nextReminder {
    DateTime? next;
    for (final note in _notes) {
      if (note.ownerId != ownerId ||
          note.deleted ||
          note.archivedAt != null ||
          !note.reminderPending) {
        continue;
      }
      if (next == null || note.remindAt!.isBefore(next)) next = note.remindAt;
    }
    return next;
  }

  /// Sets, moves (snooze), or clears ([at] null) a note's reminder.
  @override
  Future<void> setReminder(String id, DateTime? at) async {
    await _enqueue(() async {
      final current = noteById(id);
      if (current == null || current.ownerId != ownerId) return;
      final changed = at == null
          ? current.copyWith(clearReminder: true)
          : current.copyWith(remindAt: at.toUtc(), reminderFired: false);
      await store.putNote(changed.copyWith(dirty: current.dirty));
      _replaceQuietly(changed.copyWith(dirty: current.dirty));
    });
    unawaited(_notifyRemindersChanged());
  }

  /// Marks a due reminder as shown so it is not announced twice.
  Future<void> markReminderFired(String id) async {
    await _enqueue(() async {
      final current = noteById(id);
      if (current == null || !current.reminderPending) return;
      final changed = current.copyWith(reminderFired: true);
      await store.putNote(changed);
      _replaceQuietly(changed);
    });
    unawaited(_notifyRemindersChanged());
  }

  Future<void> _notifyRemindersChanged() async {
    try {
      await remindersChanged?.call();
    } catch (error) {
      // The scheduled task is best effort; the in-app check still works.
      AppLog.write('WARN', 'Reminder task update failed', error);
    }
  }

  Future<void> setReminderTaskEnabled(bool value) async {
    final previous = reminderTaskEnabled;
    reminderTaskEnabled = value;
    reminderTaskError = null;
    try {
      await store.setSetting('reminderTask', value);
      await remindersChanged?.call();
    } catch (error) {
      reminderTaskEnabled = previous;
      await store.setSetting('reminderTask', previous);
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setKeepInTray(bool value) async {
    final previous = keepInTray;
    keepInTray = value;
    try {
      await applyTray?.call();
      await store.setSetting('keepInTray', value);
    } catch (_) {
      keepInTray = previous;
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  /// Registers the shortcut first so a conflict leaves the old choice intact.
  Future<void> setQuickCaptureKey(String id) async {
    final previous = quickCaptureKey;
    quickCaptureKey = id;
    try {
      await applyQuickCapture?.call();
      await store.setSetting('quickCaptureKey', id);
      quickCaptureError = null;
    } catch (_) {
      quickCaptureKey = previous;
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setTrashRetentionDays(int days) async {
    await store.setSetting('trashRetentionDays', days);
    trashRetentionDays = days;
    notifyListeners();
    await purgeExpiredTrash();
  }

  /// Permanently removes local-only Trash older than the retention setting.
  /// Account notes keep their sync tombstones and are never touched.
  Future<int> purgeExpiredTrash({DateTime? now}) => _enqueue(() async {
    if (trashRetentionDays <= 0) return 0;
    final cutoff = (now ?? DateTime.now()).toUtc().subtract(
      Duration(days: trashRetentionDays),
    );
    final expired = [
      for (final note in _notes)
        if (note.deleted &&
            note.ownerId == guestOwner &&
            (note.deletedAt ?? note.updatedAt).isBefore(cutoff))
          note.id,
    ];
    for (final id in expired) {
      await store.deleteNote(id);
    }
    if (expired.isNotEmpty) {
      _notes.removeWhere((note) => expired.contains(note.id));
      _index();
      notifyListeners();
    }
    return expired.length;
  });

  /// Bulk actions for the multi-select bar. Each returns the notes changed.
  Future<int> bulkFavorite(Iterable<String> ids, bool favorite) =>
      _bulkSave(ids, (note) => note.copyWith(favorite: favorite));

  Future<int> bulkColor(Iterable<String> ids, int colorIndex) =>
      _bulkSave(ids, (note) => note.copyWith(colorIndex: colorIndex));

  Future<int> bulkAddTags(Iterable<String> ids, Iterable<String> tags) =>
      _bulkSave(ids, (note) => note.copyWith(tags: [...note.tags, ...tags]));

  Future<int> bulkArchive(Iterable<String> ids) async {
    var changed = 0;
    for (final id in ids.toList()) {
      final note = noteById(id);
      if (note == null || note.deleted || note.archivedAt != null) continue;
      await archive(id);
      changed++;
    }
    return changed;
  }

  Future<int> bulkTrash(Iterable<String> ids) async {
    await flushAllEditors();
    var changed = 0;
    for (final id in ids.toList()) {
      final note = noteById(id);
      if (note == null || note.deleted) continue;
      await delete(note);
      changed++;
    }
    return changed;
  }

  Future<int> _bulkSave(
    Iterable<String> ids,
    Note Function(Note) change,
  ) async {
    var changed = 0;
    for (final id in ids.toList()) {
      final note = noteById(id);
      if (note == null || note.deleted || note.archivedAt != null) continue;
      await save(change(note));
      changed++;
    }
    return changed;
  }

  Future<void> setFastNoteOpening(bool value) async {
    await store.setSetting('fastNoteOpening', value);
    fastNoteOpening = value;
    notifyListeners();
    await applyFastNoteOpening?.call();
  }

  Future<void> setAlwaysShowNoteHeader(bool value) async {
    await store.setSetting('alwaysShowNoteHeader', value);
    alwaysShowNoteHeader = value;
    notifyListeners();
  }

  Future<Uint8List> exportBackup() async {
    await flushAllEditors();
    final owner = ownerId;
    return _enqueue(() async {
      if (owner != ownerId) {
        throw StateError('Account changed. Retry exporting.');
      }
      return NoteBackup.export(store, owner);
    });
  }

  Future<void> importBackup(
    BackupData backup, {
    bool restorePreferences = false,
    required String expectedOwner,
  }) async {
    await flushAllEditors();
    await _enqueue(() async {
      if (expectedOwner != ownerId) {
        throw StateError('Account changed. Review the backup again.');
      }
      await backup.importInto(
        store,
        ownerId,
        restorePreferences: restorePreferences,
      );
      await reload();
      if (restorePreferences) {
        final prefs = backup.preferences;
        if (prefs['theme'] case final String theme) {
          themeMode = ThemeMode.values.byName(theme);
        }
        confirmDelete = prefs['confirmDelete'] as bool? ?? confirmDelete;
        reduceTransparency =
            prefs['reduceTransparency'] as bool? ?? reduceTransparency;
        inlineImages = prefs['inlineImages'] as bool? ?? inlineImages;
        customWindowButtons =
            prefs['customWindowButtons'] as bool? ?? customWindowButtons;
        notifyListeners();
      }
      _scheduleSync();
    });
  }

  Future<String> exportText() async {
    await flushAllEditors();
    return [...notes, ...archiveNotes]
        .map(
          (note) =>
              '${note.displayTitle}\n${note.updatedAt.toLocal().toIso8601String()}\n${note.textForExport}',
        )
        .join('\n\n---\n\n');
  }

  void _scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 650), sync);
  }

  Future<void> sync() async {
    if (!signedIn || syncing) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    var succeeded = false;
    try {
      await CloudSync(client!, store).sync(ownerId);
      lastSynced = DateTime.now();
      await _enqueue(reload);
      succeeded = true;
    } catch (error) {
      syncError = error.toString();
      notifyListeners();
    } finally {
      syncing = false;
      notifyListeners();
      if (succeeded && _notes.any((note) => note.dirty)) _scheduleSync();
    }
  }

  Future<void> _handleAuthChange(String? newOwner) async {
    final oldOwner = _lastOwner;
    final nextOwner = newOwner ?? guestOwner;
    if (oldOwner == nextOwner) return;
    _lastOwner = nextOwner;
    if (newOwner != null) {
      await store.moveGuestNotes(newOwner);
    } else if (oldOwner != null && oldOwner != guestOwner) {
      await store.clearOwner(oldOwner);
    }
    await reload();
    if (newOwner != null) unawaited(sync());
  }

  Future<void> signOut() async {
    if (client == null || !signedIn) return;
    await flushAllEditors();
    await sync();
    final dirty = (await store.notesFor(ownerId)).any((note) => note.dirty);
    if (dirty) {
      throw StateError(
        'Unsynced notes remain. Connect to the internet and retry.',
      );
    }
    await client!.auth.signOut();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _autoBackupTimer?.cancel();
    _debounce?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}

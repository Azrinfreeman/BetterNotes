import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/cloud_sync.dart';
import '../data/local_store.dart';
import '../data/note.dart';
import 'note_editor_store.dart';

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
  List<Note> get notes =>
      _notes.where((note) => !note.deleted).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  @override
  Note? noteById(String id) {
    for (final note in _notes) {
      if (note.id == id && !note.deleted) return note;
    }
    return null;
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
  bool inlineImages = false;
  @override
  bool syncing = false;
  String? syncError;
  DateTime? lastSynced;

  Future<void> load() async {
    final theme = await store.getSetting<String>('theme');
    themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    confirmDelete = await store.getSetting<bool>('confirmDelete') ?? true;
    customWindowButtons =
        await store.getSetting<bool>('customWindowButtons') ?? false;
    inlineImages = await store.getSetting<bool>('inlineImages') ?? false;
    _lastOwner = ownerId;
    if (signedIn) await store.moveGuestNotes(ownerId);
    await reload();
    if (signedIn) unawaited(sync());
  }

  Future<void> reload() async {
    _notes = await store.notesFor(ownerId);
    notifyListeners();
  }

  Future<Note> create() async {
    final note = Note.fresh(ownerId);
    await store.putNote(note);
    await reload();
    _scheduleSync();
    return note;
  }

  @override
  Future<void> save(Note note) async {
    if (note.ownerId != ownerId) return;
    final changed = note.copyWith(
      updatedAt: DateTime.now().toUtc(),
      dirty: true,
    );
    await store.putNote(changed);
    final index = _notes.indexWhere((value) => value.id == changed.id);
    if (index < 0) {
      _notes.add(changed);
    } else {
      _notes[index] = changed;
    }
    notifyListeners();
    _scheduleSync();
  }

  @override
  Future<void> delete(Note note) => save(note.copyWith(deleted: true));

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

  Future<void> setInlineImages(bool value) async {
    await store.setSetting('inlineImages', value);
    inlineImages = value;
    notifyListeners();
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
      await reload();
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
    _debounce?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}

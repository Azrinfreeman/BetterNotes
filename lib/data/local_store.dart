import 'dart:convert';
import 'dart:typed_data';

import 'package:sembast/sembast.dart';

import 'local_factory_web.dart'
    if (dart.library.io) 'local_factory_io.dart'
    as local_factory;
import 'note.dart';
import 'revision.dart';

class LocalStore {
  LocalStore._(this.database);
  LocalStore.fromDatabase(this.database);

  final Database database;
  final _notes = stringMapStoreFactory.store('notes');
  final _assets = stringMapStoreFactory.store('assets');
  final _settings = stringMapStoreFactory.store('settings');
  final _revisions = stringMapStoreFactory.store('revisions');

  static bool get canQuarantine => local_factory.canQuarantineLocalDatabase;

  /// Moves an unreadable database aside without deleting it.
  static Future<String?> quarantine() =>
      local_factory.quarantineLocalDatabase();

  static Future<LocalStore> open() async =>
      LocalStore._(await local_factory.openLocalDatabase());

  Future<List<Note>> notesFor(String ownerId) async {
    final records = await _notes.find(
      database,
      finder: Finder(filter: Filter.equals('owner_id', ownerId)),
    );
    return records
        .map((record) => Note.fromJson(Map<String, dynamic>.from(record.value)))
        .toList();
  }

  Future<Note?> noteById(String id) async {
    final value = await _notes.record(id).get(database);
    return value == null
        ? null
        : Note.fromJson(Map<String, dynamic>.from(value));
  }

  Future<void> putNote(Note note) =>
      _notes.record(note.id).put(database, note.toJson());

  Future<void> deleteNote(String id) async {
    await _notes.record(id).delete(database);
    await deleteRevisions(id);
  }

  /// Newest first.
  Future<List<NoteRevision>> revisionsFor(String noteId) async {
    final records = await _revisions.find(
      database,
      finder: Finder(
        filter: Filter.equals('note_id', noteId),
        sortOrders: [SortOrder('created_at', false)],
      ),
    );
    return [for (final record in records) NoteRevision.fromJson(record.value)];
  }

  Future<NoteRevision?> revisionById(String id) async {
    final value = await _revisions.record(id).get(database);
    return value == null ? null : NoteRevision.fromJson(value);
  }

  /// Stores a revision and trims the note's history to [maxRevisionsPerNote].
  Future<void> addRevision(NoteRevision revision) =>
      database.transaction((txn) async {
        await _revisions.record(revision.id).put(txn, revision.toJson());
        final records = await _revisions.find(
          txn,
          finder: Finder(
            filter: Filter.equals('note_id', revision.noteId),
            sortOrders: [SortOrder('created_at', false)],
          ),
        );
        for (final stale in records.skip(maxRevisionsPerNote)) {
          await _revisions.record(stale.key).delete(txn);
        }
      });

  Future<void> deleteRevisions(String noteId) => _revisions.delete(
    database,
    finder: Finder(filter: Filter.equals('note_id', noteId)),
  );

  Future<List<NoteRevision>> allRevisions(Set<String> noteIds) async {
    final records = await _revisions.find(database);
    return [
      for (final record in records)
        if (noteIds.contains(record.value['note_id']))
          NoteRevision.fromJson(record.value),
    ];
  }

  /// Compare and acknowledge in one transaction so an in-flight sync cannot
  /// replace a newer local save between its read and write.
  Future<void> acknowledgeRemote(Note snapshot, Note server) async {
    await database.transaction((txn) async {
      final value = await _notes.record(snapshot.id).get(txn);
      if (value == null) return; // A purged record must not reappear.
      final current = Note.fromJson(Map<String, dynamic>.from(value));
      final changed =
          jsonEncode(current.toJson()) != jsonEncode(snapshot.toJson());
      final acknowledged = changed
          ? current.copyWith(revision: server.revision)
          : server.copyWith(
              deletedAt: current.deletedAt,
              title: current.title,
              favorite: current.favorite,
              tags: current.tags,
              archivedAt: current.archivedAt,
              remindAt: current.remindAt,
              reminderFired: current.reminderFired,
              clearReminder: current.remindAt == null,
            );
      await _notes.record(snapshot.id).put(txn, acknowledged.toJson());
    });
  }

  Future<void> moveGuestNotes(String ownerId) async {
    final guestNotes = await notesFor(guestOwner);
    for (final note in guestNotes) {
      await putNote(note.copyWith(ownerId: ownerId, dirty: true));
    }
  }

  Future<void> clearOwner(String ownerId) async {
    final notes = await notesFor(ownerId);
    for (final note in notes) {
      await _notes.record(note.id).delete(database);
      for (final revision in await revisionsFor(note.id)) {
        for (final imageId in revision.imageIds) {
          await _assets.record(imageId).delete(database);
        }
      }
      await deleteRevisions(note.id);
      for (final imageId in note.images) {
        await _assets.record(imageId).delete(database);
      }
    }
  }

  Future<void> putImage(String imageId, Uint8List bytes) =>
      _assets.record(imageId).put(database, {'base64': base64Encode(bytes)});

  Future<Uint8List?> getImage(String imageId) async {
    final value = await _assets.record(imageId).get(database);
    if (value == null) return null;
    return base64Decode(value['base64'] as String);
  }

  Future<void> deleteImage(String imageId) async {
    await _assets.record(imageId).delete(database);
  }

  Future<void> importCollection(
    List<Note> notes,
    Map<String, Uint8List> assets,
    Map<String, Object> preferences, {
    List<NoteRevision> revisions = const [],
  }) async {
    await database.transaction((txn) async {
      for (final entry in assets.entries) {
        if (await _assets.record(entry.key).exists(txn)) {
          throw StateError('An imported asset ID already exists.');
        }
        await _assets.record(entry.key).put(txn, {
          'base64': base64Encode(entry.value),
        });
      }
      for (final note in notes) {
        if (await _notes.record(note.id).exists(txn)) {
          throw StateError('An imported note ID already exists.');
        }
        await _notes.record(note.id).put(txn, note.toJson());
      }
      for (final revision in revisions) {
        if (await _revisions.record(revision.id).exists(txn)) {
          throw StateError('An imported revision ID already exists.');
        }
        await _revisions.record(revision.id).put(txn, revision.toJson());
      }
      for (final entry in preferences.entries) {
        await _settings.record(entry.key).put(txn, {'value': entry.value});
      }
    });
  }

  Future<void> setSetting(String key, Object value) =>
      _settings.record(key).put(database, {'value': value});

  Future<void> deleteSetting(String key) =>
      _settings.record(key).delete(database);

  Future<T?> getSetting<T>(String key) async {
    final record = await _settings.record(key).get(database);
    return record?['value'] as T?;
  }
}

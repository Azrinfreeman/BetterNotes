import 'dart:convert';
import 'dart:typed_data';

import 'package:sembast/sembast.dart';

import 'local_factory_web.dart'
    if (dart.library.io) 'local_factory_io.dart'
    as local_factory;
import 'note.dart';

class LocalStore {
  LocalStore._(this.database);
  LocalStore.fromDatabase(this.database);

  final Database database;
  final _notes = stringMapStoreFactory.store('notes');
  final _assets = stringMapStoreFactory.store('assets');
  final _settings = stringMapStoreFactory.store('settings');

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
    Map<String, Object> preferences,
  ) async {
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
      for (final entry in preferences.entries) {
        await _settings.record(entry.key).put(txn, {'value': entry.value});
      }
    });
  }

  Future<void> setSetting(String key, Object value) =>
      _settings.record(key).put(database, {'value': value});

  Future<T?> getSetting<T>(String key) async {
    final record = await _settings.record(key).get(database);
    return record?['value'] as T?;
  }
}

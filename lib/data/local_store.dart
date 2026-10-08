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

  Future<void> setSetting(String key, Object value) =>
      _settings.record(key).put(database, {'value': value});

  Future<T?> getSetting<T>(String key) async {
    final record = await _settings.record(key).get(database);
    return record?['value'] as T?;
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:uuid/uuid.dart';

import 'local_store.dart';
import 'backup_limits.dart';
import 'note.dart';
import 'revision.dart';

export 'backup_limits.dart';

const maxBackupNotes = 5000;
const maxBackupAssets = 10000;
const _maxImageBytes = 8 * 1024 * 1024;
const _maxNotesBytes = 16 * 1024 * 1024;
final _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,100}$');

/// Schema 1 is an uncompressed ZIP: manifest.json, notes.json, `assets/<id>`.
/// Version 2 adds `revisions.json` (each note's saved earlier versions).
/// No files are extracted to disk. Every payload has a SHA-256 in the manifest.
class BackupData {
  BackupData(
    this.notes,
    this.assets,
    this.preferences, [
    this.revisions = const [],
  ]);
  final List<Note> notes;
  final List<NoteRevision> revisions;
  final Map<String, Uint8List> assets;
  final Map<String, Object> preferences;
  int get trashCount => notes.where((note) => note.deleted).length;

  Future<void> importInto(
    LocalStore store,
    String ownerId, {
    bool restorePreferences = false,
  }) async {
    final assetIds = {for (final id in assets.keys) id: const Uuid().v4()};
    final noteIds = {for (final note in notes) note.id: const Uuid().v4()};
    final copies = [
      for (final note in notes)
        note.copyWith(
          id: noteIds[note.id],
          ownerId: ownerId,
          images: note.images.map((id) => assetIds[id]!).toList(),
          delta: remapInlineImages(note.delta, assetIds),
          revision: 0,
          dirty: true,
          // Imports are copies: keep only reminders still waiting in the
          // future, so restoring never fires old or duplicate alerts.
          clearReminder:
              !(note.reminderPending && note.remindAt!.isAfter(DateTime.now())),
        ),
    ];
    final perNote = <String, int>{};
    final restored = [
      for (final revision in [
        ...revisions,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
        if ((perNote[revision.noteId] = (perNote[revision.noteId] ?? 0) + 1) <=
            maxRevisionsPerNote)
          NoteRevision(
            id: const Uuid().v4(),
            noteId: noteIds[revision.noteId]!,
            createdAt: revision.createdAt,
            title: revision.title,
            delta: remapInlineImages(revision.delta, assetIds),
            plainText: revision.plainText,
            colorIndex: revision.colorIndex,
            images: [for (final id in revision.images) assetIds[id]!],
            tags: revision.tags,
          ),
    ];
    await store.importCollection(
      copies,
      {for (final entry in assets.entries) assetIds[entry.key]!: entry.value},
      restorePreferences ? preferences : {},
      revisions: restored,
    );
  }
}

class NoteBackup {
  static Future<Uint8List> export(LocalStore store, String ownerId) async {
    final notes = await store.notesFor(ownerId);
    if (notes.length > maxBackupNotes) {
      throw StateError('Backups support up to $maxBackupNotes notes.');
    }
    final entries = <String, Uint8List>{};
    final noteJson = [
      for (final note in notes) {...note.toJson(), 'owner_id': guestOwner},
    ];
    final encodedNotes = Uint8List.fromList(utf8.encode(jsonEncode(noteJson)));
    if (encodedNotes.length > _maxNotesBytes) {
      throw StateError('Note text exceeds the 16 MB backup limit.');
    }
    entries['notes.json'] = encodedNotes;
    var total = encodedNotes.length;
    final references = {
      for (final note in notes) ...note.images,
      for (final note in notes) ...inlineImageIds(note.delta),
    };
    if (references.length > maxBackupAssets) {
      throw StateError('Too many images for one backup.');
    }
    for (final id in references) {
      if (!_idPattern.hasMatch(id)) {
        throw StateError('An image has an invalid ID.');
      }
      final bytes = await store.getImage(id);
      if (bytes == null) {
        throw StateError(
          'An image is missing locally. Open the note to download it, then retry.',
        );
      }
      if (bytes.length > _maxImageBytes) {
        throw StateError('An image exceeds 8 MB.');
      }
      total += bytes.length;
      if (total > maxBackupBytes - 1024 * 1024) {
        throw StateError('Backup exceeds 128 MB.');
      }
      entries['assets/$id'] = bytes;
    }
    final revisions = await _exportableRevisions(store, notes, entries, total);
    if (revisions.isNotEmpty) {
      entries['revisions.json'] = Uint8List.fromList(
        utf8.encode(
          jsonEncode([for (final revision in revisions) revision.toJson()]),
        ),
      );
    }
    final preferences = <String, Object>{};
    for (final key in [
      'theme',
      'reduceTransparency',
      'confirmDelete',
      'inlineImages',
      'customWindowButtons',
    ]) {
      final value = await store.getSetting<Object>(key);
      if (value != null) preferences[key] = value;
    }
    entries['manifest.json'] = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'BetterNotes',
          'version': revisions.isEmpty ? 1 : 2,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'hashes': {
            for (final entry in entries.entries)
              entry.key: sha256.convert(entry.value).toString(),
          },
          'preferences': preferences,
        }),
      ),
    );
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.add(
        ArchiveFile(entry.key, entry.value.length, entry.value)
          ..compression = CompressionType.none,
      );
    }
    final bytes = ZipEncoder().encodeBytes(archive);
    if (bytes.length > maxBackupBytes) {
      throw StateError('Backup exceeds 128 MB.');
    }
    // Do not advertise a successful backup that our importer cannot restore.
    validate(bytes);
    return bytes;
  }

  /// History is auxiliary: a version whose images are unavailable, or that
  /// would push the backup over a limit, is left out rather than failing.
  /// Adds the extra images those versions need to [entries].
  static Future<List<NoteRevision>> _exportableRevisions(
    LocalStore store,
    List<Note> notes,
    Map<String, Uint8List> entries,
    int usedBytes,
  ) async {
    var total = usedBytes;
    final all = await store.allRevisions({for (final note in notes) note.id})
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final kept = <NoteRevision>[];
    var jsonBytes = 0;
    for (final revision in all) {
      final pending = <String, Uint8List>{};
      var usable = revision.imageIds.every(_idPattern.hasMatch);
      for (final id in revision.imageIds) {
        if (!usable || entries.containsKey('assets/$id')) continue;
        final bytes = await store.getImage(id);
        if (bytes == null || bytes.length > _maxImageBytes) {
          usable = false;
        } else {
          pending['assets/$id'] = bytes;
        }
      }
      final size = utf8.encode(jsonEncode(revision.toJson())).length;
      final added = pending.values.fold<int>(0, (n, b) => n + b.length);
      final assetCount = entries.keys
          .where((k) => k.startsWith('assets/'))
          .length;
      if (!usable ||
          jsonBytes + size > _maxNotesBytes ~/ 2 ||
          total + added + size > maxBackupBytes - 2 * 1024 * 1024 ||
          assetCount + pending.length > maxBackupAssets) {
        continue;
      }
      entries.addAll(pending);
      total += added + size;
      jsonBytes += size;
      kept.add(revision);
    }
    return kept;
  }

  static BackupData validate(Uint8List bytes) {
    try {
      return _validate(bytes);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Invalid or truncated BetterNotes backup. Choose a complete exported ZIP.',
      );
    }
  }

  static BackupData _validate(Uint8List bytes) {
    if (bytes.length > maxBackupBytes) {
      throw const FormatException('Backup exceeds 128 MB.');
    }
    final directory = ZipDirectory()..read(InputMemoryStream(bytes));
    if (directory.fileHeaders.length > maxBackupAssets + 3 ||
        directory.fileHeaders.length !=
            directory.totalCentralDirectoryEntries ||
        directory.numberOfThisDisk != 0 ||
        directory.diskWithTheStartOfTheCentralDirectory != 0) {
      throw const FormatException('Invalid backup entry count.');
    }
    final entries = <String, Uint8List>{};
    var total = 0;
    for (final header in directory.fileHeaders) {
      final name = header.filename;
      final asset =
          name.startsWith('assets/') && _idPattern.hasMatch(name.substring(7));
      if ((!asset &&
              name != 'manifest.json' &&
              name != 'notes.json' &&
              name != 'revisions.json') ||
          entries.containsKey(name)) {
        throw const FormatException('Unexpected or duplicate archive path.');
      }
      // Schema 1 uses stored entries. Reject compressed/encrypted content before
      // decoding, so declared sizes cannot hide a decompression bomb.
      final file = header.file;
      if (header.compressionMethod != 0 ||
          header.generalPurposeBitFlag & 1 != 0 ||
          header.compressedSize != header.uncompressedSize ||
          file == null ||
          file.flags & 1 != 0 ||
          file.compressionMethod != CompressionType.none ||
          file.filename != name ||
          (header.externalFileAttributes >> 16) & 0xf000 == 0xa000) {
        throw const FormatException(
          'Unsupported compressed, encrypted, or linked backup entry.',
        );
      }
      final limit = asset
          ? _maxImageBytes
          : name == 'manifest.json'
          ? 2 * 1024 * 1024
          : _maxNotesBytes;
      total += header.uncompressedSize;
      if (header.uncompressedSize > limit || total > maxBackupBytes) {
        throw const FormatException('Backup entry exceeds its size limit.');
      }
      final content = file.getStream().toUint8List();
      if (content.length != header.uncompressedSize ||
          getCrc32(content) != header.crc32) {
        throw const FormatException('Backup integrity check failed.');
      }
      entries[name] = content;
    }
    final manifestBytes = entries.remove('manifest.json');
    if (manifestBytes == null) {
      throw const FormatException('Backup manifest is missing.');
    }
    final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map;
    final version = manifest['version'];
    if (manifest['format'] != 'BetterNotes' ||
        (version != 1 && version != 2) ||
        (version == 1 && entries.containsKey('revisions.json'))) {
      throw const FormatException('Unsupported backup version.');
    }
    final hashes = manifest['hashes'] as Map;
    if (hashes.length != entries.length) {
      throw const FormatException('Backup manifest does not match its files.');
    }
    for (final entry in entries.entries) {
      if (hashes[entry.key] != sha256.convert(entry.value).toString()) {
        throw const FormatException('Backup SHA-256 check failed.');
      }
    }
    final preferences = _preferences(manifest['preferences'] as Map? ?? {});
    final rawNotes =
        jsonDecode(utf8.decode(entries.remove('notes.json')!)) as List;
    if (rawNotes.length > maxBackupNotes) {
      throw const FormatException('Too many notes in backup.');
    }
    final revisionBytes = entries.remove('revisions.json');
    final assets = {
      for (final entry in entries.entries) entry.key.substring(7): entry.value,
    };
    final ids = <String>{};
    final notes = <Note>[];
    for (final raw in rawNotes) {
      final json = Map<String, dynamic>.from(raw as Map);
      if ((json['title'] != null && json['title'] is! String) ||
          (json['favorite'] != null && json['favorite'] is! bool) ||
          (json['tags'] != null &&
              (json['tags'] is! List ||
                  (json['tags'] as List).any((tag) => tag is! String))) ||
          (json['archived_at'] != null &&
              (json['archived_at'] is! String ||
                  DateTime.tryParse(json['archived_at'] as String) == null)) ||
          (json['remind_at'] != null &&
              (json['remind_at'] is! String ||
                  DateTime.tryParse(json['remind_at'] as String) == null)) ||
          (json['reminder_fired'] != null && json['reminder_fired'] is! bool)) {
        throw const FormatException('Invalid organization metadata.');
      }
      final id = json['id'] as String;
      if (!_idPattern.hasMatch(id) || !ids.add(id)) {
        throw const FormatException('Invalid or duplicate note ID.');
      }
      if (json['plain_text'] is! String ||
          json['color_index'] is! int ||
          json['revision'] is! int ||
          json['deleted'] is! bool ||
          json['dirty'] is! bool ||
          json['images'] is! List ||
          json['strokes'] is! List ||
          (json['deleted_at'] != null &&
              DateTime.tryParse(json['deleted_at'] as String) == null)) {
        throw const FormatException('Invalid note fields.');
      }
      final delta = json['content'] as List;
      _checkDelta(delta);
      final note = Note.fromJson({...json, 'owner_id': guestOwner});
      if (note.colorIndex < 0 ||
          note.images.toSet().length != note.images.length ||
          note.images.length > maxBackupAssets ||
          note.strokes.length > 10000) {
        throw const FormatException('Invalid note content.');
      }
      if (!note.images.toSet().containsAll(inlineImageIds(delta))) {
        throw const FormatException(
          'An inline image is missing from its note.',
        );
      }
      for (final imageId in note.images) {
        if (!assets.containsKey(imageId)) {
          throw const FormatException('An image is missing from the backup.');
        }
      }
      var points = 0;
      for (final stroke in note.strokes) {
        points += stroke.points.length;
        if (points > 1000000 ||
            stroke.points.any(
              (point) =>
                  point.length != 2 || point.any((value) => !value.isFinite),
            )) {
          throw const FormatException('Invalid drawing data.');
        }
      }
      notes.add(note);
    }
    final revisions = _revisions(revisionBytes, ids, assets);
    return BackupData(notes, assets, preferences, revisions);
  }

  static void _checkDelta(List delta) {
    if (delta.isEmpty || delta.length > 100000) {
      throw const FormatException('Invalid rich-text document.');
    }
    for (final rawOp in delta) {
      final op = rawOp as Map;
      final insert = op['insert'];
      if (op.keys.any((key) => key != 'insert' && key != 'attributes') ||
          (insert is! String &&
              !(insert is Map &&
                  insert.length == 1 &&
                  insert['image'] is String))) {
        throw const FormatException('Unsupported rich-text operation.');
      }
      final attrs = op['attributes'];
      if (attrs != null &&
          (attrs is! Map ||
              attrs.entries.any(
                (entry) =>
                    entry.key is! String ||
                    !(entry.value is String ||
                        entry.value is num ||
                        entry.value is bool ||
                        entry.value == null),
              ))) {
        throw const FormatException('Invalid rich-text attributes.');
      }
    }
    if (delta.last['insert'] is! String ||
        !(delta.last['insert'] as String).endsWith('\n')) {
      throw const FormatException('A note is missing its final paragraph.');
    }
    quill.Document.fromJson(delta);
  }

  static List<NoteRevision> _revisions(
    Uint8List? bytes,
    Set<String> noteIds,
    Map<String, Uint8List> assets,
  ) {
    if (bytes == null) return const [];
    final raw = jsonDecode(utf8.decode(bytes)) as List;
    if (raw.length > maxBackupNotes * maxRevisionsPerNote) {
      throw const FormatException('Too many saved versions in backup.');
    }
    final seen = <String>{};
    final perNote = <String, int>{};
    final result = <NoteRevision>[];
    for (final value in raw) {
      final json = Map<String, dynamic>.from(value as Map);
      if (json['content'] is! List ||
          json['plain_text'] is! String ||
          json['color_index'] is! int ||
          json['images'] is! List ||
          json['tags'] is! List ||
          (json['images'] as List).any((id) => id is! String) ||
          (json['tags'] as List).any((tag) => tag is! String)) {
        throw const FormatException('Invalid saved version fields.');
      }
      final revision = NoteRevision.fromJson(json);
      if (!_idPattern.hasMatch(revision.id) ||
          !seen.add(revision.id) ||
          !noteIds.contains(revision.noteId) ||
          revision.colorIndex < 0 ||
          revision.images.toSet().length != revision.images.length ||
          (perNote[revision.noteId] = (perNote[revision.noteId] ?? 0) + 1) >
              maxRevisionsPerNote) {
        throw const FormatException('Invalid or duplicate saved version.');
      }
      _checkDelta(revision.delta);
      if (!revision.images.toSet().containsAll(
            inlineImageIds(revision.delta),
          ) ||
          !revision.imageIds.every(assets.containsKey)) {
        throw const FormatException('A saved version is missing an image.');
      }
      result.add(revision);
    }
    return result;
  }

  static Map<String, Object> _preferences(Map raw) {
    final result = <String, Object>{};
    for (final entry in raw.entries) {
      if (entry.key == 'theme' &&
          ['light', 'dark', 'system'].contains(entry.value)) {
        result['theme'] = entry.value as String;
      } else if ([
            'confirmDelete',
            'inlineImages',
            'reduceTransparency',
            'customWindowButtons',
          ].contains(entry.key) &&
          entry.value is bool) {
        result[entry.key as String] = entry.value as bool;
      } else {
        throw const FormatException('Unsupported backup preference.');
      }
    }
    return result;
  }
}

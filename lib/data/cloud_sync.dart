import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'local_store.dart';
import 'note.dart';

class CloudSync {
  CloudSync(this.client, this.store);

  final SupabaseClient client;
  final LocalStore store;

  Future<void> sync(String ownerId) async {
    final remoteRows = await client
        .from('notes')
        .select()
        .eq('owner_id', ownerId);
    final remote = <String, Note>{
      for (final row in remoteRows)
        row['id'] as String: Note.fromJson(Map<String, dynamic>.from(row)),
    };
    final localNotes = await store.notesFor(ownerId);

    for (final local in localNotes) {
      final server = remote.remove(local.id);
      if (server != null && local.dirty && local.revision != server.revision) {
        if (local.deleted) {
          await _saveAcknowledged(
            local,
            local.copyWith(revision: server.revision),
          );
          continue;
        }
        final copiedImages = <String>[];
        final imageIds = <String, String>{};
        for (final imageId in local.images) {
          final bytes =
              await store.getImage(imageId) ??
              await downloadImage(ownerId, local.id, imageId);
          final copyId = const Uuid().v4();
          await store.putImage(copyId, Uint8List.fromList(bytes));
          copiedImages.add(copyId);
          imageIds[imageId] = copyId;
        }
        final conflict = Note.fresh(ownerId).copyWith(
          delta: [
            {'insert': 'Conflict copy\n'},
            ...remapInlineImages(local.delta, imageIds),
          ],
          plainText: 'Conflict copy\n${local.plainText}',
          colorIndex: local.colorIndex,
          images: copiedImages,
          strokes: local.strokes,
        );
        await store.putNote(conflict);
        await _saveAcknowledged(local, server);
        continue;
      }
      if (server != null && !local.dirty) {
        if (server.revision > local.revision) {
          await _saveAcknowledged(local, server);
        }
        continue;
      }
      if (!local.dirty) continue;

      final oldImages = server?.images ?? const <String>[];
      for (final imageId in local.images) {
        if (oldImages.contains(imageId)) continue;
        final bytes = await store.getImage(imageId);
        if (bytes == null) throw StateError('An image is missing locally.');
        await client.storage
            .from('note-assets')
            .uploadBinary(
              '$ownerId/${local.id}/$imageId',
              bytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: imageMime(bytes),
              ),
            );
      }

      final next = local.copyWith(revision: local.revision + 1);
      if (server == null) {
        final saved = await client
            .from('notes')
            .insert(next.toRemoteJson())
            .select()
            .single();
        await _saveAcknowledged(
          local,
          Note.fromJson(Map<String, dynamic>.from(saved)),
        );
      } else {
        final rows = await client
            .from('notes')
            .update(next.toRemoteJson())
            .eq('id', local.id)
            .eq('revision', local.revision)
            .select();
        if (rows.isEmpty) {
          // Another device edited the row while this request was in flight.
          continue;
        }
        await _saveAcknowledged(
          local,
          Note.fromJson(Map<String, dynamic>.from(rows.first)),
        );
      }

      for (final removed in oldImages.where(
        (id) => !local.images.contains(id),
      )) {
        await client.storage.from('note-assets').remove([
          '$ownerId/${local.id}/$removed',
        ]);
        // Keep the local bytes available to an open editor's undo/redo history.
      }
      if (local.deleted) {
        for (final imageId in local.images) {
          await client.storage.from('note-assets').remove([
            '$ownerId/${local.id}/$imageId',
          ]);
          await store.deleteImage(imageId);
        }
      }
    }

    for (final incoming in remote.values) {
      await store.putNote(incoming);
    }
  }

  Future<List<int>> downloadImage(
    String ownerId,
    String noteId,
    String imageId,
  ) => client.storage.from('note-assets').download('$ownerId/$noteId/$imageId');

  Future<void> _saveAcknowledged(Note snapshot, Note server) async {
    final current = await store.noteById(snapshot.id);
    if (current == null) {
      await store.putNote(server);
      return;
    }
    if (jsonEncode(current.toJson()) != jsonEncode(snapshot.toJson())) {
      await store.putNote(current.copyWith(revision: server.revision));
      return;
    }
    await store.putNote(server);
  }
}

String imageMime(List<int> bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8) {
    return 'image/jpeg';
  }
  if (bytes.length >= 6 && String.fromCharCodes(bytes.take(3)) == 'GIF') {
    return 'image/gif';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    return 'image/webp';
  }
  throw StateError('Unsupported image format. Use PNG, JPEG, GIF, or WebP.');
}

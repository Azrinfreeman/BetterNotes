import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'sticky_import.dart';

const _packageFolder = 'Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe';

/// The Sticky Notes data folder (`LocalState`) for the current user, or null
/// when the app has never been used or this is not Windows.
Directory? stickyNotesFolder() {
  if (!Platform.isWindows) return null;
  final base = Platform.environment['LOCALAPPDATA'];
  if (base == null) return null;
  final folder = Directory('$base\\Packages\\$_packageFolder\\LocalState');
  return File('${folder.path}\\plum.sqlite').existsSync() ? folder : null;
}

/// Reads Windows Sticky Notes without touching its files: the database (and
/// its write-ahead log) are copied to a temporary folder, opened read-only
/// through Windows' own `winsqlite3.dll`, and the copy is deleted on [close].
class StickyNotesReader implements StickySource {
  StickyNotesReader._(this._folder, this._temp, this._db, this._api);

  final Directory _folder;
  final Directory _temp;
  final Pointer<Void> _db;
  final _Sqlite _api;

  static Future<StickyNotesReader> open([Directory? folder]) async {
    final source = folder ?? stickyNotesFolder();
    if (source == null) {
      throw StateError('Windows Sticky Notes data was not found.');
    }
    final temp = await Directory.systemTemp.createTemp('bn-sticky-');
    try {
      for (final name in [
        'plum.sqlite',
        'plum.sqlite-wal',
        'plum.sqlite-shm',
      ]) {
        final file = File('${source.path}\\$name');
        if (await file.exists()) {
          await file.copy('${temp.path}\\$name');
        }
      }
      final api = _Sqlite.load();
      final db = api.open('${temp.path}\\plum.sqlite');
      return StickyNotesReader._(source, temp, db, api);
    } catch (_) {
      await temp.delete(recursive: true);
      rethrow;
    }
  }

  @override
  Future<List<StickyNote>> notes() async {
    final media = <String, List<String>>{};
    for (final row in _api.query(
      _db,
      'select ParentId, LocalFileRelativePath from Media '
      'where (IsOrphaned is null or IsOrphaned = 0) and DeletedAt is null '
      'order by CreatedAt',
    )) {
      final parent = row[0] as String?;
      final path = row[1] as String?;
      if (parent == null || path == null) continue;
      media
          .putIfAbsent(parent, () => [])
          .add(path.split(RegExp(r'[\\/]')).last);
    }
    return [
      for (final row in _api.query(
        _db,
        'select Id, Text, Theme, CreatedAt, UpdatedAt from Note '
        'where DeletedAt is null order by CreatedAt',
      ))
        StickyNote(
          id: row[0] as String,
          text: (row[1] as String?) ?? '',
          theme: (row[2] as String?) ?? 'Yellow',
          createdAt: stickyTimeFromTicks(row[3] as int?),
          updatedAt: stickyTimeFromTicks(row[4] as int?),
          mediaFiles: media[row[0] as String] ?? const [],
        ),
    ];
  }

  @override
  Future<Uint8List?> media(String fileName) async {
    final safe = fileName.split(RegExp(r'[\\/]')).last;
    final file = File('${_folder.path}\\media\\$safe');
    return await file.exists() ? file.readAsBytes() : null;
  }

  Future<void> close() async {
    _api.close(_db);
    try {
      await _temp.delete(recursive: true);
    } catch (_) {
      // The OS removes the temp folder eventually.
    }
  }
}

typedef _OpenC = Int32 Function(
  Pointer<Utf8>,
  Pointer<Pointer<Void>>,
  Int32,
  Pointer<Utf8>,
);
typedef _OpenD = int Function(
  Pointer<Utf8>,
  Pointer<Pointer<Void>>,
  int,
  Pointer<Utf8>,
);
typedef _CloseC = Int32 Function(Pointer<Void>);
typedef _CloseD = int Function(Pointer<Void>);
typedef _PrepareC = Int32 Function(
  Pointer<Void>,
  Pointer<Utf8>,
  Int32,
  Pointer<Pointer<Void>>,
  Pointer<Pointer<Utf8>>,
);
typedef _PrepareD = int Function(
  Pointer<Void>,
  Pointer<Utf8>,
  int,
  Pointer<Pointer<Void>>,
  Pointer<Pointer<Utf8>>,
);
typedef _StepC = Int32 Function(Pointer<Void>);
typedef _StepD = int Function(Pointer<Void>);
typedef _ColTypeC = Int32 Function(Pointer<Void>, Int32);
typedef _ColTypeD = int Function(Pointer<Void>, int);
typedef _ColTextC = Pointer<Utf8> Function(Pointer<Void>, Int32);
typedef _ColTextD = Pointer<Utf8> Function(Pointer<Void>, int);
typedef _ColIntC = Int64 Function(Pointer<Void>, Int32);
typedef _ColIntD = int Function(Pointer<Void>, int);
typedef _ErrC = Pointer<Utf8> Function(Pointer<Void>);
typedef _ErrD = Pointer<Utf8> Function(Pointer<Void>);

class _Sqlite {
  _Sqlite(DynamicLibrary lib)
    : _open = lib.lookupFunction<_OpenC, _OpenD>('sqlite3_open_v2'),
      _close = lib.lookupFunction<_CloseC, _CloseD>('sqlite3_close'),
      _prepare = lib.lookupFunction<_PrepareC, _PrepareD>('sqlite3_prepare_v2'),
      _step = lib.lookupFunction<_StepC, _StepD>('sqlite3_step'),
      _finalize = lib.lookupFunction<_CloseC, _CloseD>('sqlite3_finalize'),
      _columnType = lib.lookupFunction<_ColTypeC, _ColTypeD>(
        'sqlite3_column_type',
      ),
      _columnText = lib.lookupFunction<_ColTextC, _ColTextD>(
        'sqlite3_column_text',
      ),
      _columnInt = lib.lookupFunction<_ColIntC, _ColIntD>(
        'sqlite3_column_int64',
      ),
      _errmsg = lib.lookupFunction<_ErrC, _ErrD>('sqlite3_errmsg');

  final _OpenD _open;
  final _CloseD _close;
  final _PrepareD _prepare;
  final _StepD _step;
  final _CloseD _finalize;
  final _ColTypeD _columnType;
  final _ColTextD _columnText;
  final _ColIntD _columnInt;
  final _ErrD _errmsg;

  static _Sqlite load() => _Sqlite(DynamicLibrary.open('winsqlite3.dll'));

  static const _readonly = 1;

  Pointer<Void> open(String path) {
    final pathPointer = path.toNativeUtf8();
    final out = calloc<Pointer<Void>>();
    try {
      final code = _open(pathPointer, out, _readonly, nullptr);
      final db = out.value;
      if (code != 0) {
        final message = db == nullptr
            ? 'code $code'
            : _errmsg(db).toDartString();
        if (db != nullptr) _close(db);
        throw StateError(
          'Could not open the Sticky Notes database ($message).',
        );
      }
      return db;
    } finally {
      calloc.free(pathPointer);
      calloc.free(out);
    }
  }

  void close(Pointer<Void> db) => _close(db);

  /// Runs a read-only query; text columns become [String], integers [int],
  /// everything else (including NULL) null.
  List<List<Object?>> query(Pointer<Void> db, String sql) {
    final sqlPointer = sql.toNativeUtf8();
    final statementOut = calloc<Pointer<Void>>();
    try {
      final code = _prepare(db, sqlPointer, -1, statementOut, nullptr);
      if (code != 0) {
        throw StateError(
          'Sticky Notes query failed: ${_errmsg(db).toDartString()}',
        );
      }
      final statement = statementOut.value;
      final rows = <List<Object?>>[];
      try {
        while (_step(statement) == 100) {
          final row = <Object?>[];
          for (var column = 0; column < 8; column++) {
            final type = _columnType(statement, column);
            // 1 integer, 3 text, 5 NULL; columns past the end read as NULL.
            row.add(switch (type) {
              1 => _columnInt(statement, column),
              3 => _columnText(statement, column).toDartString(),
              _ => null,
            });
          }
          rows.add(row);
        }
      } finally {
        _finalize(statement);
      }
      return rows;
    } finally {
      calloc.free(sqlPointer);
      calloc.free(statementOut);
    }
  }
}

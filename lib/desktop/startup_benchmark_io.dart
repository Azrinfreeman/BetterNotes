import 'dart:convert';
import 'dart:io';

/// Explicit diagnostic output only; normal launches never write this file.
Future<void> writeStartupBenchmark(String path, Map<String, Object> data) =>
    File(path).writeAsString(jsonEncode(data));

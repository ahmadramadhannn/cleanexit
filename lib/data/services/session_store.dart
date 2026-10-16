import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';

/// Persists one JSON file per session under the app-support directory.
class SessionStore {
  final String baseDir;

  SessionStore(this.baseDir);

  File _file(String id) => File(p.join(baseDir, '$id.json'));

  Future<void> save(SessionRecord record) async {
    await Directory(baseDir).create(recursive: true);
    final target = _file(record.id);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(record.toJson()),
    );
    if (target.existsSync()) target.deleteSync();
    await tmp.rename(target.path);
  }

  List<SessionRecord> listAll() {
    final dir = Directory(baseDir);
    if (!dir.existsSync()) return const [];
    final out = <SessionRecord>[];
    for (final e in dir.listSync()) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      try {
        out.add(
          SessionRecord.fromJson(
            jsonDecode(e.readAsStringSync()) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // Corrupt record — skip it rather than break the whole list.
      }
    }
    out.sort((a, b) => b.start.compareTo(a.start));
    return out;
  }

  SessionRecord? byId(String id) {
    final f = _file(id);
    if (!f.existsSync()) return null;
    try {
      return SessionRecord.fromJson(
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String id) async {
    final f = _file(id);
    if (f.existsSync()) await f.delete();
  }
}

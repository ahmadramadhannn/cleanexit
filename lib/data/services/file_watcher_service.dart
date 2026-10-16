import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import '../../core/constants.dart';
import '../models/models.dart';

enum WatchKind { create, modify, delete, move }

class WatchEvent {
  final String path;
  final DateTime at;
  final WatchKind kind;
  const WatchEvent(this.path, this.at, this.kind);
}

/// Live watcher for workflow #1: records filesystem events while the session
/// timer runs, then aggregates them into a keep/clean review list.
class FileWatcherService {
  final List<StreamSubscription<FileSystemEvent>> _fsSubs = [];
  final StreamController<WatchEvent> _controller =
      StreamController<WatchEvent>.broadcast();

  /// path -> aggregate state
  final Map<String, _WatchedPath> _events = {};
  Set<String> _excludePrefixes = {};
  List<ManagedRoot> _roots = const [];

  bool get isRunning => _fsSubs.isNotEmpty;
  int get touchedCount => _events.length;

  Stream<WatchEvent> get stream => _controller.stream;

  void start(
    List<ManagedRoot> roots, {
    Set<String> excludePrefixes = const {},
  }) {
    stopSync();
    _roots = roots;
    _excludePrefixes = excludePrefixes;
    _events.clear();

    for (final root in roots) {
      final dir = Directory(root.path);
      if (!dir.existsSync()) continue;
      try {
        dir.watch(events: FileSystemEvent.all).listen(
              (e) => _handleFsEvent(e, root),
              onError: (Object _) {}, // inotify limit etc. — keep others alive
              cancelOnError: false,
            );
      } catch (_) {
        // Directory disappeared between existsSync and watch.
      }
    }
  }

  void _handleFsEvent(FileSystemEvent e, ManagedRoot root) {
    final path = e.path;
    if (path.isEmpty) return;
    final now = DateTime.now();
    if (e.type == FileSystemEvent.create) {
      _record(path, now, WatchKind.create);
    } else if (e.type == FileSystemEvent.modify) {
      _record(path, now, WatchKind.modify);
    } else if (e.type == FileSystemEvent.delete) {
      _record(path, now, WatchKind.delete);
    } else if (e.type == FileSystemEvent.move) {
      _record(path, now, WatchKind.move);
      final dest = (e as dynamic).destination as String?;
      if (dest != null && dest.isNotEmpty) {
        _record(dest, now, WatchKind.create);
      }
    } else {
      _record(path, now, WatchKind.modify);
    }
  }

  void _record(String path, DateTime at, WatchKind kind) {
    if (_isExcluded(path)) return;
    final segs = p.split(path);
    if (segs.any((s) => CeConstants.skipDirNames.contains(s.toLowerCase()))) {
      return;
    }
    final state = _events.putIfAbsent(path, () => _WatchedPath());
    state.firstAt ??= at;
    state.lastAt = at;
    if (kind == WatchKind.create) state.sawCreate = true;
    if (kind == WatchKind.modify) state.sawModify = true;
    state.eventCount++;
    _controller.add(WatchEvent(path, at, kind));
  }

  bool _isExcluded(String path) {
    final norm = _norm(path);
    for (final ex in _excludePrefixes) {
      final exNorm = _norm(ex);
      if (norm == exNorm || norm.startsWith('$exNorm/')) return true;
    }
    return false;
  }

  /// Aggregates recorded events into reviewable [TrackedFile]s, newest first.
  /// Only entities that still exist are listed — short-lived temp files that
  /// got deleted again are already gone and need no cleanup.
  List<TrackedFile> snapshot() {
    final out = <TrackedFile>[];
    for (final entry in _events.entries) {
      final path = entry.key;
      final st = entry.value;

      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type == FileSystemEntityType.link) continue;
      final isDir = type == FileSystemEntityType.directory;

      var size = 0;
      var modified = st.lastAt;
      var created = st.firstAt ?? st.lastAt;
      try {
        final stat = FileStat.statSync(path);
        size = stat.size;
        if (!isDir) modified = stat.modified;
        if (Platform.isWindows) created = stat.changed;
      } catch (_) {}

      ManagedRoot? matchedRoot;
      for (final r in _roots) {
        if (_norm(path).startsWith('${_norm(r.path)}/')) {
          matchedRoot = r;
          break;
        }
      }

      FileOrigin origin;
      if (matchedRoot != null &&
          _norm(matchedRoot.path) == _norm(CeConstants.downloadsDir)) {
        origin = FileOrigin.downloaded;
      } else if (st.sawCreate) {
        origin = FileOrigin.created;
      } else {
        origin = FileOrigin.watched;
      }

      out.add(TrackedFile(
        path: path,
        name: p.basename(path),
        isDir: isDir,
        sizeBytes: size,
        modified: modified,
        created: created,
        rootLabel: matchedRoot?.label ?? 'Watched',
        origin: origin,
      ));
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  Future<void> stop() async {
    for (final s in List.of(_fsSubs)) {
      await s.cancel();
    }
    _fsSubs.clear();
  }

  /// Synchronous best-effort stop for teardown paths.
  void stopSync() {
    for (final s in _fsSubs) {
      s.cancel();
    }
    _fsSubs.clear();
  }

  void dispose() {
    stopSync();
    _controller.close();
  }

  static String _norm(String path) =>
      p.normalize(path).replaceAll('\\', '/').toLowerCase();
}

class _WatchedPath {
  DateTime? firstAt;
  DateTime? lastAt;
  bool sawCreate = false;
  bool sawModify = false;
  int eventCount = 0;
}

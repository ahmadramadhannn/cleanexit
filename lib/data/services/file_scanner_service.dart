import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../models/models.dart';
import 'scan_logic.dart';

class ScanProgress {
  final int scanned;
  final int found;
  final String currentPath;
  const ScanProgress(this.scanned, this.found, this.currentPath);
}

/// Retroactive scanner: walks the managed roots and returns every file whose
/// modified (or, on Windows, created) timestamp falls inside the session
/// range. Runs in a background isolate so the UI stays responsive.
class FileScannerService {
  Future<List<TrackedFile>> scan({
    required DateTime start,
    required DateTime end,
    required List<ManagedRoot> roots,
    Set<String> excludePrefixes = const {},
    void Function(ScanProgress progress)? onProgress,
  }) async {
    final active =
        roots.where((r) => Directory(r.path).existsSync()).toList();
    if (active.isEmpty) return const [];

    final port = ReceivePort();
    final errors = ReceivePort();
    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(
        _scanIsolateMain,
        _ScanRequest(
          paths: active.map((r) => r.path).toList(),
          labels: active.map((r) => r.label).toList(),
          startMs: start.millisecondsSinceEpoch,
          endMs: end.millisecondsSinceEpoch,
          excludes: excludePrefixes.toList(),
          port: port.sendPort,
        ),
        onError: errors.sendPort,
        errorsAreFatal: true,
      );

      final resultCompleter = Completer<List<TrackedFile>>();
      late StreamSubscription sub;
      late StreamSubscription errSub;

      errSub = errors.listen((msg) {
        if (!resultCompleter.isCompleted) {
          resultCompleter.completeError(
            StateError('Scanner isolate failed: $msg'),
          );
        }
      });

      sub = port.listen((msg) {
        if (msg is _ScanProgressMsg) {
          onProgress?.call(
            ScanProgress(msg.scanned, msg.found, msg.currentPath),
          );
        } else if (msg is List) {
          final files =
              msg.cast<Map>().map((m) => TrackedFile.fromJson(Map<String, dynamic>.from(m))).toList();
          files.sort((a, b) => b.modified.compareTo(a.modified));
          if (!resultCompleter.isCompleted) resultCompleter.complete(files);
          sub.cancel();
          errSub.cancel();
        }
      });

      return await resultCompleter.future;
    } finally {
      isolate?.kill(priority: Isolate.immediate);
      port.close();
      errors.close();
    }
  }
}

class _ScanRequest {
  final List<String> paths;
  final List<String> labels;
  final int startMs;
  final int endMs;
  final List<String> excludes;
  final SendPort port;
  const _ScanRequest({
    required this.paths,
    required this.labels,
    required this.startMs,
    required this.endMs,
    required this.excludes,
    required this.port,
  });
}

class _ScanProgressMsg {
  final int scanned;
  final int found;
  final String currentPath;
  const _ScanProgressMsg(this.scanned, this.found, this.currentPath);
}

/// Serialized TrackedFile — isolate-safe (plain JSON map).
typedef _FileMap = Map<String, dynamic>;

Future<void> _scanIsolateMain(_ScanRequest req) async {
  final start = DateTime.fromMillisecondsSinceEpoch(req.startMs);
  final end = DateTime.fromMillisecondsSinceEpoch(req.endMs);
  final results = <_FileMap>[];
  final creationKnown = ScanLogic.creationTimeKnown();

  var scanned = 0;
  var lastReport = 0;

  void report(String current) {
    // Throttle cross-isolate chatter.
    if (scanned - lastReport >= 250) {
      lastReport = scanned;
      req.port.send(_ScanProgressMsg(scanned, results.length, current));
    }
  }

  for (var i = 0; i < req.paths.length; i++) {
    final rootPath = req.paths[i];
    final rootLabel = req.labels[i];
    final rootNorm = _normalize(rootPath);
    final isDownloads =
        rootNorm == _normalize(CeConstants.downloadsDir);

    await _walk(
      Directory(rootPath),
      depth: 0,
      onEntity: (entity) {
        scanned++;
        if (entity is! File) return;
        final path = entity.path;
        if (_isExcluded(path, req.excludes)) return;
        final name = p.basename(path);
        if (_shouldSkipName(name)) return;

        final FileStat stat;
        try {
          stat = entity.statSync();
        } catch (_) {
          return; // vanished mid-scan or permission denied
        }

        if (!ScanLogic.fileBelongsToRange(
          stat: stat,
          start: start,
          end: end,
        )) {
          return;
        }

        final modified = stat.modified;
        final created =
            creationKnown ? stat.changed : stat.modified;
        final createdInRange = ScanLogic.isWithinRange(start, end, created);

        final origin = ScanLogic.classifyOrigin(
          isUnderDownloadsRoot: isDownloads ||
              _isUnderDownloads(path),
          createdInRange: createdInRange,
          creationKnown: creationKnown,
        );

        results.add(
          TrackedFile(
            path: path,
            name: name,
            isDir: false,
            sizeBytes: stat.size,
            modified: modified,
            created: created,
            rootLabel: rootLabel,
            origin: origin,
          ).toJson(),
        );
        report(path);
      },
    );
    report(rootPath);
  }

  req.port.send(results);
}

bool _isUnderDownloads(String path) =>
    _normalize(path).startsWith('${_normalize(CeConstants.downloadsDir)}/');

String _normalize(String path) =>
    p.normalize(path).replaceAll('\\', '/').toLowerCase();

bool _isExcluded(String path, List<String> excludes) {
  final norm = _normalize(path);
  for (final ex in excludes) {
    final exNorm = _normalize(ex);
    if (norm == exNorm || norm.startsWith('$exNorm/')) return true;
  }
  return false;
}

bool _shouldSkipName(String name) =>
    CeConstants.skipDirNames.contains(name.toLowerCase());

Future<void> _walk(
  Directory dir, {
  required int depth,
  required void Function(FileSystemEntity entity) onEntity,
}) async {
  if (depth > CeConstants.maxScanDepth) return;
  final List<FileSystemEntity> children;
  try {
    children = dir.listSync(followLinks: false);
  } catch (_) {
    return; // permission denied etc.
  }
  for (final entity in children) {
    final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
    if (type == FileSystemEntityType.link) continue;
    if (type == FileSystemEntityType.notFound) continue;
    final name = p.basename(entity.path);
    if (_shouldSkipName(name)) continue;
    onEntity(entity);
    if (type == FileSystemEntityType.directory) {
      await _walk(
        Directory(entity.path),
        depth: depth + 1,
        onEntity: onEntity,
      );
    }
  }
}

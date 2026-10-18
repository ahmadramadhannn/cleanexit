import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/vault_models.dart';

/// The vault is CleanExit's quarantine area. Files the user did not keep can
/// be parked here instead of the Recycle Bin, and restored later from the
/// History screen. Each session gets its own sub-folder + manifest.
class VaultService {
  final String vaultRoot;

  VaultService(this.vaultRoot);

  Directory sessionDir(String sessionId) =>
      Directory(p.join(vaultRoot, sessionId));

  /// Moves [paths] into the vault and writes the manifest.
  /// Returns the manifest describing where everything went.
  Future<VaultManifest> stash({
    required String sessionId,
    required List<String> paths,
    void Function(int done, int total, String current)? onProgress,
  }) async {
    final dir = sessionDir(sessionId);
    await dir.create(recursive: true);

    final items = <VaultItem>[];
    for (var i = 0; i < paths.length; i++) {
      final original = paths[i];
      onProgress?.call(i, paths.length, original);
      final fse = FileSystemEntity.typeSync(original, followLinks: false);
      if (fse == FileSystemEntityType.notFound) continue;

      final name = p.basename(original);
      var vaultPath = p.join(dir.path, '${i.toString().padLeft(4, '0')}__$name');
      try {
        await _moveEntity(original, vaultPath);
      } catch (_) {
        // Collision or cross-device: make the name unique and retry once.
        vaultPath = p.join(
          dir.path,
          '${i.toString().padLeft(4, '0')}__${DateTime.now().millisecondsSinceEpoch}__$name',
        );
        await _moveEntity(original, vaultPath);
      }

      int size = 0;
      try {
        size = FileStat.statSync(vaultPath).size;
      } catch (_) {}

      items.add(VaultItem(
        originalPath: original,
        vaultPath: vaultPath,
        name: name,
        sizeBytes: size,
        deletedAt: DateTime.now(),
      ));
    }
    onProgress?.call(paths.length, paths.length, '');

    final manifest = VaultManifest(
      sessionId: sessionId,
      createdAt: DateTime.now(),
      items: items,
    );
    await File(p.join(dir.path, 'manifest.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );
    return manifest;
  }

  VaultManifest? readManifest(String sessionId) {
    final f = File(p.join(sessionDir(sessionId).path, 'manifest.json'));
    if (!f.existsSync()) return null;
    try {
      return VaultManifest.fromJson(
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Puts every item of a session's vault back where it came from.
  /// Returns the number of successfully restored items.
  Future<int> restoreAll(String sessionId) async {
    final manifest = readManifest(sessionId);
    if (manifest == null) return 0;
    var restored = 0;
    for (final item in manifest.items) {
      if (!File(item.vaultPath).existsSync() &&
          !Directory(item.vaultPath).existsSync()) {
        continue;
      }
      var target = item.originalPath;
      try {
        final exists =
            File(target).existsSync() || Directory(target).existsSync();
        if (exists) {
          final ext = p.extension(target);
          final stem = p.basenameWithoutExtension(target);
          target = p.join(p.dirname(target), '$stem (restored)$ext');
        }
        await _moveEntity(item.vaultPath, target);
        restored++;
      } catch (_) {
        // Leave the item in the vault; user can retry or open the folder.
      }
    }
    if (restored == manifest.items.length && restored > 0) {
      _deleteSessionQuietly(sessionId);
    }
    return restored;
  }

  /// Hard-deletes everything parked for this session.
  Future<int> purgeSession(String sessionId) async {
    final manifest = readManifest(sessionId);
    var count = manifest?.items.length ?? 0;
    _deleteSessionQuietly(sessionId);
    return count;
  }

  void _deleteSessionQuietly(String sessionId) {
    try {
      final dir = sessionDir(sessionId);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}
  }

  /// Public wrapper so other layers (e.g. History record deletion) can drop
  /// a session's vault data without knowing the internals.
  void deleteSessionQuietly(String sessionId) =>
      _deleteSessionQuietly(sessionId);

  /// Total bytes currently parked in the vault.
  int totalBytes() {
    final root = Directory(vaultRoot);
    if (!root.existsSync()) return 0;
    var total = 0;
    try {
      for (final e in root.listSync(recursive: true, followLinks: false)) {
        if (e is File) {
          try {
            total += e.lengthSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _moveEntity(String from, String to) async {
    final type = FileSystemEntity.typeSync(from, followLinks: false);
    try {
      if (type == FileSystemEntityType.directory) {
        await Directory(from).rename(to);
      } else {
        await File(from).rename(to);
      }
    } on FileSystemException {
      // Cross-device rename (EXDEV): copy then delete.
      if (type == FileSystemEntityType.directory) {
        await _copyDir(Directory(from), Directory(to));
        Directory(from).deleteSync(recursive: true);
      } else {
        await File(from).copy(to);
        File(from).deleteSync();
      }
    }
  }

  Future<void> _copyDir(Directory from, Directory to) async {
    await to.create(recursive: true);
    await for (final e in from.list(followLinks: false)) {
      final t = p.join(to.path, p.basename(e.path));
      if (e is Directory) {
        await _copyDir(e, Directory(t));
      } else if (e is File) {
        await e.copy(t);
      }
    }
  }
}

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../models/disposal_method.dart';
import 'vault_service.dart';

class DisposalOutcome {
  final String path;
  final bool success;
  final String? error;
  const DisposalOutcome(this.path, {this.error}) : success = error == null;
}

/// Executes the per-run disposal decision for every path the user did NOT
/// keep. Three strategies: OS recycle bin, private vault, or shred.
class DisposalService {
  final VaultService vault;

  DisposalService(this.vault);

  Future<List<DisposalOutcome>> dispose({
    required List<String> paths,
    required DisposalMethod method,
    required String sessionId,
    void Function(int done, int total, String current)? onProgress,
  }) async {
    final outcomes = <DisposalOutcome>[];
    if (method == DisposalMethod.vault) {
      try {
        final manifest = await vault.stash(
          sessionId: sessionId,
          paths: paths,
          onProgress: onProgress,
        );
        final parked = manifest.items.map((i) => i.originalPath).toSet();
        for (final path in paths) {
          outcomes.add(
            parked.contains(path)
                ? DisposalOutcome(path)
                : DisposalOutcome(path, error: 'File vanished before stashing'),
          );
        }
        return outcomes;
      } catch (e) {
        return [
          for (final path in paths) DisposalOutcome(path, error: '$e'),
        ];
      }
    }

    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      onProgress?.call(i, paths.length, path);
      try {
        if (method == DisposalMethod.recycle) {
          await _recycle(path);
        } else {
          await _shred(path);
        }
        outcomes.add(DisposalOutcome(path));
      } catch (e) {
        outcomes.add(DisposalOutcome(path, error: e.toString()));
      }
    }
    onProgress?.call(paths.length, paths.length, '');
    return outcomes;
  }

  // ---------------------------------------------------------------- recycle

  Future<void> _recycle(String path) async {
    if (Platform.isWindows) {
      await _recycleWindows(path);
    } else {
      await _recycleLinux(path);
    }
  }

  Future<void> _recycleWindows(String path) async {
    final isDir = Directory(path).existsSync();
    final psPath = path.replaceAll("'", "''");
    final api = isDir ? 'DeleteDirectory' : 'DeleteFile';
    final script =
        "Add-Type -AssemblyName Microsoft.VisualBasic; "
        "[Microsoft.VisualBasic.FileIO.FileSystem]::$api("
        "'$psPath','OnlyErrorDialogs','SendToRecycleBin')";
    final result = await Process.run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      runInShell: false,
    );
    if (result.exitCode != 0) {
      throw StateError('Recycle failed: ${result.stderr}');
    }
  }

  Future<void> _recycleLinux(String path) async {
    // Preferred: the desktop's own trash tool.
    try {
      final gio = await Process.run('gio', ['trash', path]);
      if (gio.exitCode == 0) return;
    } catch (_) {/* gio not installed */}

    // Fallback: implement the XDG trash spec by hand.
    final dataHome =
        Platform.environment['XDG_DATA_HOME'] ?? '${CeConstants.home}/.local/share';
    final trashFiles = Directory(p.join(dataHome, 'Trash', 'files'));
    final trashInfo = Directory(p.join(dataHome, 'Trash', 'info'));
    await trashFiles.create(recursive: true);
    await trashInfo.create(recursive: true);

    final base = p.basename(path);
    var target = p.join(trashFiles.path, base);
    var stamp = 0;
    while (File(target).existsSync() || Directory(target).existsSync()) {
      target = p.join(trashFiles.path, '${++stamp}_$base');
    }
    try {
      if (Directory(path).existsSync()) {
        await Directory(path).rename(target);
      } else {
        await File(path).rename(target);
      }
    } on FileSystemException {
      throw StateError(
        'Cannot trash across filesystems — install `gio` or use the Vault.',
      );
    }

    final infoName = p.basename(target);
    final encoded = Uri.file(path).toString();
    final date = DateTime.now().toUtc().toIso8601String().split('.').first;
    await File(p.join(trashInfo.path, '$infoName.trashinfo')).writeAsString(
      '[Trash Info]\nPath=$encoded\nDeletionDate=$date\n',
    );
  }

  // ----------------------------------------------------------------- shred

  Future<void> _shred(String path) async {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type == FileSystemEntityType.directory) {
      final dir = Directory(path);
      await for (final child
          in dir.list(followLinks: false)) {
        await _shred(child.path);
      }
      await dir.deleteSync();
      return;
    }

    final f = File(path);
    final length = f.lengthSync();
    // Single zero-pass wipe. Fast; good enough for session hygiene.
    // (Guaranteed erasure on flash storage is out of scope for v1.)
    final raf = await f.open(mode: FileMode.append);
    try {
      await raf.truncate(length);
      await raf.setPosition(0);
      final chunk = List<int>.filled(64 * 1024, 0);
      var remaining = length;
      while (remaining > 0) {
        final n = remaining > chunk.length ? chunk.length : remaining;
        await raf.writeFrom(chunk, 0, n);
        remaining -= n;
      }
      await raf.flush();
    } finally {
      await raf.close();
    }
    await f.delete();
  }

  String get vaultRootDescription =>
      vault.vaultRoot;
}

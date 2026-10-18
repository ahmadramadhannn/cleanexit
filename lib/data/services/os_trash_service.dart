import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../models/trash_item.dart';

/// Browses the operating system's own trash:
///  - Linux: the XDG Trash spec (`$XDG_DATA_HOME/Trash/{files,info}` —
///    the folder GNOME/KDE file managers empty, same one `gio trash` uses).
///  - Windows: the Recycle Bin, through the Shell COM API via PowerShell.
///
/// Lets the user confirm what is recoverable, restore single items to
/// their original location, or wipe them for good.
class OsTrashService {
  const OsTrashService();

  // ------------------------------------------------------------------ list

  Future<List<TrashItem>> list() async {
    if (Platform.isWindows) return _listWindows();
    return _listLinux();
  }

  Future<List<TrashItem>> _listLinux() async {
    final trash = _linuxTrashDir();
    final filesDir = Directory(p.join(trash, 'files'));
    final infoDir = Directory(p.join(trash, 'info'));
    if (!filesDir.existsSync()) return const [];

    final out = <TrashItem>[];
    for (final e in filesDir.listSync(followLinks: false)) {
      final name = p.basename(e.path);
      final isDir = e is Directory;
      if (!isDir && e is! File) continue;

      var originalPath = e.path;
      DateTime? deletedAt;
      final info = File(p.join(infoDir.path, '$name.trashinfo'));
      if (info.existsSync()) {
        try {
          final parsed = parseTrashInfo(info.readAsStringSync());
          if (parsed.$1 != null) originalPath = parsed.$1!;
          deletedAt = parsed.$2;
        } catch (_) {}
      }

      var size = 0;
      try {
        if (!isDir) size = File(e.path).lengthSync();
      } catch (_) {}

      out.add(TrashItem(
        id: e.path,
        name: name,
        originalPath: originalPath,
        deletedAt: deletedAt,
        isDir: isDir,
        sizeLabel: isDir ? 'folder' : formatBytes(size),
      ));
    }
    out.sort((a, b) => (b.deletedAt ?? DateTime(0))
        .compareTo(a.deletedAt ?? DateTime(0)));
    return out;
  }

  Future<List<TrashItem>> _listWindows() async {
    final script = '''
\$s = New-Object -ComObject Shell.Application
\$rb = \$s.Namespace(0xA)
\$out = @()
foreach (\$i in \$rb.Items()) {
  \$out += [PSCustomObject]@{
    Name = \$i.Name
    Path = \$i.Path
    Orig = \$rb.GetDetailsOf(\$i, 1)
    Date = \$rb.GetDetailsOf(\$i, 2)
    Size = \$rb.GetDetailsOf(\$i, 3)
    IsDir = \$i.IsFolder
  }
}
\$out | ConvertTo-Json -Compress
'''
        .trim();
    final result = await _runPowerShell(script);
    if (result.exitCode != 0) {
      throw StateError('Could not read the Recycle Bin: ${result.stderr}');
    }
    final text = result.stdout.toString().trim();
    if (text.isEmpty) return const [];

    final decoded = jsonDecode(text);
    final List items;
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map) {
      items = [decoded];
    } else {
      return const [];
    }

    final out = <TrashItem>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final name = (raw['Name'] ?? '').toString();
      final path = (raw['Path'] ?? '').toString();
      if (path.isEmpty) continue;
      out.add(TrashItem(
        id: path,
        name: name.isEmpty ? p.basename(path) : name,
        originalPath: (raw['Orig'] ?? '').toString(),
        deletedAt: parseWindowsTrashDate((raw['Date'] ?? '').toString()),
        isDir: (raw['IsDir'] ?? false) == true,
        sizeLabel: (raw['Size'] ?? '').toString(),
      ));
    }
    return out;
  }

  // ---------------------------------------------------------------- restore

  Future<void> restore(TrashItem item) async {
    if (Platform.isWindows) return _restoreWindows(item);
    return _restoreLinux(item);
  }

  Future<void> _restoreLinux(TrashItem item) async {
    final from = item.id;
    if (!File(from).existsSync() && !Directory(from).existsSync()) {
      throw StateError('Item is no longer in the trash.');
    }

    var target = item.originalPath;
    if (target == null || target.isEmpty || p.equals(target, from)) {
      // No usable original location recorded — put it back under home.
      target = p.join(CeConstants.home, p.basename(from));
    }
    // Never overwrite anything that is already there.
    if (File(target).existsSync() || Directory(target).existsSync()) {
      final ext = p.extension(target);
      final stem = p.basenameWithoutExtension(target);
      target = p.join(p.dirname(target), '$stem (restored)$ext');
    }
    Directory(p.dirname(target)).createSync(recursive: true);

    await _move(from, target);

    // Drop the .trashinfo so the item no longer shows up anywhere.
    final info = File(p.join(
      _linuxTrashDir(),
      'info',
      '${p.basename(from)}.trashinfo',
    ));
    if (info.existsSync()) info.deleteSync();
  }

  Future<void> _restoreWindows(TrashItem item) async {
    final id = item.id.replaceAll("'", "''");
    final script = '''
\$s = New-Object -ComObject Shell.Application
\$rb = \$s.Namespace(0xA)
foreach (\$i in \$rb.Items()) {
  if (\$i.Path -eq '$id') {
    foreach (\$v in \$i.Verbs()) {
      \$n = (\$v.Name -replace '&','')
      if (\$n -match '^(?i)restore') { \$v.DoIt(); break }
    }
    break
  }
}
'''
        .trim();
    final result = await _runPowerShell(script);
    if (result.exitCode != 0) {
      throw StateError('Restore failed: ${result.stderr}');
    }
  }

  // ---------------------------------------------------------- delete/empty

  Future<void> deleteForever(TrashItem item) async {
    if (Platform.isWindows) {
      final id = item.id.replaceAll("'", "''");
      final result = await _runPowerShell(
        "Remove-Item -LiteralPath '$id' -Force -Recurse -ErrorAction Stop",
      );
      if (result.exitCode != 0) {
        throw StateError('Delete failed: ${result.stderr}');
      }
      return;
    }
    _deleteEntity(item.id);
    _deleteInfoFor(item.id);
  }

  /// Empties the whole trash; returns how many items were in it.
  Future<int> emptyAll() async {
    final items = await list();
    if (Platform.isWindows) {
      final result = await _runPowerShell(
        'Clear-RecycleBin -Force -ErrorAction Stop',
      );
      if (result.exitCode != 0) {
        throw StateError('Could not empty the Recycle Bin: ${result.stderr}');
      }
      return items.length;
    }
    for (final item in items) {
      _deleteEntity(item.id);
      _deleteInfoFor(item.id);
    }
    return items.length;
  }

  // -------------------------------------------------------------- internals

  void _deleteEntity(String path) {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type == FileSystemEntityType.directory) {
      Directory(path).deleteSync(recursive: true);
    } else {
      File(path).deleteSync();
    }
  }

  void _deleteInfoFor(String trashedPath) {
    final info = File(p.join(
      _linuxTrashDir(),
      'info',
      '${p.basename(trashedPath)}.trashinfo',
    ));
    if (info.existsSync()) info.deleteSync();
  }

  Future<void> _move(String from, String to) async {
    final type = FileSystemEntity.typeSync(from, followLinks: false);
    try {
      if (type == FileSystemEntityType.directory) {
        await Directory(from).rename(to);
      } else {
        await File(from).rename(to);
      }
    } on FileSystemException {
      // Cross-device rename: copy then delete as a fallback.
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

  String _linuxTrashDir() {
    final dataHome = Platform.environment['XDG_DATA_HOME'] ??
        '${CeConstants.home}/.local/share';
    return p.join(dataHome, 'Trash');
  }

  static Future<ProcessResult> _runPowerShell(String script) {
    return Process.run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      runInShell: false,
    );
  }
}

// ------------------------------------------------------------- pure helpers

/// Parses a `.trashinfo` file (XDG trash spec). Path is URL-encoded,
/// DeletionDate is `YYYY-MM-DDTHH:MM:SS`. Returns (path, deletionDate).
(String?, DateTime?) parseTrashInfo(String contents) {
  var path = '';
  DateTime? date;
  for (final rawLine in contents.split('\n')) {
    final line = rawLine.trim();
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim();
    final value = line.substring(eq + 1).trim();
    if (key == 'Path') {
      path = Uri.decodeComponent(value);
    } else if (key == 'DeletionDate') {
      date = DateTime.tryParse(value)?.toLocal();
    }
  }
  return (path.isEmpty ? null : path, date);
}

/// Lenient parser for the Recycle Bin's "Date deleted" column, whose format
/// follows the user's locale. Falls back to null when unrecognised.
DateTime? parseWindowsTrashDate(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final iso = DateTime.tryParse(text);
  if (iso != null) return iso;
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})$')
      .firstMatch(text);
  if (m != null) {
    try {
      return DateTime(
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
        int.parse(m.group(1)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
      );
    } catch (_) {}
  }
  return null;
}

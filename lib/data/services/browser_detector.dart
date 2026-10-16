import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../models/browser_models.dart';

/// Finds Chromium-family browsers installed on this machine and enumerates
/// their profile folders (the ones that actually contain cookie/history DBs).
class BrowserDetector {
  Future<List<BrowserApp>> detect() async {
    final out = <BrowserApp>[];
    for (final def in CeConstants.browsers) {
      final dataRoot = CeConstants.expandPath(
        Platform.isWindows ? def.windowsUserdata : def.linuxUserdata,
      );
      if (!Directory(dataRoot).existsSync()) continue;

      final profiles = def.flatProfileLayout
          ? _flatProfile(def.id, dataRoot)
          : _standardProfiles(dataRoot);

      out.add(BrowserApp(
        defId: BrowserDefId.values.firstWhere((d) => d.name == def.id),
        displayName: def.displayName,
        dataRoot: dataRoot,
        profiles: profiles,
        processNames: def.processNames,
      ));
    }
    return out;
  }

  List<BrowserProfile> _standardProfiles(String dataRoot) {
    final profiles = <BrowserProfile>[];
    final root = Directory(dataRoot);
    for (final e in root.listSync(followLinks: false)) {
      if (e is! Directory) continue;
      final name = p.basename(e.path);
      if (name != 'Default' && !name.startsWith('Profile ')) continue;
      final profile = _buildProfile(name, e.path);
      if (profile != null) profiles.add(profile);
    }
    // Sort: Default first, then Profile 1, 2, ...
    profiles.sort((a, b) {
      if (a.name == 'Default') return -1;
      if (b.name == 'Default') return 1;
      return a.name.compareTo(b.name);
    });
    return profiles;
  }

  List<BrowserProfile> _flatProfile(String id, String dataRoot) {
    final profile = _buildProfile('Default', dataRoot);
    return profile == null ? const [] : [profile];
  }

  BrowserProfile? _buildProfile(String name, String dir) {
    String? firstExisting(List<String> candidates) {
      for (final c in candidates) {
        if (File(p.join(dir, c)).existsSync()) return p.join(dir, c);
      }
      return null;
    }

    final cookies = firstExisting([
      p.join('Network', 'Cookies'),
      'Cookies',
      p.join('Network', 'Extension Cookies'),
      'Extension Cookies',
    ]);
    final history = firstExisting(['History']);

    if (cookies == null && history == null) return null;
    return BrowserProfile(
      name: name,
      dirPath: dir,
      cookiesPath: cookies,
      historyPath: history,
    );
  }

  /// Best-effort "is this browser currently running?" check.
  Future<bool> isRunning(BrowserApp app) async {
    try {
      if (Platform.isWindows) {
        for (final name in app.processNames) {
          if (!name.endsWith('.exe')) continue;
          final r = await Process.run(
            'tasklist',
            ['/FI', 'IMAGENAME eq $name', '/NH', '/FO', 'CSV'],
            runInShell: true,
          );
          if (r.stdout.toString().toLowerCase().contains(name.toLowerCase())) {
            return true;
          }
        }
        return false;
      }
      for (final name in app.processNames) {
        if (name.endsWith('.exe')) continue;
        final r = await Process.run('pgrep', ['-x', name]);
        if (r.exitCode == 0) return true;
      }
      return false;
    } catch (_) {
      return false; // Cannot check — UI still warns the user to close it.
    }
  }
}

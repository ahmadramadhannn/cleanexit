import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../models/browser_account.dart';

/// One account found by parsing a browser preference file, before it is
/// merged with the recorded history in [BrowserAccountStore].
class ParsedAccount {
  final String profileDir;
  final String email;
  final String fullName;
  final String source;

  const ParsedAccount({
    required this.profileDir,
    required this.email,
    required this.fullName,
    required this.source,
  });
}

/// Detects the accounts signed into the browsers installed on this machine.
///
/// Sources (all plain preference files — no password stores are touched):
///  - Chromium family: `Local State` → profile.info_cache (the file Chrome
///    itself calls "user preferences"), plus each profile's `Preferences`
///    → account_info as a fallback.
///  - Firefox: `profiles.ini` + per-profile `signedInUser.json`.
class BrowserAccountService {
  const BrowserAccountService();

  /// Scans the chosen browsers' preference files for signed-in accounts.
  ///
  /// [onlyBrowserIds] restricts the scan to the browser ids the user picked
  /// in Settings (Chromium ids plus 'firefox' for the monitor-only Firefox
  /// section). `null` means "no preference recorded" and scans everything;
  /// an EMPTY set scans nothing — the user has not chosen any browser yet.
  Future<List<BrowserAccount>> scan({Set<String>? onlyBrowserIds}) async {
    final now = DateTime.now();
    final out = <BrowserAccount>[];

    void add(String browserKey, String browserName, ParsedAccount acc) {
      out.add(BrowserAccount(
        browserKey: browserKey,
        browserName: browserName,
        profileDir: acc.profileDir,
        profileLabel: acc.profileDir,
        email: acc.email,
        fullName: acc.fullName,
        source: acc.source,
        firstSeen: now,
        lastSeen: now,
      ));
    }

    for (final def in CeConstants.browsers) {
      if (onlyBrowserIds != null && !onlyBrowserIds.contains(def.id)) {
        continue;
      }
      final dataRoot = CeConstants.expandPath(
        Platform.isWindows ? def.windowsUserdata : def.linuxUserdata,
      );
      if (!Directory(dataRoot).existsSync()) continue;

      // 1) Authoritative source: Local State → profile.info_cache.
      final localState = File(p.join(dataRoot, 'Local State'));
      if (localState.existsSync()) {
        try {
          final accounts = parseLocalStateAccounts(
            localState.readAsStringSync(),
          );
          for (final a in accounts) {
            add(def.id, def.displayName, a);
          }
        } catch (_) {
          // Corrupt JSON — fall through to per-profile Preferences.
        }
      }

      // 2) Fallback / supplement: per-profile Preferences → account_info.
      for (final entry in _profileDirs(dataRoot)) {
        final prefs = File(p.join(entry, 'Preferences'));
        if (!prefs.existsSync()) continue;
        try {
          for (final a in parsePreferencesAccountInfo(
            prefs.readAsStringSync(),
            entry,
          )) {
            add(def.id, def.displayName, a);
          }
        } catch (_) {
          // Ignore unreadable preference files.
        }
      }
    }

    // Firefox (also flatpak / snap installs on Linux).
    final wantFirefox =
        onlyBrowserIds == null || onlyBrowserIds.contains('firefox');
    for (final firefoxRoot in wantFirefox ? _firefoxRoots() : const <String>[]) {
      final ini = File(p.join(firefoxRoot, 'profiles.ini'));
      if (!ini.existsSync()) continue;
      try {
        final dirs = parseFirefoxProfileIni(ini.readAsStringSync());
        for (final dir in dirs) {
          final signedIn = File(p.join(firefoxRoot, dir, 'signedInUser.json'));
          if (!signedIn.existsSync()) continue;
          try {
            final accounts = parseFirefoxSignedInUser(
              signedIn.readAsStringSync(),
              dir,
            );
            for (final a in accounts) {
              add('firefox', 'Firefox', a);
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    return out;
  }

  /// Profile directories of a Chromium user-data root.
  List<String> _profileDirs(String dataRoot) {
    final out = <String>[];
    final root = Directory(dataRoot);
    for (final e in root.listSync(followLinks: false)) {
      if (e is! Directory) continue;
      final name = p.basename(e.path);
      if (name == 'Default' || name.startsWith('Profile ')) {
        out.add(e.path);
      }
    }
    return out;
  }

  /// Candidate Firefox profile roots for the current platform.
  List<String> _firefoxRoots() {
    if (Platform.isWindows) {
      return [
        CeConstants.expandPath(r'%APPDATA%\Mozilla\Firefox'),
      ];
    }
    return [
      '${CeConstants.home}/.mozilla/firefox',
      '${CeConstants.home}/.var/app/org.mozilla.firefox/.mozilla/firefox',
      '${CeConstants.home}/snap/firefox/common/.mozilla/firefox',
    ];
  }

  // --------------------------------------------------------- pure parsers
  // Static and side-effect free so they are unit-testable without any
  // filesystem, and so a corrupt file can only ever fail its own parse.

  /// Chromium `Local State` → profile.info_cache entries that carry a
  /// signed-in `user_name`.
  static List<ParsedAccount> parseLocalStateAccounts(String jsonText) {
    final root = jsonDecode(jsonText) as Map<String, dynamic>;
    final infoCache =
        ((root['profile'] as Map<String, dynamic>?)?['info_cache']
                as Map<String, dynamic>?) ??
            const {};
    final out = <ParsedAccount>[];
    infoCache.forEach((dirName, raw) {
      if (raw is! Map<String, dynamic>) return;
      final email = (raw['user_name'] as String?)?.trim() ?? '';
      if (email.isEmpty) return; // Local, signed-out profile.
      out.add(ParsedAccount(
        profileDir: dirName,
        email: email,
        fullName: ((raw['gaia_name'] as String?) ??
                (raw['full_name'] as String?) ??
                '')
            .trim(),
        source: 'chromium-local-state',
      ));
    });
    return out;
  }

  /// Chromium per-profile `Preferences` → `account_info` entries.
  static List<ParsedAccount> parsePreferencesAccountInfo(
    String jsonText,
    String profileDirPath,
  ) {
    final root = jsonDecode(jsonText) as Map<String, dynamic>;
    final infos = (root['account_info'] as List?) ?? const [];
    final out = <ParsedAccount>[];
    for (final raw in infos) {
      if (raw is! Map<String, dynamic>) continue;
      final email = (raw['email'] as String?)?.trim() ?? '';
      if (email.isEmpty) continue;
      out.add(ParsedAccount(
        profileDir: p.basename(profileDirPath),
        email: email,
        fullName: ((raw['full_name'] as String?) ??
                (raw['given_name'] as String?) ??
                '')
            .trim(),
        source: 'chromium-preferences',
      ));
    }
    return out;
  }

  /// Firefox `signedInUser.json` → the signed-in Firefox Sync account.
  static List<ParsedAccount> parseFirefoxSignedInUser(
    String jsonText,
    String profileDir,
  ) {
    final root = jsonDecode(jsonText) as Map<String, dynamic>;
    final account = root['account'] as Map<String, dynamic>?;
    final email = (account?['email'] as String?)?.trim() ?? '';
    if (email.isEmpty) return const [];
    return [
      ParsedAccount(
        profileDir: profileDir,
        email: email,
        fullName: ((account?['displayName'] as String?) ?? '').trim(),
        source: 'firefox-signed-in-user',
      ),
    ];
  }

  /// Firefox `profiles.ini` → profile directory names (relative paths).
  static List<String> parseFirefoxProfileIni(String iniText) {
    final out = <String>[];
    String? currentPath;
    for (final rawLine in iniText.split('\n')) {
      final line = rawLine.trim();
      if (line.startsWith('[')) {
        // New section starts — flush the previous one.
        if (currentPath != null && !out.contains(currentPath)) {
          out.add(currentPath);
        }
        currentPath = null;
        continue;
      }
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      final key = line.substring(0, eq).trim();
      final value = line.substring(eq + 1).trim();
      if (key == 'Path' && value.isNotEmpty) {
        currentPath = value.replaceAll('\\', '/');
      }
    }
    if (currentPath != null && !out.contains(currentPath)) {
      out.add(currentPath);
    }
    return out;
  }
}

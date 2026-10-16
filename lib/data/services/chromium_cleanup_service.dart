import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/utils.dart';
import '../models/browser_models.dart';
import '../models/models.dart';
import '../models/site_activity.dart';
import 'browser_detector.dart';
import 'vault_service.dart';

class ProfileSites {
  final BrowserProfile profile;
  final List<SiteActivity> sites;
  const ProfileSites(this.profile, this.sites);
}

class BrowserScanResult {
  final BrowserApp app;
  final bool running;
  final List<ProfileSites> profiles;
  const BrowserScanResult(this.app, this.running, this.profiles);

  /// Sites aggregated across all profiles of this browser.
  List<SiteActivity> get mergedSites {
    final byDomain = <String, _Agg>{};
    for (final ps in profiles) {
      for (final s in ps.sites) {
        final agg = byDomain.putIfAbsent(
          s.domain,
          () => _Agg(s.domain),
        );
        agg.cookies += s.cookieCount;
        agg.visits += s.visitCount;
        final lv = s.lastVisit;
        if (lv != null && (agg.last == null || lv.isAfter(agg.last!))) {
          agg.last = lv;
        }
      }
    }
    final list = byDomain.values
        .map((a) => SiteActivity(
              domain: a.domain,
              cookieCount: a.cookies,
              visitCount: a.visits,
              lastVisit: a.last,
            ))
        .toList()
      ..sort((a, b) {
        final byActivity = (b.cookieCount + b.visitCount)
            .compareTo(a.cookieCount + a.visitCount);
        if (byActivity != 0) return byActivity;
        return a.domain.compareTo(b.domain);
      });
    return list;
  }
}

class _Agg {
  final String domain;
  int cookies = 0;
  int visits = 0;
  DateTime? last;
  _Agg(this.domain);
}

/// Thrown when the user tries to clean a browser that is still running.
class BrowserRunningException implements Exception {
  final String browserName;
  BrowserRunningException(this.browserName);
  @override
  String toString() =>
      '$browserName is still running. Close it completely, then try again.';
}

/// Reads and cleans Chromium profile databases (cookies + history) for a
/// given time range. Every modification is backed up into the vault first.
class ChromiumCleanupService {
  final VaultService vault;

  ChromiumCleanupService(this.vault);

  // -------------------------------------------------------------- loading

  static bool _loaderReady = false;

  void _ensureSqliteLoader() {
    if (_loaderReady) return;
    if (Platform.isLinux) {
      open.overrideFor(OperatingSystem.linux, () {
        try {
          return DynamicLibrary.open('libsqlite3.so');
        } catch (_) {
          return DynamicLibrary.open('libsqlite3.so.0');
        }
      });
    }
    _loaderReady = true;
  }

  // ----------------------------------------------------------------- scan

  /// Which sites show account activity in [start, end] for this browser?
  Future<BrowserScanResult> scanBrowser({
    required BrowserApp app,
    required DateTime start,
    required DateTime end,
  }) async {
    final running = await const BrowserDetector().isRunning(app);
    final profiles = <ProfileSites>[];

    final tmp = await Directory.systemTemp.createTemp('cleanexit_scan_');
    try {
      for (var i = 0; i < app.profiles.length; i++) {
        final profile = app.profiles[i];
        final sites = <String, SiteActivity>{};

        if (profile.historyPath != null) {
          final dbCopy = await _copyForRead(
            profile.historyPath!,
            tmp,
            'h$i',
          );
          _mergeSites(sites, _readHistory(dbCopy, start, end));
        }
        if (profile.cookiesPath != null) {
          final dbCopy = await _copyForRead(
            profile.cookiesPath!,
            tmp,
            'c$i',
          );
          _mergeSites(sites, _readCookies(dbCopy, start, end));
        }
        profiles.add(
          ProfileSites(profile, sites.values.toList()),
        );
      }
    } finally {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }

    return BrowserScanResult(app, running, profiles);
  }

  void _mergeSites(
    Map<String, SiteActivity> sink,
    List<SiteActivity> incoming,
  ) {
    for (final s in incoming) {
      final existing = sink[s.domain];
      if (existing == null) {
        sink[s.domain] = s;
      } else {
        sink[s.domain] = existing.copyWith(
          cookieCount: existing.cookieCount + s.cookieCount,
          visitCount: existing.visitCount + s.visitCount,
          lastVisit: (existing.lastVisit == null ||
                  (s.lastVisit?.isAfter(existing.lastVisit!) ?? false))
              ? s.lastVisit
              : existing.lastVisit,
        );
      }
    }
  }

  Future<String> _copyForRead(String dbPath, Directory tmp, String tag) async {
    final dest = p.join(tmp.path, '$tag${p.basename(dbPath)}');
    await File(dbPath).copy(dest);
    for (final suffix in ['-wal', '-shm']) {
      final side = File('$dbPath$suffix');
      if (side.existsSync()) {
        await side.copy('$dest$suffix');
      }
    }
    return dest;
  }

  List<SiteActivity> _readHistory(String dbPath, DateTime start, DateTime end) {
    _ensureSqliteLoader();
    final byDomain = <String, SiteActivity>{};
    try {
      final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      try {
        final rs = db.select(
          'SELECT u.url, v.visit_time FROM visits v '
          'JOIN urls u ON u.id = v.url '
          'WHERE v.visit_time BETWEEN ? AND ?',
          [dartToChromium(start), dartToChromium(end)],
        );
        for (final row in rs) {
          final url = row['url'] as String? ?? '';
          final domain = registrableDomain(hostFromUrl(url));
          if (domain.isEmpty) continue;
          final t = chromiumToDart(row['visit_time'] as int);
          final agg = byDomain.putIfAbsent(
            domain,
            () => SiteActivity(
              domain: domain,
              cookieCount: 0,
              visitCount: 0,
            ),
          );
          byDomain[domain] = agg.copyWith(visitCount: agg.visitCount + 1);
          final cur = byDomain[domain]!;
          if (cur.lastVisit == null || t.isAfter(cur.lastVisit!)) {
            byDomain[domain] = cur.copyWith(lastVisit: t);
          }
        }
      } finally {
        db.dispose();
      }
    } catch (_) {
      // Locked / unreadable DB — report no history rather than crash.
    }
    return byDomain.values.toList();
  }

  List<SiteActivity> _readCookies(String dbPath, DateTime start, DateTime end) {
    _ensureSqliteLoader();
    final byDomain = <String, SiteActivity>{};
    try {
      final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      try {
        final rs = db.select(
          'SELECT host_key, COUNT(*) AS n, MAX(last_access_utc) AS last '
          'FROM cookies '
          'WHERE creation_utc BETWEEN ? AND ? OR last_access_utc BETWEEN ? AND ? '
          'GROUP BY host_key',
          [dartToChromium(start), dartToChromium(end),
           dartToChromium(start), dartToChromium(end)],
        );
        for (final row in rs) {
          final hostKey = row['host_key'] as String? ?? '';
          final domain = registrableDomain(hostKey);
          if (domain.isEmpty) continue;
          final n = row['n'] as int;
          final t = row['last'] == null
              ? null
              : chromiumToDart(row['last'] as int);
          final agg = byDomain.putIfAbsent(
            domain,
            () => SiteActivity(
              domain: domain,
              cookieCount: 0,
              visitCount: 0,
            ),
          );
          byDomain[domain] =
              agg.copyWith(cookieCount: agg.cookieCount + n);
          final cur = byDomain[domain]!;
          if (t != null && (cur.lastVisit == null || t.isAfter(cur.lastVisit!))) {
            byDomain[domain] = cur.copyWith(lastVisit: t);
          }
        }
      } finally {
        db.dispose();
      }
    } catch (_) {
      // Locked / unreadable DB.
    }
    return byDomain.values.toList();
  }

  // --------------------------------------------------------------- cleanup

  /// Removes ALL cookies (any creation time) for [domains] — that is what
  /// actually logs an account out. Backs every DB up into the vault first.
  Future<List<SiteCleanupResult>> clearSiteData({
    required BrowserApp app,
    required List<String> domains,
    required String sessionId,
  }) async {
    final running = await const BrowserDetector().isRunning(app);
    if (running) throw BrowserRunningException(app.displayName);

    final results = <SiteCleanupResult>[];
    for (final profile in app.profiles) {
      final cookieDbs = <String>[];
      for (final candidate in [
        p.join(profile.dirPath, 'Network', 'Cookies'),
        p.join(profile.dirPath, 'Cookies'),
        p.join(profile.dirPath, 'Network', 'Extension Cookies'),
        p.join(profile.dirPath, 'Extension Cookies'),
      ]) {
        if (File(candidate).existsSync() && !cookieDbs.contains(candidate)) {
          cookieDbs.add(candidate);
        }
      }

      var removed = 0;
      String? error;
      for (final dbPath in cookieDbs) {
        try {
          await _backup(dbPath, app, profile, sessionId);
          removed += _deleteCookieRows(dbPath, domains);
        } on SqliteException catch (e) {
          error ??= 'Database locked — ${e.message}';
        } catch (e) {
          error ??= '$e';
        }
      }
      results.add(SiteCleanupResult(
        '${app.defId.name}:${profile.name}',
        removed,
        error,
      ));
    }
    return results;
  }

  int _deleteCookieRows(String dbPath, List<String> domains) {
    _ensureSqliteLoader();
    final db = sqlite3.open(dbPath);
    var total = 0;
    try {
      db.execute('BEGIN');
      final stmt = db.prepare(
        'DELETE FROM cookies WHERE host_key = ?1 '
        'OR host_key = "." || ?1 OR host_key LIKE "%." || ?1',
      );
      for (final d in domains) {
        stmt.execute([d]);
        total += db.updatedRows;
      }
      stmt.dispose();
      db.execute('COMMIT');
    } catch (_) {
      try {
        db.execute('ROLLBACK');
      } catch (_) {}
      rethrow;
    } finally {
      db.dispose();
    }
    return total;
  }

  /// Clears history (visits, urls, downloads, search terms) inside the range.
  /// Returns the number of visit rows removed.
  Future<int> clearHistoryInRange({
    required BrowserApp app,
    required DateTime start,
    required DateTime end,
    required String sessionId,
  }) async {
    final running = await const BrowserDetector().isRunning(app);
    if (running) throw BrowserRunningException(app.displayName);

    var total = 0;
    for (final profile in app.profiles) {
      final historyPath = profile.historyPath;
      if (historyPath == null || !File(historyPath).existsSync()) continue;
      await _backup(historyPath, app, profile, sessionId);
      total += _deleteHistoryRows(historyPath, start, end);
    }
    return total;
  }

  int _deleteHistoryRows(String dbPath, DateTime start, DateTime end) {
    _ensureSqliteLoader();
    final db = sqlite3.open(dbPath);
    var removed = 0;
    try {
      db.execute('BEGIN');
      final rs = db.select(
        'DELETE FROM visits WHERE visit_time BETWEEN ? AND ?',
        [dartToChromium(start), dartToChromium(end)],
      );
      removed = db.updatedRows;

      db.execute(
        'DELETE FROM keyword_search_terms WHERE url_id NOT IN '
        '(SELECT id FROM urls)',
      );
      db.execute(
        'DELETE FROM segment_usage WHERE segment_id NOT IN '
        '(SELECT id FROM segments)',
      );
      db.execute(
        'DELETE FROM segments WHERE url_id NOT IN (SELECT id FROM urls)',
      );
      db.execute(
        'DELETE FROM urls WHERE id NOT IN (SELECT url FROM visits)',
      );
      db.execute(
        'DELETE FROM downloads_url_chains WHERE id NOT IN '
        '(SELECT id FROM downloads)',
      );
      db.execute(
        'DELETE FROM downloads WHERE start_time BETWEEN ? AND ?',
        [dartToChromium(start), dartToChromium(end)],
      );
      db.execute('COMMIT');
    } catch (_) {
      try {
        db.execute('ROLLBACK');
      } catch (_) {}
      rethrow;
    } finally {
      db.dispose();
    }
    return removed;
  }

  // --------------------------------------------------------------- backup

  Future<void> _backup(
    String dbPath,
    BrowserApp app,
    BrowserProfile profile,
    String sessionId,
  ) async {
    final backupDir = p.join(
      vault.sessionDir(sessionId).path,
      'browser_backup',
      app.defId.name,
      profile.name,
    );
    await Directory(backupDir).create(recursive: true);
    final name = p.basename(dbPath);
    await File(dbPath).copy(p.join(backupDir, '$name.bak'));
    for (final suffix in ['-wal', '-shm']) {
      final side = File('$dbPath$suffix');
      if (side.existsSync()) {
        await side.copy(p.join(backupDir, '$name.bak$suffix'));
      }
    }
  }
}



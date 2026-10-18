import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/browser_account.dart';

/// Persistent record of every browser account CleanExit has ever detected.
///
/// This is what turns a one-off scan into monitoring: each scan updates
/// `lastSeen` for accounts still signed in and keeps records of accounts
/// that have since been signed out, with their `firstSeen` intact.
class BrowserAccountStore {
  final String filePath;

  BrowserAccountStore(String baseDir)
      : filePath = p.join(baseDir, 'accounts.json');

  Map<String, BrowserAccount> _load() {
    final f = File(filePath);
    if (!f.existsSync()) return {};
    try {
      final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      return raw.map(
        (k, v) => MapEntry(
          k,
          BrowserAccount.fromJson(v as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  void _save(Map<String, BrowserAccount> records) {
    final f = File(filePath);
    f.parent.createSync(recursive: true);
    final tmp = File('${f.path}.tmp');
    tmp.writeAsStringSync(
      const JsonEncoder.withIndent('  ')
          .convert(records.map((k, v) => MapEntry(k, v.toJson()))),
    );
    if (f.existsSync()) f.deleteSync();
    tmp.renameSync(f.path);
  }

  /// Merges a fresh scan into the history: known accounts keep their
  /// `firstSeen` and get a new `lastSeen`; new accounts are recorded;
  /// accounts no longer detected are KEPT (that's the point of the log).
  List<BrowserAccount> upsertScan(List<BrowserAccount> scanned) {
    final records = _load();
    for (final acc in scanned) {
      final existing = records[acc.recordKey];
      records[acc.recordKey] = existing == null
          ? acc
          : existing.copyWith(
              profileLabel: acc.profileLabel,
              fullName: acc.fullName,
              lastSeen: acc.lastSeen,
            );
    }
    _save(records);
    return records.values.toList();
  }

  List<BrowserAccount> all() => _load().values.toList();

  void forget(String recordKey) {
    final records = _load();
    records.remove(recordKey);
    _save(records);
  }
}

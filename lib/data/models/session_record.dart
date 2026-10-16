import 'disposal_method.dart';
import 'tracked_file.dart';

enum SessionMode { live, retroactive }

enum SessionStatus { running, awaitingReview, completed, cancelled }

extension SessionModeX on SessionMode {
  String get label => switch (this) {
        SessionMode.live => 'Watched session',
        SessionMode.retroactive => 'Retroactive scan',
      };

  static SessionMode fromJson(String v) => SessionMode.values
      .firstWhere((m) => m.name == v, orElse: () => SessionMode.retroactive);
}

extension SessionStatusX on SessionStatus {
  String get label => switch (this) {
        SessionStatus.running => 'Running',
        SessionStatus.awaitingReview => 'Awaiting review',
        SessionStatus.completed => 'Completed',
        SessionStatus.cancelled => 'Cancelled',
      };

  static SessionStatus fromJson(String v) => SessionStatus.values
      .firstWhere((s) => s.name == v, orElse: () => SessionStatus.completed);
}

/// What happened to one site during browser cleanup.
class SiteCleanupResult {
  final String domain;
  final int cookiesRemoved;
  final String? error;

  const SiteCleanupResult(this.domain, this.cookiesRemoved, [this.error]);

  bool get success => error == null;

  Map<String, dynamic> toJson() => {
        'domain': domain,
        'cookiesRemoved': cookiesRemoved,
        if (error != null) 'error': error,
      };

  factory SiteCleanupResult.fromJson(Map<String, dynamic> j) => SiteCleanupResult(
        j['domain'] as String,
        (j['cookiesRemoved'] as num?)?.toInt() ?? 0,
        j['error'] as String?,
      );
}

/// A completed (or cancelled) CleanExit session, persisted as JSON.
class SessionRecord {
  final String id;
  final SessionMode mode;
  final DateTime start;
  final DateTime? end;
  final SessionStatus status;

  /// Time range the scan/watch covered (may differ slightly from start/end).
  final DateTime rangeStart;
  final DateTime rangeEnd;

  /// Files that were seen as belonging to the session.
  final List<TrackedFile> files;

  /// Paths the user chose to keep.
  final List<String> keptPaths;

  /// Paths that were actually disposed of.
  final List<String> cleanedPaths;

  final DisposalMethod disposal;

  /// Vault directory for this session, if the vault method was used.
  final String? vaultDir;

  final List<String> browsersCleaned;
  final List<SiteCleanupResult> sitesCleared;
  final bool historyCleared;

  const SessionRecord({
    required this.id,
    required this.mode,
    required this.start,
    required this.end,
    required this.status,
    required this.rangeStart,
    required this.rangeEnd,
    this.files = const [],
    this.keptPaths = const [],
    this.cleanedPaths = const [],
    this.disposal = DisposalMethod.recycle,
    this.vaultDir,
    this.browsersCleaned = const [],
    this.sitesCleared = const [],
    this.historyCleared = false,
  });

  int get bytesCleaned {
    final cleanedSet = cleanedPaths.toSet();
    return files
        .where((f) => cleanedSet.contains(f.path))
        .fold(0, (sum, f) => sum + f.sizeBytes);
  }

  SessionRecord copyWith({
    String? id,
    SessionMode? mode,
    DateTime? start,
    DateTime? end,
    SessionStatus? status,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    List<TrackedFile>? files,
    List<String>? keptPaths,
    List<String>? cleanedPaths,
    DisposalMethod? disposal,
    String? vaultDir,
    List<String>? browsersCleaned,
    List<SiteCleanupResult>? sitesCleared,
    bool? historyCleared,
  }) {
    return SessionRecord(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      start: start ?? this.start,
      end: end ?? this.end,
      status: status ?? this.status,
      rangeStart: rangeStart ?? this.rangeStart,
      rangeEnd: rangeEnd ?? this.rangeEnd,
      files: files ?? this.files,
      keptPaths: keptPaths ?? this.keptPaths,
      cleanedPaths: cleanedPaths ?? this.cleanedPaths,
      disposal: disposal ?? this.disposal,
      vaultDir: vaultDir ?? this.vaultDir,
      browsersCleaned: browsersCleaned ?? this.browsersCleaned,
      sitesCleared: sitesCleared ?? this.sitesCleared,
      historyCleared: historyCleared ?? this.historyCleared,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.name,
        'start': start.millisecondsSinceEpoch,
        'end': end?.millisecondsSinceEpoch,
        'status': status.name,
        'rangeStart': rangeStart.millisecondsSinceEpoch,
        'rangeEnd': rangeEnd.millisecondsSinceEpoch,
        'files': files.map((f) => f.toJson()).toList(),
        'keptPaths': keptPaths,
        'cleanedPaths': cleanedPaths,
        'disposal': disposal.jsonValue,
        'vaultDir': vaultDir,
        'browsersCleaned': browsersCleaned,
        'sitesCleared': sitesCleared.map((s) => s.toJson()).toList(),
        'historyCleared': historyCleared,
      };

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
        id: j['id'] as String,
        mode: SessionModeX.fromJson(j['mode'] as String? ?? 'retroactive'),
        start: DateTime.fromMillisecondsSinceEpoch(j['start'] as int? ?? 0),
        end: j['end'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['end'] as int),
        status: SessionStatusX.fromJson(j['status'] as String? ?? 'completed'),
        rangeStart:
            DateTime.fromMillisecondsSinceEpoch(j['rangeStart'] as int? ?? 0),
        rangeEnd:
            DateTime.fromMillisecondsSinceEpoch(j['rangeEnd'] as int? ?? 0),
        files: ((j['files'] as List?) ?? const [])
            .map((f) => TrackedFile.fromJson(f as Map<String, dynamic>))
            .toList(),
        keptPaths: ((j['keptPaths'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
        cleanedPaths: ((j['cleanedPaths'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
        disposal: DisposalMethodX.fromJson(j['disposal'] as String? ?? 'recycle'),
        vaultDir: j['vaultDir'] as String?,
        browsersCleaned: ((j['browsersCleaned'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
        sitesCleared: ((j['sitesCleared'] as List?) ?? const [])
            .map((s) => SiteCleanupResult.fromJson(s as Map<String, dynamic>))
            .toList(),
        historyCleared: (j['historyCleared'] as bool?) ?? false,
      );
}

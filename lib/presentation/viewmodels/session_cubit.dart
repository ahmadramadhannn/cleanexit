import 'dart:async';

// ignore_for_file: prefer_initializing_formals

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../di.dart';
import '../../data/models/models.dart';
import '../../data/services/file_scanner_service.dart';
import '../../data/services/file_watcher_service.dart';
import '../../data/services/session_store.dart';

enum SessionPhase { idle, watching, scanning, reviewing, browserStep, done }

/// ViewModel for the whole session flow:
/// idle → watching/scanning → reviewing → browserStep → done.
class SessionState extends Equatable {
  final SessionPhase phase;
  final SessionMode? mode;
  final String? sessionId;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final DateTime? timerEnd;
  final int watchedCount;
  final int scannedCount;
  final String? statusText;
  final String? error;
  final List<TrackedFile> files;
  final SessionRecord? lastRecord;

  const SessionState({
    required this.phase,
    this.mode,
    this.sessionId,
    this.rangeStart,
    this.rangeEnd,
    this.timerEnd,
    this.watchedCount = 0,
    this.scannedCount = 0,
    this.statusText,
    this.error,
    this.files = const [],
    this.lastRecord,
  });

  Duration? get remaining {
    final te = timerEnd;
    if (te == null) return null;
    final d = te.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  SessionState copyWith({
    SessionPhase? phase,
    SessionMode? mode,
    String? sessionId,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    DateTime? timerEnd,
    int? watchedCount,
    int? scannedCount,
    String? statusText,
    String? error,
    List<TrackedFile>? files,
    SessionRecord? lastRecord,
    bool clearStatus = false,
  }) {
    return SessionState(
      phase: phase ?? this.phase,
      mode: mode ?? this.mode,
      sessionId: sessionId ?? this.sessionId,
      rangeStart: rangeStart ?? this.rangeStart,
      rangeEnd: rangeEnd ?? this.rangeEnd,
      timerEnd: timerEnd ?? this.timerEnd,
      watchedCount: watchedCount ?? this.watchedCount,
      scannedCount: scannedCount ?? this.scannedCount,
      statusText: clearStatus ? null : (statusText ?? this.statusText),
      error: error,
      files: files ?? this.files,
      lastRecord: lastRecord ?? this.lastRecord,
    );
  }

  @override
  List<Object?> get props => [
        phase, mode, sessionId, rangeStart, rangeEnd, timerEnd,
        watchedCount, scannedCount, statusText, error, files, lastRecord,
      ];
}

class SessionCubit extends Cubit<SessionState> {
  final FileScannerService _scanner;
  final FileWatcherService _watcher;
  final SessionStore _store;
  Timer? _ticker;

  SessionCubit({
    required FileScannerService scanner,
    required FileWatcherService watcher,
    required SessionStore store,
  })  : _scanner = scanner,
        _watcher = watcher,
        _store = store,
        super(const SessionState(phase: SessionPhase.idle));

  /// Workflow #1 — start "watching" before/while using the computer.
  void startLive({Duration? duration}) {
    final now = DateTime.now();
    _watcher.start(
      Services.enabledRoots,
      excludePrefixes: Services.excludePrefixes,
    );
    emit(SessionState(
      phase: SessionPhase.watching,
      mode: SessionMode.live,
      sessionId: newSessionId(),
      rangeStart: now,
      timerEnd: duration == null ? null : now.add(duration),
    ));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (state.phase != SessionPhase.watching) return;
    final remaining = state.remaining;
    if (state.timerEnd != null && remaining == Duration.zero) {
      stopLive();
      return;
    }
    emit(state.copyWith(watchedCount: _watcher.touchedCount));
  }

  /// User pressed stop (or the timer ran out) → collect files for review.
  Future<void> stopLive() async {
    if (state.phase != SessionPhase.watching) return;
    _ticker?.cancel();
    _ticker = null;
    final end = DateTime.now();
    emit(state.copyWith(statusText: 'Collecting session files…'));
    await _watcher.stop();
    final files = _watcher.snapshot();
    emit(state.copyWith(
      phase: SessionPhase.reviewing,
      rangeEnd: end,
      files: files,
      clearStatus: true,
    ));
  }

  /// Workflow #2 — "I already used the PC, here's roughly when".
  Future<void> startRetroactive(DateTime start, DateTime end) async {
    emit(SessionState(
      phase: SessionPhase.scanning,
      mode: SessionMode.retroactive,
      sessionId: newSessionId(),
      rangeStart: start,
      rangeEnd: end,
    ));
    try {
      final files = await _scanner.scan(
        start: start,
        end: end,
        roots: Services.enabledRoots,
        excludePrefixes: Services.excludePrefixes,
        onProgress: (p) {
          if (isClosed) return;
          emit(state.copyWith(
            scannedCount: p.scanned,
            statusText: '${p.found} files in range — scanned ${p.scanned}',
          ));
        },
      );
      if (isClosed) return;
      emit(state.copyWith(
        phase: SessionPhase.reviewing,
        files: files,
        clearStatus: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(SessionState(phase: SessionPhase.idle, error: 'Scan failed: $e'));
    }
  }

  /// Called by the Review VM once disposal finished.
  Future<void> finishReview({
    required List<String> keptPaths,
    required List<String> cleanedPaths,
    required DisposalMethod method,
    String? vaultDir,
  }) async {
    final end = state.rangeEnd ?? DateTime.now();
    final record = SessionRecord(
      id: state.sessionId ?? newSessionId(),
      mode: state.mode ?? SessionMode.retroactive,
      start: state.rangeStart ?? DateTime.now(),
      end: end,
      status: SessionStatus.completed,
      rangeStart: state.rangeStart ?? DateTime.now(),
      rangeEnd: end,
      files: state.files,
      keptPaths: keptPaths,
      cleanedPaths: cleanedPaths,
      disposal: method,
      vaultDir: vaultDir,
    );
    await _store.save(record);
    emit(state.copyWith(
      phase: SessionPhase.browserStep,
      lastRecord: record,
    ));
  }

  /// Called by the Browser VM after account cleanup (or skip).
  Future<void> recordBrowserStep({
    List<SiteCleanupResult> sites = const [],
    List<String> browsers = const [],
    bool historyCleared = false,
    bool skipped = false,
  }) async {
    final rec = state.lastRecord;
    if (rec == null) {
      emit(state.copyWith(phase: SessionPhase.done));
      return;
    }
    final updated = rec.copyWith(
      sitesCleared: sites,
      browsersCleaned: browsers,
      historyCleared: historyCleared,
      status: skipped ? rec.status : SessionStatus.completed,
    );
    await _store.save(updated);
    emit(state.copyWith(lastRecord: updated, phase: SessionPhase.done));
  }

  void reset() => emit(const SessionState(phase: SessionPhase.idle));

  @override
  Future<void> close() {
    _ticker?.cancel();
    _watcher.dispose();
    return super.close();
  }
}

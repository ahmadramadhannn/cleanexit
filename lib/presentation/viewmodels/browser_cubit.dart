// ignore_for_file: prefer_initializing_formals

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/models.dart';
import '../../data/services/browser_detector.dart';
import '../../data/services/chromium_cleanup_service.dart';

class BrowserState extends Equatable {
  final bool detecting;
  final List<BrowserApp> detected;

  /// Per browser id: sites with activity in the session range.
  final Map<String, List<SiteActivity>> sites;
  final Map<String, bool> running;
  final Set<String> scanned;

  /// Browser currently being inspected (expanded card).
  final String? activeBrowserId;

  /// Domains selected for cookie cleanup, across browsers.
  final Set<String> selectedDomains;

  final bool clearHistory;
  final bool busy;
  final String? statusText;
  final List<SiteCleanupResult>? outcomes;
  final int historyRemoved;
  final String? error;

  const BrowserState({
    this.detecting = false,
    this.detected = const [],
    this.sites = const {},
    this.running = const {},
    this.scanned = const {},
    this.activeBrowserId,
    this.selectedDomains = const {},
    this.clearHistory = true,
    this.busy = false,
    this.statusText,
    this.outcomes,
    this.historyRemoved = 0,
    this.error,
  });

  BrowserState copyWith({
    bool? detecting,
    List<BrowserApp>? detected,
    Map<String, List<SiteActivity>>? sites,
    Map<String, bool>? running,
    Set<String>? scanned,
    Object? activeBrowserId = _unset,
    Set<String>? selectedDomains,
    bool? clearHistory,
    bool? busy,
    String? statusText,
    Object? outcomes = _unset,
    int? historyRemoved,
    Object? error = _unset,
  }) {
    return BrowserState(
      detecting: detecting ?? this.detecting,
      detected: detected ?? this.detected,
      sites: sites ?? this.sites,
      running: running ?? this.running,
      scanned: scanned ?? this.scanned,
      activeBrowserId: identical(activeBrowserId, _unset)
          ? this.activeBrowserId
          : activeBrowserId as String?,
      selectedDomains: selectedDomains ?? this.selectedDomains,
      clearHistory: clearHistory ?? this.clearHistory,
      busy: busy ?? this.busy,
      statusText: statusText,
      outcomes: identical(outcomes, _unset)
          ? this.outcomes
          : outcomes as List<SiteCleanupResult>?,
      historyRemoved: historyRemoved ?? this.historyRemoved,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }

  @override
  List<Object?> get props => [
        detecting, detected, sites, running, scanned, activeBrowserId,
        selectedDomains, clearHistory, busy, statusText, outcomes,
        historyRemoved, error,
      ];
}

class _Unset {
  const _Unset();
}

const Object _unset = _Unset();

class BrowserCubit extends Cubit<BrowserState> {
  final BrowserDetector _detector;
  final ChromiumCleanupService _chromium;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String sessionId;

  BrowserCubit({
    required BrowserDetector detector,
    required ChromiumCleanupService chromium,
    required this.rangeStart,
    required this.rangeEnd,
    required this.sessionId,
  })  : _detector = detector,
        _chromium = chromium,
        super(const BrowserState());

  Future<void> load() async {
    emit(state.copyWith(detecting: true, error: null));
    try {
      final apps = await _detector.detect();
      if (isClosed) return;
      emit(state.copyWith(
        detecting: false,
        detected: apps.where((a) => a.isDetected).toList(),
        activeBrowserId:
            apps.where((a) => a.isDetected).isNotEmpty ? null : null,
      ));
      if (state.detected.isNotEmpty) {
        await inspect(state.detected.first);
      }
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(detecting: false, error: '$e'));
    }
  }

  /// Scans one browser's profiles for range activity.
  Future<void> inspect(BrowserApp app) async {
    emit(state.copyWith(busy: true, statusText: 'Reading ${app.displayName}…'));
    try {
      final result = await _chromium.scanBrowser(
        app: app,
        start: rangeStart,
        end: rangeEnd,
      );
      if (isClosed) return;
      final sites = Map<String, List<SiteActivity>>.from(state.sites);
      final running = Map<String, bool>.from(state.running);
      final scanned = Set<String>.from(state.scanned);
      sites[app.defId.name] = result.mergedSites;
      running[app.defId.name] = result.running;
      scanned.add(app.defId.name);

      // Pre-select domains with cookies — those are the live logins.
      final selected = Set<String>.from(state.selectedDomains);
      for (final s in result.mergedSites) {
        if (s.hasCookies) selected.add(s.domain);
      }

      emit(state.copyWith(
        busy: false,
        statusText: null,
        sites: sites,
        running: running,
        scanned: scanned,
        selectedDomains: selected,
        activeBrowserId: app.defId.name,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, statusText: null, error: '$e'));
    }
  }

  void selectBrowser(String browserId) =>
      emit(state.copyWith(activeBrowserId: browserId));

  void toggleDomain(String domain) {
    final next = Set<String>.from(state.selectedDomains);
    if (!next.add(domain)) next.remove(domain);
    emit(state.copyWith(selectedDomains: next));
  }

  void selectAllDomains() {
    final next = Set<String>.from(state.selectedDomains);
    for (final s in state.sites[state.activeBrowserId] ?? const []) {
      next.add(s.domain);
    }
    emit(state.copyWith(selectedDomains: next));
  }

  void clearDomainSelection() => emit(state.copyWith(selectedDomains: {}));

  void toggleClearHistory() =>
      emit(state.copyWith(clearHistory: !state.clearHistory));

  bool get anyBrowserRunning =>
      state.running.values.any((r) => r);

  /// Executes cookie cleanup (+ optional history purge) on every scanned
  /// browser that owns at least one selected domain.
  Future<void> execute() async {
    emit(state.copyWith(busy: true, statusText: 'Cleaning accounts…',
        error: null, outcomes: null, historyRemoved: 0));
    try {
      final allOutcomes = <SiteCleanupResult>[];
      final cleanedBrowsers = <String>[];
      var historyRemoved = 0;

      for (final app in state.detected) {
        final browserSites = state.sites[app.defId.name] ?? const [];
        final own = state.selectedDomains
            .where((d) => browserSites.any((s) => s.domain == d))
            .toList();
        if (own.isEmpty) continue;

        if (state.running[app.defId.name] ?? false) {
          throw BrowserRunningException(app.displayName);
        }

        if (own.isNotEmpty) {
          final res = await _chromium.clearSiteData(
            app: app,
            domains: own,
            sessionId: sessionId,
          );
          allOutcomes.addAll(res);
          cleanedBrowsers.add(app.displayName);
        }

        if (state.clearHistory) {
          historyRemoved += await _chromium.clearHistoryInRange(
            app: app,
            start: rangeStart,
            end: rangeEnd,
            sessionId: sessionId,
          );
          if (!cleanedBrowsers.contains(app.displayName)) {
            cleanedBrowsers.add(app.displayName);
          }
        }
      }

      emit(state.copyWith(
        busy: false,
        statusText: null,
        outcomes: allOutcomes,
        historyRemoved: historyRemoved,
      ));
    } on BrowserRunningException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, statusText: null, error: e.toString()));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, statusText: null, error: '$e'));
    }
  }
}

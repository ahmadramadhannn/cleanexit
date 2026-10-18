// ignore_for_file: prefer_initializing_formals

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/models.dart';
import '../../data/services/browser_account_service.dart';
import '../../data/services/browser_account_store.dart';
import '../../data/services/chromium_cleanup_service.dart';

class AccountsState extends Equatable {
  final bool loading;

  /// Accounts detected in the most recent scan.
  final List<BrowserAccount> signedIn;

  /// Accounts recorded earlier but NOT detected in the most recent scan —
  /// the monitoring history ("you signed this out / it disappeared").
  final List<BrowserAccount> previouslySeen;

  final bool busy;
  final String? statusText;
  final String? error;

  const AccountsState({
    this.loading = false,
    this.signedIn = const [],
    this.previouslySeen = const [],
    this.busy = false,
    this.statusText,
    this.error,
  });

  AccountsState copyWith({
    bool? loading,
    List<BrowserAccount>? signedIn,
    List<BrowserAccount>? previouslySeen,
    bool? busy,
    String? statusText,
    String? error,
  }) {
    return AccountsState(
      loading: loading ?? this.loading,
      signedIn: signedIn ?? this.signedIn,
      previouslySeen: previouslySeen ?? this.previouslySeen,
      busy: busy ?? this.busy,
      statusText: statusText,
      error: error,
    );
  }

  int get total => signedIn.length + previouslySeen.length;

  @override
  List<Object?> get props =>
      [loading, signedIn, previouslySeen, busy, statusText, error];
}

/// ViewModel behind the Accounts tab: scans the browsers' preference files,
/// records every signed-in account over time, and can log every website in
/// a profile out by wiping that profile's cookies (vault-backed-up first).
class AccountsCubit extends Cubit<AccountsState> {
  final BrowserAccountService _service;
  final BrowserAccountStore _store;
  final ChromiumCleanupService _chromium;
  final String Function() _newSessionId;

  /// When the latest scan ran — everything recorded but not seen in this
  /// scan is "previously seen".
  DateTime? _lastScanAt;

  AccountsCubit({
    required BrowserAccountService service,
    required BrowserAccountStore store,
    required ChromiumCleanupService chromium,
    required String Function() newSessionId,
  })  : _service = service,
        _store = store,
        _chromium = chromium,
        _newSessionId = newSessionId,
        super(const AccountsState());

  /// Scans the browsers' preference files. [force] = true re-scans even if
  /// a scan already ran this app session (rail tab, manual refresh);
  /// force = false only triggers the FIRST scan (dashboard banner).
  Future<void> load({bool force = true}) async {
    if (!force && _lastScanAt != null) return;
    emit(state.copyWith(loading: true, error: null));
    try {
      final scanned = await _service.scan();
      final records = _store.upsertScan(scanned);
      if (isClosed) return;
      _lastScanAt = DateTime.now();

      final current = <BrowserAccount>[];
      final earlier = <BrowserAccount>[];
      for (final r in records) {
        final stillThere =
            scanned.any((s) => s.recordKey == r.recordKey);
        (stillThere ? current : earlier).add(r);
      }
      current.sort(_byBrowserThenProfile);
      earlier.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

      emit(state.copyWith(
        loading: false,
        signedIn: current,
        previouslySeen: earlier,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, error: 'Account scan failed: $e'));
    }
  }

  /// Wipes every cookie of the profile the account lives in. Cookie
  /// deletion is what actually signs websites out; the browser-level
  /// profile sign-in has to be removed in the browser's own settings.
  Future<void> logOutProfile(BrowserAccount account) async {
    if (state.busy) return;
    if (account.browserKey == 'firefox') {
      // Firefox stores cookies in a different schema (moz_cookies); wiping
      // them with the Chromium engine would corrupt nothing but do nothing
      // either — so the action is refused with a clear message instead.
      emit(state.copyWith(
        error: 'Firefox cookie cleanup is not supported yet — sign out '
            'from the Firefox menu for now.',
      ));
      return;
    }
    emit(state.copyWith(
      busy: true,
      statusText: 'Signing websites out of ${account.browserName}…',
      error: null,
    ));
    try {
      final profileRoot = _profileRootFor(account);
      final result = await _chromium.clearAllCookiesForProfile(
        browserKey: account.browserKey,
        browserName: account.browserName,
        profileDirPath: profileRoot,
        profileName: account.profileDir,
        sessionId: _newSessionId(),
      );
      if (isClosed) return;
      await load();
      if (isClosed) return;
      emit(state.copyWith(
        busy: false,
        statusText: result.success
            ? 'Removed ${result.cookiesRemoved} cookie(s) — websites in '
                '${account.profileLabel} are signed out.'
            : 'Could not finish: ${result.error}',
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, statusText: null, error: '$e'));
    }
  }

  /// Forget a history record (e.g. the account was signed out long ago and
  /// the user does not care anymore).
  void forget(BrowserAccount account) {
    _store.forget(account.recordKey);
    emit(state.copyWith(
      previouslySeen: state.previouslySeen
          .where((a) => a.recordKey != account.recordKey)
          .toList(),
    ));
  }

  void clearToast() =>
      emit(state.copyWith(statusText: null, error: null));

  /// Best-effort reconstruction of the profile's absolute directory from
  /// the browser's standard user-data location.
  String _profileRootFor(BrowserAccount account) {
    // Firefox records are relative to its own profile roots.
    if (account.browserKey == 'firefox') {
      return account.profileDir; // not used for cookie wipes today
    }
    return _chromium.profileDirFor(account.browserKey, account.profileDir);
  }

  static int _byBrowserThenProfile(BrowserAccount a, BrowserAccount b) {
    final byBrowser = a.browserName.compareTo(b.browserName);
    if (byBrowser != 0) return byBrowser;
    return a.profileDir.compareTo(b.profileDir);
  }
}

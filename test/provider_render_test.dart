import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:cleanexit/data/models/models.dart';
import 'package:cleanexit/data/services/browser_account_service.dart';
import 'package:cleanexit/data/services/browser_account_store.dart';
import 'package:cleanexit/data/services/browser_detector.dart';
import 'package:cleanexit/data/services/chromium_cleanup_service.dart';
import 'package:cleanexit/data/services/disposal_service.dart';
import 'package:cleanexit/data/services/file_scanner_service.dart';
import 'package:cleanexit/data/services/file_watcher_service.dart';
import 'package:cleanexit/data/services/os_trash_service.dart';
import 'package:cleanexit/data/services/session_store.dart';
import 'package:cleanexit/data/services/settings_store.dart';
import 'package:cleanexit/data/services/vault_service.dart';
import 'package:cleanexit/di.dart';
import 'package:cleanexit/presentation/screens/accounts_screen.dart';
import 'package:cleanexit/presentation/screens/browser_cleanup_view.dart';
import 'package:cleanexit/presentation/screens/settings_screen.dart';
import 'package:cleanexit/presentation/screens/trash_screen.dart';
import 'package:cleanexit/presentation/viewmodels/accounts_cubit.dart';
import 'package:cleanexit/presentation/viewmodels/session_cubit.dart';
import 'package:cleanexit/presentation/viewmodels/settings_cubit.dart';
import 'package:cleanexit/presentation/viewmodels/trash_cubit.dart';

/// Regression suite for the "Could not find the correct
/// `Provider<SomeState>`" crash family.
///
/// Account cards, browser cards and trash tiles once called
/// `context.watch<SomeState>()` — a STATE-type provider lookup that
/// `BlocProvider<SomeCubit>` never satisfies. Every screen rendered fine
/// while its list was empty, then crashed the moment one item existed.
/// These tests pump each screen WITH a populated list, so the crash can
/// never ship silently again.
void main() {
  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('cleanexit_provider_test_');
    Services.appSupportPath = tmp.path;
    Services.vault = VaultService(p.join(tmp.path, 'vault'));
    Services.disposal = DisposalService(Services.vault);
    Services.sessions = SessionStore(p.join(tmp.path, 'sessions'));
    Services.settingsStore = SettingsStore(p.join(tmp.path, 'settings.json'));
    Services.settings = Services.settingsStore.load();
    Services.scanner = FileScannerService();
    Services.watcher = FileWatcherService();
    Services.browserDetector = BrowserDetector();
    Services.chromium = ChromiumCleanupService(Services.vault);
    Services.accountScanner = const BrowserAccountService();
    Services.accountStore = BrowserAccountStore(p.join(tmp.path, 'accounts'));
    Services.osTrash = const OsTrashService();
  });

  tearDownAll(() {
    tmp.deleteSync(recursive: true);
  });

  testWidgets(
    'Accounts tab renders a signed-in account card (no Provider<AccountsState> crash)',
    (tester) async {
      final account = BrowserAccount(
        browserKey: 'chrome',
        browserName: 'Google Chrome',
        profileDir: 'Default',
        profileLabel: 'Default',
        email: 'jane@example.com',
        fullName: 'Jane Doe',
        source: 'chromium-local-state',
        firstSeen: DateTime(2026, 10, 18, 9),
        lastSeen: DateTime(2026, 10, 18, 9),
      );
      Services.settings = const AppSettings(
        roots: [],
        preferredBrowsers: ['chrome'],
      );

      final cubit = AccountsCubit(
        service: _StubAccountService(account),
        store: Services.accountStore,
        chromium: Services.chromium,
        newSessionId: () => 'test-session',
      );
      await cubit.load();
      addTearDown(cubit.close);

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: const MaterialApp(home: Scaffold(body: AccountsScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.textContaining('Google Chrome'), findsWidgets);
      expect(find.textContaining('Watching'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Trash tab renders an item tile (no Provider<TrashState> crash)',
    (tester) async {
      final cubit = TrashCubit(trash: _StubTrash());
      await cubit.refresh();
      addTearDown(cubit.close);

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: const MaterialApp(home: Scaffold(body: TrashScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('notes.txt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Account-cleanup step renders a browser card (no Provider<BrowserState> crash)',
    (tester) async {
      Services.settings = const AppSettings(
        roots: [],
        preferredBrowsers: ['chrome'],
      );
      Services.browserDetector = _StubDetector();
      Services.chromium = _StubChromium();

      final sessionCubit = SessionCubit(
        scanner: Services.scanner,
        watcher: Services.watcher,
        store: Services.sessions,
      );
      addTearDown(sessionCubit.close);

      await tester.pumpWidget(
        BlocProvider.value(
          value: sessionCubit,
          child: const MaterialApp(home: Scaffold(body: BrowserCleanupView())),
        ),
      );
      await tester.pumpAndSettle();

      // The stubbed browser card is expanded and shows the site list header.
      expect(find.text('Google Chrome'), findsOneWidget);
      expect(find.text('Select all'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Settings renders the Preferred browsers section for every browser',
    (tester) async {
      // Tall surface — the Preferred browsers section sits below the fold
      // of the default 800x600 test viewport and ListView builds lazily.
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Services.settings = Services.settingsStore.load(); // default: empty
      final cubit = SettingsCubit();
      addTearDown(cubit.close);

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(Services.settings.preferredBrowsers, isEmpty);
      expect(find.text('PREFERRED BROWSERS'), findsOneWidget);
      for (final name in [
        'Google Chrome',
        'Microsoft Edge',
        'Brave',
        'Vivaldi',
        'Opera',
        'Chromium',
        'Firefox',
      ]) {
        expect(find.text(name), findsOneWidget, reason: '$name checkbox row');
      }
      expect(find.text('No browsers watched yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // NOTE: toggle behaviour is a PLAIN async test on purpose. Inside
  // testWidgets (FakeAsync), the awaited settings-file write in
  // SettingsCubit._persist never completes, so the cubit's post-save emit
  // never runs and back-to-back toggles observe stale state. Real async
  // here exercises the same code path the app uses.
  test('SettingsCubit toggles persist in canonical browser order', () async {
    Services.settings = Services.settingsStore.load(); // default: empty
    final cubit = SettingsCubit();

    await cubit.togglePreferredBrowser('firefox', true);
    await cubit.togglePreferredBrowser('chrome', true);
    // Canonical order, not insertion order: chrome sorts before firefox.
    expect(Services.settings.preferredBrowsers, ['chrome', 'firefox']);

    await cubit.togglePreferredBrowser('chrome', false);
    expect(Services.settings.preferredBrowsers, ['firefox']);

    await cubit.clearPreferredBrowsers();
    expect(Services.settings.preferredBrowsers, isEmpty);
    expect(Services.settings.hasBrowserChoice, isFalse);

    await cubit.close();
  });
}

class _StubAccountService extends BrowserAccountService {
  final BrowserAccount account;
  _StubAccountService(this.account);

  @override
  Future<List<BrowserAccount>> scan({Set<String>? onlyBrowserIds}) async =>
      [account];
}

class _StubTrash extends OsTrashService {
  @override
  Future<List<TrashItem>> list() async => [
        const TrashItem(
          id: '/tmp/trash/files/notes.txt',
          name: 'notes.txt',
          originalPath: '/home/u/notes.txt',
          isDir: false,
          sizeLabel: '1.2 KB',
        ),
      ];

  @override
  Future<void> restore(TrashItem item) async {}

  @override
  Future<void> deleteForever(TrashItem item) async {}

  @override
  Future<int> emptyAll() async => 0;
}

class _StubDetector extends BrowserDetector {
  @override
  Future<List<BrowserApp>> detect({Set<String>? onlyIds}) async => [
        const BrowserApp(
          defId: BrowserDefId.chrome,
          displayName: 'Google Chrome',
          dataRoot: '/stub/chrome',
          profiles: [
            BrowserProfile(
              name: 'Default',
              dirPath: '/stub/chrome/Default',
              cookiesPath: '/stub/chrome/Default/Network/Cookies',
              historyPath: '/stub/chrome/Default/History',
            ),
          ],
          processNames: ['chrome'],
        ),
      ];
}

class _StubChromium extends ChromiumCleanupService {
  _StubChromium() : super(_noVault());

  static VaultService _noVault() {
    // Only touched by write paths; the render test never writes.
    return VaultService(Directory.systemTemp.createTempSync('ce_stub_vault_').path);
  }

  @override
  Future<BrowserScanResult> scanBrowser({
    required BrowserApp app,
    required DateTime start,
    required DateTime end,
  }) async {
    return BrowserScanResult(app, false, const []);
  }
}

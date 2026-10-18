import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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
import 'package:cleanexit/presentation/screens/home_screen.dart';
import 'package:cleanexit/presentation/screens/home_shell.dart';
import 'package:cleanexit/presentation/viewmodels/accounts_cubit.dart';
import 'package:cleanexit/presentation/viewmodels/history_cubit.dart';
import 'package:cleanexit/presentation/viewmodels/session_cubit.dart';
import 'package:cleanexit/presentation/viewmodels/settings_cubit.dart';
import 'package:cleanexit/presentation/viewmodels/trash_cubit.dart';
import 'package:cleanexit/presentation/widgets/common.dart';
import 'package:cleanexit/startup_failure_screen.dart';

/// Regression suite for the "blank panel" bug family.
///
/// The dashboard once rendered permanently blank because a
/// CrossAxisAlignment.stretch Row sat directly inside a ListView
/// (infinite-height layout crash), and an AnimatedSwitcher could leave
/// panes at opacity 0. These tests pin both behaviours:
/// dashboard content must be visible on the FIRST frame.
void main() {
  setUpAll(() async {
    // Manual service assembly against throwaway directories —
    // path_provider has no real value inside widget tests.
    final tmp = await Directory.systemTemp.createTemp('cleanexit_shell_test_');
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
    Services.accountStore =
        BrowserAccountStore(p.join(tmp.path, 'accounts'));
    Services.osTrash = const OsTrashService();
  });

  Widget host({required Widget child}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SessionCubit>(
          create: (_) => SessionCubit(
            scanner: Services.scanner,
            watcher: Services.watcher,
            store: Services.sessions,
          ),
        ),
        BlocProvider<HistoryCubit>(
          create: (_) => HistoryCubit(
            store: Services.sessions,
            vault: Services.vault,
          ),
        ),
        BlocProvider<AccountsCubit>(
          create: (_) => AccountsCubit(
            service: Services.accountScanner,
            store: Services.accountStore,
            chromium: Services.chromium,
            newSessionId: newSessionId,
          ),
        ),
        BlocProvider<TrashCubit>(
          create: (_) => TrashCubit(trash: Services.osTrash),
        ),
        BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets(
    'dashboard renders its action cards on the very first frame',
    (tester) async {
      await tester.pumpWidget(host(child: const HomeScreen()));

      // Deliberately NOT pumpAndSettle: the content must not depend on
      // animation frames ever being scheduled.
      expect(find.text('Start a watched session'), findsOneWidget);
      expect(find.text('Clean up past activity'), findsOneWidget);
      expect(find.text('MONITORED FOLDERS'), findsOneWidget);
    },
  );

  testWidgets('rail navigation swaps to History and Settings panes',
      (tester) async {
    await tester.pumpWidget(host(child: const HomeShell()));

    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.pump(); // one for the swap, one for the refresh emit
    expect(find.text('No sessions recorded yet.'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(find.text('MONITORED FOLDERS'), findsOneWidget);
  });

  testWidgets('CeErrorCard renders the exception instead of a grey box',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CeErrorCard(
          details: FlutterErrorDetails(
            exception: StateError('boom-render-test'),
            library: 'test',
          ),
        ),
      ),
    );

    expect(find.textContaining('boom-render-test'), findsOneWidget);
    expect(
      find.text('Something went wrong rendering this panel'),
      findsOneWidget,
    );
  });

  testWidgets('StartupFailureApp explains a storage failure',
      (tester) async {
    await tester.pumpWidget(
      StartupFailureApp(error: const FileSystemException('locked', '/data')),
    );

    expect(find.text('CleanExit could not start'), findsOneWidget);
    expect(find.textContaining('locked'), findsOneWidget);
  });
}

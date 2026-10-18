import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'core/constants.dart';
import 'data/models/app_settings.dart';
import 'data/services/browser_account_service.dart';
import 'data/services/browser_account_store.dart';
import 'data/services/browser_detector.dart';
import 'data/services/chromium_cleanup_service.dart';
import 'data/services/disposal_service.dart';
import 'data/services/file_scanner_service.dart';
import 'data/services/file_watcher_service.dart';
import 'data/services/os_trash_service.dart';
import 'data/services/session_store.dart';
import 'data/services/settings_store.dart';
import 'data/services/vault_service.dart';

/// Hand-rolled service locator — the whole Model layer in one place.
/// ViewModels (BLoC cubits) pull these; Views never do (MVVM).
abstract final class Services {
  static late final String appSupportPath;

  // These are `late` (not `late final`) so tests can rewire stubs between
  // cases; production writes them exactly once in init().
  static late VaultService vault;
  static late DisposalService disposal;
  static late SessionStore sessions;
  static late SettingsStore settingsStore;
  static late AppSettings settings;
  static late FileScannerService scanner;
  static late FileWatcherService watcher;
  static late BrowserDetector browserDetector;
  static late ChromiumCleanupService chromium;
  static late BrowserAccountService accountScanner;
  static late BrowserAccountStore accountStore;
  static late OsTrashService osTrash;

  static Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    appSupportPath = dir.path;

    vault = VaultService(p.join(dir.path, 'vault'));
    disposal = DisposalService(vault);
    sessions = SessionStore(p.join(dir.path, 'sessions'));
    settingsStore = SettingsStore(p.join(dir.path, 'settings.json'));
    settings = settingsStore.load();
    scanner = FileScannerService();
    watcher = FileWatcherService();
    browserDetector = BrowserDetector();
    chromium = ChromiumCleanupService(vault);
    accountScanner = const BrowserAccountService();
    accountStore = BrowserAccountStore(dir.path);
    osTrash = const OsTrashService();
  }

  /// Everything CleanExit creates must never be scanned into itself.
  static Set<String> get excludePrefixes => {
        appSupportPath,
        vault.vaultRoot,
      };

  static List<ManagedRoot> get enabledRoots => settings.enabledRoots
      .map((r) => ManagedRoot(r.label, r.path))
      .toList();

  static Future<void> saveSettings(AppSettings next) async {
    settings = next;
    await settingsStore.save(next);
  }
}

String newSessionId() {
  final now = DateTime.now();
  final rand = Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
  final ts = now.millisecondsSinceEpoch;
  return 's-$ts-$rand';
}

import 'dart:io';

/// A top-level folder that CleanExit watches / scans for session files.
class ManagedRoot {
  final String label;
  final String path;
  final bool enabledByDefault;

  const ManagedRoot(this.label, this.path, {this.enabledByDefault = true});

  @override
  bool operator ==(Object other) => other is ManagedRoot && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// Static description of one Chromium-family browser we know how to clean.
class BrowserDef {
  final String id;
  final String displayName;
  final List<String> processNames;

  /// Directory that holds profile folders ("Default", "Profile 1", ...).
  /// For Opera this directory IS the profile.
  final String windowsUserdata;
  final String linuxUserdata;

  /// Opera keeps its databases straight in the userdata dir.
  final bool flatProfileLayout;

  const BrowserDef({
    required this.id,
    required this.displayName,
    required this.processNames,
    required this.windowsUserdata,
    required this.linuxUserdata,
    this.flatProfileLayout = false,
  });
}

abstract final class CeConstants {
  static const String appName = 'CleanExit';
  static const String tagline = 'Leave the computer like you were never here.';
  static const String version = '1.0.0';

  /// Recursion guard for folder walks.
  static const int maxScanDepth = 8;

  /// Directories that are pure noise — never scan into them.
  static const Set<String> skipDirNames = {
    'node_modules', '.git', '__pycache__', '.cache', '.cargo', '.rustup',
    '.nvm', '.venv', 'venv', '.gradle', '.m2', '.npm', '.yarn', '.pnpm-store',
    '.terraform', '.docker', '.vscode', '.idea', '\$RECYCLE.BIN',
    'System Volume Information', 'vendor', 'target', 'dist', '.next',
    '.dart_tool', '.pub-cache', '.atom', '.bundle',
  };

  /// Chromium-family browsers CleanExit knows how to clean. The engine is
  /// data-driven off this list — detection, account monitoring and cookie
  /// cleanup all iterate it. The user picks WHICH of these (plus Firefox,
  /// monitor-only) to watch in Settings → Preferred browsers; nothing is
  /// ever scanned just because it happens to be installed.
  static const List<BrowserDef> browsers = [
    BrowserDef(
      id: 'chrome',
      displayName: 'Google Chrome',
      processNames: ['chrome.exe', 'chrome'],
      windowsUserdata: r'%LOCALAPPDATA%\Google\Chrome\User Data',
      linuxUserdata: '~/.config/google-chrome',
    ),
    BrowserDef(
      id: 'edge',
      displayName: 'Microsoft Edge',
      processNames: ['msedge.exe', 'msedge'],
      windowsUserdata: r'%LOCALAPPDATA%\Microsoft\Edge\User Data',
      linuxUserdata: '~/.config/microsoft-edge',
    ),
    BrowserDef(
      id: 'brave',
      displayName: 'Brave',
      processNames: ['brave.exe', 'brave'],
      windowsUserdata: r'%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data',
      linuxUserdata: '~/.config/BraveSoftware/Brave-Browser',
    ),
    BrowserDef(
      id: 'vivaldi',
      displayName: 'Vivaldi',
      processNames: ['vivaldi.exe', 'vivaldi-bin', 'vivaldi'],
      windowsUserdata: r'%LOCALAPPDATA%\Vivaldi\User Data',
      linuxUserdata: '~/.config/vivaldi',
    ),
    BrowserDef(
      id: 'opera',
      displayName: 'Opera',
      processNames: ['opera.exe', 'opera'],
      windowsUserdata: r'%APPDATA%\Opera Software',
      linuxUserdata: '~/.config/opera',
      flatProfileLayout: true,
    ),
    BrowserDef(
      id: 'chromium',
      displayName: 'Chromium',
      processNames: ['chromium.exe', 'chromium'],
      windowsUserdata: r'%LOCALAPPDATA%\Chromium\User Data',
      linuxUserdata: '~/.config/chromium',
    ),
  ];

  /// Firefox is monitor-only for now (accounts yes, cookie wipes no — its
  /// cookie schema differs), but it IS a first-class choice in Settings.
  static const String firefoxId = 'firefox';
  static const String firefoxDisplayName = 'Firefox';

  /// Every browser the user can pick in Settings — Chromium family
  /// ([browsers]) plus monitor-only Firefox. Single source of truth for
  /// the settings UI and for validating stored preferences.
  static List<String> get selectableBrowserIds => [
        for (final b in browsers) b.id,
        firefoxId,
      ];

  static String browserDisplayName(String id) {
    if (id == firefoxId) return firefoxDisplayName;
    for (final b in browsers) {
      if (b.id == id) return b.displayName;
    }
    return id;
  }

  /// Where a browser keeps its data — shown as a hint in Settings so the
  /// user can recognize what they are enabling.
  static String? browserDataPathHint(String id) {
    if (id == firefoxId) {
      return Platform.isWindows
          ? r'%APPDATA%\Mozilla\Firefox'
          : '~/.mozilla/firefox';
    }
    for (final b in browsers) {
      if (b.id == id) {
        return Platform.isWindows ? b.windowsUserdata : b.linuxUserdata;
      }
    }
    return null;
  }

  static String get home {
    if (Platform.isWindows) {
      return Platform.environment['USERPROFILE'] ?? r'C:\Users\Public';
    }
    return Platform.environment['HOME'] ?? '/';
  }

  /// %LOCALAPPDATA% / %APPDATA% equivalents.
  static String get appDataLocal {
    if (Platform.isWindows) {
      return Platform.environment['LOCALAPPDATA'] ?? '$home\\AppData\\Local';
    }
    return '$home/.local/share';
  }

  static String get appDataRoaming {
    if (Platform.isWindows) {
      return Platform.environment['APPDATA'] ?? '$home\\AppData\\Roaming';
    }
    return '$home/.config';
  }

  static String get downloadsDir {
    if (Platform.isWindows) return '$home\\Downloads';
    return '$home/Downloads';
  }

  /// The default set of managed roots, resolved for the current OS.
  static List<ManagedRoot> defaultRoots() {
    if (Platform.isWindows) {
      return [
        ManagedRoot('Downloads', '$home\\Downloads'),
        ManagedRoot('Desktop', '$home\\Desktop'),
        ManagedRoot('Documents', '$home\\Documents'),
        ManagedRoot('Pictures', '$home\\Pictures'),
        ManagedRoot('Videos', '$home\\Videos'),
        ManagedRoot('Music', '$home\\Music'),
        ManagedRoot(
          'Temp (%TEMP%)',
          Platform.environment['TEMP'] ?? '$home\\AppData\\Local\\Temp',
          enabledByDefault: false,
        ),
      ];
    }
    return [
      ManagedRoot('Downloads', '$home/Downloads'),
      ManagedRoot('Desktop', '$home/Desktop'),
      ManagedRoot('Documents', '$home/Documents'),
      ManagedRoot('Pictures', '$home/Pictures'),
      ManagedRoot('Videos', '$home/Videos'),
      ManagedRoot('Music', '$home/Music'),
      ManagedRoot('Temp (/tmp)', '/tmp', enabledByDefault: false),
    ];
  }

  /// Expands `%VAR%` and `~` inside stored browser paths.
  static String expandPath(String p) {
    var out = p;
    if (out.startsWith('~')) {
      out = '$home${out.substring(1)}';
    }
    // Windows-style env vars, resolved from the actual environment.
    out = out.replaceAllMapped(RegExp(r'%([A-Za-z_]+)%'), (m) {
      return Platform.environment[m.group(1)] ?? m.group(0)!;
    });
    return out;
  }
}

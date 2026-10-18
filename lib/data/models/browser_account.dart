import 'package:equatable/equatable.dart';

/// One account signed into a browser on this machine — e.g. a Google
/// account inside a Chrome profile, or a Firefox Sync account.
///
/// CleanExit discovers these from the browsers' own user-preference files
/// (Chromium `Local State` / per-profile `Preferences`, Firefox
/// `signedInUser.json`) and records when it first and last saw each one,
/// so nothing logged-in can slip through unnoticed before leaving a PC.
class BrowserAccount extends Equatable {
  /// Internal browser id: chrome / brave / vivaldi / opera / firefox.
  final String browserKey;

  /// Human browser name, e.g. "Google Chrome".
  final String browserName;

  /// Profile folder name inside the browser's user-data dir.
  final String profileDir;

  /// Friendly profile label the browser shows its user.
  final String profileLabel;

  final String email;
  final String fullName;

  /// Which preference file produced this record
  /// (chromium-local-state / chromium-preferences / firefox-signed-in-user).
  final String source;

  /// First time CleanExit recorded this account on this machine.
  final DateTime firstSeen;

  /// Most recent scan that still detected this account.
  final DateTime lastSeen;

  const BrowserAccount({
    required this.browserKey,
    required this.browserName,
    required this.profileDir,
    required this.profileLabel,
    required this.email,
    required this.fullName,
    required this.source,
    required this.firstSeen,
    required this.lastSeen,
  });

  /// Stable storage key — one account per browser/profile/email triple.
  String get recordKey => '$browserKey::$profileDir::$email';

  String get displayName {
    if (fullName.trim().isNotEmpty) return fullName.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return profileLabel;
  }

  String get initial {
    final name = displayName.trim();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  BrowserAccount copyWith({
    String? profileLabel,
    String? fullName,
    String? source,
    DateTime? lastSeen,
  }) {
    return BrowserAccount(
      browserKey: browserKey,
      browserName: browserName,
      profileDir: profileDir,
      profileLabel: profileLabel ?? this.profileLabel,
      email: email,
      fullName: fullName ?? this.fullName,
      source: source ?? this.source,
      firstSeen: firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() => {
        'browserKey': browserKey,
        'browserName': browserName,
        'profileDir': profileDir,
        'profileLabel': profileLabel,
        'email': email,
        'fullName': fullName,
        'source': source,
        'firstSeen': firstSeen.millisecondsSinceEpoch,
        'lastSeen': lastSeen.millisecondsSinceEpoch,
      };

  factory BrowserAccount.fromJson(Map<String, dynamic> j) => BrowserAccount(
        browserKey: j['browserKey'] as String,
        browserName: j['browserName'] as String? ?? j['browserKey'] as String,
        profileDir: j['profileDir'] as String? ?? '',
        profileLabel: j['profileLabel'] as String? ?? '',
        email: j['email'] as String? ?? '',
        fullName: j['fullName'] as String? ?? '',
        source: j['source'] as String? ?? '',
        firstSeen:
            DateTime.fromMillisecondsSinceEpoch(j['firstSeen'] as int? ?? 0),
        lastSeen:
            DateTime.fromMillisecondsSinceEpoch(j['lastSeen'] as int? ?? 0),
      );

  @override
  List<Object?> get props => [browserKey, profileDir, email];
}

import 'package:flutter_test/flutter_test.dart';

import 'package:cleanexit/core/constants.dart';
import 'package:cleanexit/data/models/models.dart';
import 'package:cleanexit/data/services/browser_account_service.dart';

/// The user's preferred-browser choice: persistence, canonical id list, and
/// the guarantee that an EMPTY choice means "scan nothing" — never "guess".
void main() {
  group('AppSettings.preferredBrowsers', () {
    test('survives a JSON round-trip', () {
      const settings = AppSettings(
        roots: [],
        preferredBrowsers: ['chrome', 'firefox'],
      );

      final restored = AppSettings.fromJson(settings.toJson());

      expect(restored.preferredBrowsers, ['chrome', 'firefox']);
      expect(restored.hasBrowserChoice, isTrue);
    });

    test('defaults to an EMPTY choice when the key is missing', () {
      // Settings written by an older build — no preferredBrowsers yet.
      final old = AppSettings.fromJson({
        'roots': <Map<String, dynamic>>[],
        'defaultDisposal': DisposalMethod.recycle.name,
        'askDisposalEachRun': true,
      });

      expect(old.preferredBrowsers, isEmpty);
      expect(old.hasBrowserChoice, isFalse);
    });

    test('non-string entries in the stored list are dropped', () {
      final s = AppSettings.fromJson({
        'roots': <Map<String, dynamic>>[],
        'preferredBrowsers': ['chrome', 42, null, 'firefox'],
      });

      expect(s.preferredBrowsers, ['chrome', 'firefox']);
    });

    test('empty choice keeps hasBrowserChoice false', () {
      const s = AppSettings(roots: []);
      expect(s.hasBrowserChoice, isFalse);
    });
  });

  group('CeConstants selectable browser ids', () {
    test('covers every Chromium def plus monitor-only Firefox, no dupes', () {
      final ids = CeConstants.selectableBrowserIds;

      for (final defId in BrowserDefId.values) {
        expect(ids.contains(defId.name), isTrue,
            reason: '${defId.name} must be selectable');
      }
      expect(ids.contains(CeConstants.firefoxId), isTrue);
      expect(ids.toSet().length, ids.length, reason: 'no duplicates');
    });

    test('browserDisplayName resolves every selectable id', () {
      for (final id in CeConstants.selectableBrowserIds) {
        final name = CeConstants.browserDisplayName(id);
        expect(name.isNotEmpty, isTrue);
        expect(name, isNot(id),
            reason: '$id should map to a human-readable name');
      }
      expect(CeConstants.browserDisplayName('chrome'), 'Google Chrome');
      expect(CeConstants.browserDisplayName('edge'), 'Microsoft Edge');
      expect(CeConstants.browserDisplayName('firefox'), 'Firefox');
    });

    test('browserDataPathHint is non-null for every selectable id', () {
      for (final id in CeConstants.selectableBrowserIds) {
        expect(CeConstants.browserDataPathHint(id), isNotNull);
      }
    });
  });

  group('BrowserAccountService.scan selection guard', () {
    test('an EMPTY selection scans nothing — even without a filesystem hit',
        () async {
      final service = const BrowserAccountService();
      final accounts = await service.scan(onlyBrowserIds: const {});
      expect(accounts, isEmpty);
    });

    test('an unknown id set scans nothing', () async {
      final service = const BrowserAccountService();
      final accounts = await service.scan(onlyBrowserIds: {'netscape'});
      expect(accounts, isEmpty);
    });
  });

  group('BrowserAccount model keys', () {
    test('recordKey separates browsers and profiles', () {
      final now = DateTime.now();
      final chrome = BrowserAccount(
        browserKey: 'chrome',
        browserName: 'Google Chrome',
        profileDir: 'Default',
        profileLabel: 'Default',
        email: 'a@x.com',
        fullName: 'A',
        source: 'chromium-local-state',
        firstSeen: now,
        lastSeen: now,
      );
      final firefox = BrowserAccount(
        browserKey: 'firefox',
        browserName: 'Firefox',
        profileDir: 'abc.default-release',
        profileLabel: 'abc.default-release',
        email: 'b@x.com',
        fullName: 'B',
        source: 'firefox-signed-in-user',
        firstSeen: now,
        lastSeen: now,
      );

      expect(chrome.recordKey, contains('chrome'));
      expect(chrome.recordKey, isNot(firefox.recordKey));
      expect(firefox.recordKey, contains('firefox'));
    });
  });
}

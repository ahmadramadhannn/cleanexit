import 'package:flutter_test/flutter_test.dart';

import 'package:cleanexit/data/services/browser_account_service.dart';
import 'package:cleanexit/data/services/os_trash_service.dart';

/// Pure-parser coverage for the account monitor and the trash browser.
void main() {
  group('BrowserAccountService.parseLocalStateAccounts', () {
    test('extracts only signed-in Chromium profiles', () {
      const json = '''
      {
        "profile": {
          "info_cache": {
            "Default": {
              "name": "Person 1",
              "user_name": "jane@gmail.com",
              "gaia_name": "Jane Doe",
              "gaia_given_name": "Jane",
              "is_consented_primary_account": true
            },
            "Profile 1": {
              "name": "Guest-ish",
              "user_name": ""
            }
          }
        }
      }''';

      final accounts =
          BrowserAccountService.parseLocalStateAccounts(json);

      expect(accounts.length, 1);
      expect(accounts.first.profileDir, 'Default');
      expect(accounts.first.email, 'jane@gmail.com');
      expect(accounts.first.fullName, 'Jane Doe');
      expect(accounts.first.source, 'chromium-local-state');
    });

    test('returns nothing on corrupt JSON', () {
      expect(
        () => BrowserAccountService.parseLocalStateAccounts('{oops'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('BrowserAccountService.parsePreferencesAccountInfo', () {
    test('reads the account_info list of a profile Preferences file', () {
      const json = '''
      {
        "account_info": [
          {"email": "sam@example.com", "full_name": "Sam Smith",
           "given_name": "Sam"}
        ],
        "profile": {"name": "Work"}
      }''';

      final accounts = BrowserAccountService.parsePreferencesAccountInfo(
        json,
        '/home/u/.config/google-chrome/Default',
      );

      expect(accounts.length, 1);
      expect(accounts.first.profileDir, 'Default');
      expect(accounts.first.email, 'sam@example.com');
      expect(accounts.first.fullName, 'Sam Smith');
    });

    test('no account_info → no accounts', () {
      final accounts = BrowserAccountService.parsePreferencesAccountInfo(
        '{"profile": {"name": "X"}}',
        '/x/Default',
      );
      expect(accounts, isEmpty);
    });
  });

  group('BrowserAccountService.parseFirefoxSignedInUser', () {
    test('extracts the Firefox Sync account', () {
      const json = '''
      {"account": {"uid": "123", "email": "kim@example.com",
                   "displayName": "Kim K"},
       "data": {"syncedEngines": {}}}''';

      final accounts = BrowserAccountService.parseFirefoxSignedInUser(
        json,
        'abc123.default-release',
      );

      expect(accounts.length, 1);
      expect(accounts.first.profileDir, 'abc123.default-release');
      expect(accounts.first.email, 'kim@example.com');
      expect(accounts.first.fullName, 'Kim K');
      expect(accounts.first.source, 'firefox-signed-in-user');
    });

    test('signed-out profile (no account) → empty', () {
      expect(
        BrowserAccountService.parseFirefoxSignedInUser('{}', 'p'),
        isEmpty,
      );
    });
  });

  group('BrowserAccountService.parseFirefoxProfileIni', () {
    test('collects every Path entry, install + profiles, deduped', () {
      const ini = '''
[Install4F96D1932A9F858E]
Default=Profiles/abc.default-release
Locked=1

[Profile0]
Name=default
IsRelative=1
Path=Profiles/abc.default-release
Default=1

[Profile1]
Name=dev
IsRelative=1
Path=Profiles/dev.edition
''';

      final dirs = BrowserAccountService.parseFirefoxProfileIni(ini);

      expect(dirs, ['Profiles/abc.default-release', 'Profiles/dev.edition']);
    });
  });

  group('parseTrashInfo (XDG .trashinfo)', () {
    test('decodes the URL-encoded path and the deletion date', () {
      final (path, date) = parseTrashInfo(
        '[Trash Info]\n'
        'Path=/home/u/Downloads/report%20final.pdf\n'
        'DeletionDate=2026-10-18T09:30:00\n',
      );

      expect(path, '/home/u/Downloads/report final.pdf');
      expect(date, DateTime(2026, 10, 18, 9, 30));
    });

    test('missing fields → nulls, never throws', () {
      final (path, date) = parseTrashInfo('[Trash Info]\n');
      expect(path, isNull);
      expect(date, isNull);
    });
  });

  group('parseWindowsTrashDate', () {
    test('parses d/M/yyyy HH:mm locale format', () {
      expect(
        parseWindowsTrashDate('18/10/2026 09:30'),
        DateTime(2026, 10, 18, 9, 30),
      );
    });

    test('parses ISO-ish strings', () {
      expect(
        parseWindowsTrashDate('2026-10-18 09:30'),
        DateTime(2026, 10, 18, 9, 30),
      );
    });

    test('garbage → null', () {
      expect(parseWindowsTrashDate('whenever'), isNull);
      expect(parseWindowsTrashDate(''), isNull);
    });
  });
}

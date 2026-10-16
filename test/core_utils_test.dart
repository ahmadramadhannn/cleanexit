import 'package:cleanexit/core/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matchesCookieHost', () {
    test('matches bare host, dotted host, subdomains and www', () {
      expect(matchesCookieHost('google.com', 'google.com'), isTrue);
      expect(matchesCookieHost('.google.com', 'google.com'), isTrue);
      expect(matchesCookieHost('www.google.com', 'google.com'), isTrue);
      expect(matchesCookieHost('.www.google.com', 'google.com'), isTrue);
      expect(matchesCookieHost('accounts.google.com', 'google.com'), isTrue);
      expect(matchesCookieHost('GOOGLE.COM', 'google.com'), isTrue);
    });

    test('does not match look-alike or unrelated domains', () {
      expect(matchesCookieHost('notgoogle.com', 'google.com'), isFalse);
      expect(matchesCookieHost('evil-google.com', 'google.com'), isFalse);
      expect(matchesCookieHost('google.com.evil.io', 'google.com'), isFalse);
      expect(matchesCookieHost('facebook.com', 'google.com'), isFalse);
      expect(matchesCookieHost('', 'google.com'), isFalse);
      expect(matchesCookieHost('google.com', ''), isFalse);
    });

    test('handles case and stray whitespace', () {
      expect(matchesCookieHost('  .GitHub.com ', 'github.com'), isTrue);
    });
  });

  group('registrableDomain', () {
    test('reduces URLs to their registrable domain', () {
      expect(registrableDomain('https://accounts.google.com/signin'), 'google.com');
      expect(registrableDomain('http://www.reddit.com/r/privacy'), 'reddit.com');
      expect(registrableDomain('github.com'), 'github.com');
      expect(registrableDomain('.youtube.com'), 'youtube.com');
      expect(registrableDomain('https://news.ycombinator.com'), 'ycombinator.com');
    });

    test('keeps two-part public suffixes together', () {
      expect(registrableDomain('https://www.google.co.uk'), 'google.co.uk');
      expect(registrableDomain('mail.university.ac.id'), 'university.ac.id');
      expect(registrableDomain('shop.com.au'), 'shop.com.au');
    });

    test('handles ports, fragments and odd hosts', () {
      expect(registrableDomain('https://example.com:8080/x#y'), 'example.com');
      expect(registrableDomain('192.168.1.10'), '192.168.1.10');
      expect(registrableDomain('localhost'), 'localhost');
    });
  });

  group('chromium epoch conversion', () {
    test('round-trips through the 1601 epoch', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final back = chromiumToDart(dartToChromium(now));
      // Sub-second tolerance from the toLocal()/toUtc() dance.
      expect(back.isBefore(now.add(const Duration(seconds: 1))), isTrue);
      expect(back.isAfter(now.subtract(const Duration(seconds: 1))), isTrue);
    });

    test('known epoch value maps correctly', () {
      // 2024-01-01T00:00:00Z == 13348540800000000 µs since 1601.
      final dt = chromiumToDart(13348540800000000);
      expect(dt.toUtc().toString(), startsWith('2024-01-01 00:00:00'));
    });
  });

  group('formatters', () {
    test('formatBytes stays human', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2.0 KB');
      expect(formatBytes(1024 * 1024 * 5), '5.0 MB');
      expect(formatBytes(1024 * 1024 * 1024 * 2), '2.00 GB');
    });

    test('formatClock pads correctly', () {
      expect(formatClock(const Duration(minutes: 5, seconds: 3)), '05:03');
      expect(
        formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });
  });
}

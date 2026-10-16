import 'package:intl/intl.dart';

/// Pure helpers shared across layers. Everything here must be unit-testable
/// without any Flutter binding.

String formatBytes(num bytes) {
  if (bytes < 0) return '?';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(gb < 10 ? 2 : 1)} GB';
}

String formatDurationShort(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
  return '${s}s';
}

String formatClock(Duration d) {
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final h = d.inHours;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

final DateFormat _dtFmt = DateFormat('dd MMM yyyy, HH:mm');
final DateFormat _timeFmt = DateFormat('HH:mm:ss');
final DateFormat _dayFmt = DateFormat('dd MMM');

String formatDateTime(DateTime dt) => _dtFmt.format(dt);
String formatTime(DateTime dt) => _timeFmt.format(dt);
String formatDay(DateTime dt) => _dayFmt.format(dt);

/// Human "11:00 – 11:25" style range label.
String formatRangeLabel(DateTime start, DateTime end) {
  if (start.day == end.day && start.month == end.month && start.year == end.year) {
    return '${DateFormat('HH:mm').format(start)} – ${DateFormat('HH:mm').format(end)}';
  }
  return '${formatDateTime(start)} → ${formatDateTime(end)}';
}

/// ---------------------------------------------------------------------------
/// Chromium timestamp helpers.
/// Chromium stores times as microseconds since 1601-01-01 UTC.
/// ---------------------------------------------------------------------------

const int _chromiumEpochDeltaUs = 11644473600000000;

DateTime chromiumToDart(int microsecondsSince1601) {
  return DateTime.fromMicrosecondsSinceEpoch(
    microsecondsSince1601 - _chromiumEpochDeltaUs,
    isUtc: true,
  ).toLocal();
}

int dartToChromium(DateTime dt) {
  return dt.toUtc().microsecondsSinceEpoch + _chromiumEpochDeltaUs;
}

/// ---------------------------------------------------------------------------
/// Cookie host matching.
/// A Chromium cookie row has `host_key` like "google.com", ".google.com",
/// "www.google.com" or ".www.google.com". We consider the row as belonging
/// to [domain] when the host equals the domain, equals "." + domain, or ends
/// with "." + domain (subdomain of it).
/// ---------------------------------------------------------------------------

bool matchesCookieHost(String hostKey, String domain) {
  final h = _normalizeHost(hostKey);
  final d = _normalizeHost(domain);
  if (h.isEmpty || d.isEmpty) return false;
  return h == d || h == '.$d' || h.endsWith('.$d');
}

String _normalizeHost(String host) => host.trim().toLowerCase().stripDot();

extension on String {
  String stripDot() =>
      startsWith('.') ? substring(1) : this;
}

/// Best-effort "registrable domain" guess from a URL or bare host.
/// Handles the common two-part public suffixes; good enough for v1.
const Set<String> _twoPartSuffixes = {
  'co.uk', 'org.uk', 'ac.uk', 'gov.uk', 'net.uk',
  'co.id', 'or.id', 'web.id', 'go.id', 'ac.id', 'my.id', 'biz.id',
  'com.au', 'net.au', 'org.au', 'co.jp', 'ne.jp', 'or.jp', 'ac.jp', 'go.jp',
  'co.kr', 'or.kr', 'co.nz', 'net.nz', 'org.nz', 'co.za', 'org.za',
  'com.br', 'com.mx', 'com.ar', 'com.tr', 'com.cn', 'com.hk', 'com.tw',
  'com.sg', 'com.my', 'co.in', 'net.in', 'org.in', 'co.th', 'com.ph',
  'com.vn', 'co.il', 'com.sa', 'com.eg', 'com.ng', 'com.pk', 'com.bd',
};

String registrableDomain(String urlOrHost) {
  var host = urlOrHost.trim().toLowerCase();
  // Pull host out of a URL if needed.
  final schemeIdx = host.indexOf('://');
  if (schemeIdx >= 0) {
    host = host.substring(schemeIdx + 3);
  }
  final slash = host.indexOf(RegExp(r'[/?#:]'));
  if (slash > 0) host = host.substring(0, slash);
  host = host.stripDot();
  if (host.startsWith('www.')) host = host.substring(4);
  if (host.isEmpty || RegExp(r'^[\d.:\[\]]+$').hasMatch(host)) return host;

  final labels = host.split('.');
  if (labels.length <= 2) return host;

  final last2 = labels.sublist(labels.length - 2).join('.');
  if (_twoPartSuffixes.contains(last2) && labels.length >= 3) {
    return labels.sublist(labels.length - 3).join('.');
  }
  return last2;
}

/// Extracts a host from an arbitrary URL-ish string (empty on failure).
String hostFromUrl(String url) {
  try {
    final stripped = url.contains('://') ? url.split('://')[1] : url;
    final slash = stripped.indexOf(RegExp(r'[/?#:]'));
    final host = slash > 0 ? stripped.substring(0, slash) : stripped;
    return host.toLowerCase();
  } catch (_) {
    return '';
  }
}

/// A website that shows account/browsing activity inside the session range,
/// aggregated across a browser's profiles.
class SiteActivity {
  final String domain;

  /// Cookie rows for this domain whose creation or last-access falls in range.
  final int cookieCount;

  /// History visits to this domain in range.
  final int visitCount;

  final DateTime? lastVisit;

  const SiteActivity({
    required this.domain,
    required this.cookieCount,
    required this.visitCount,
    this.lastVisit,
  });

  bool get hasCookies => cookieCount > 0;

  SiteActivity copyWith({
    String? domain,
    int? cookieCount,
    int? visitCount,
    DateTime? lastVisit,
  }) {
    return SiteActivity(
      domain: domain ?? this.domain,
      cookieCount: cookieCount ?? this.cookieCount,
      visitCount: visitCount ?? this.visitCount,
      lastVisit: lastVisit ?? this.lastVisit,
    );
  }
}

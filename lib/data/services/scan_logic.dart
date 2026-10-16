import 'dart:io';

import '../models/models.dart';

/// Pure, host-testable scan logic shared by the scanner service.
abstract final class ScanLogic {
  static bool isWithinRange(DateTime start, DateTime end, DateTime t) {
    return !t.isBefore(start) && !t.isAfter(end);
  }

  /// On Windows `FileStat.changed` carries the real creation time;
  /// on Linux there is no creation timestamp, so callers pass
  /// `creationKnown: false` and we refuse to claim "Created".
  static bool creationTimeKnown() => Platform.isWindows;

  static FileOrigin classifyOrigin({
    required bool isUnderDownloadsRoot,
    required bool createdInRange,
    required bool creationKnown,
  }) {
    if (isUnderDownloadsRoot) return FileOrigin.downloaded;
    if (creationKnown && createdInRange) return FileOrigin.created;
    return FileOrigin.modified;
  }

  /// What timestamp groups a file into the session range?
  /// Modified OR created inside the range qualifies.
  static bool fileBelongsToRange({
    required FileStat stat,
    required DateTime start,
    required DateTime end,
  }) {
    final modified = stat.modified;
    final created =
        creationTimeKnown() ? stat.changed : stat.modified;
    return isWithinRange(start, end, modified) ||
        isWithinRange(start, end, created);
  }
}

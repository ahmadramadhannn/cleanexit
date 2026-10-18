/// One item sitting in the operating system's trash (XDG Trash on Linux /
/// Recycle Bin on Windows), as shown by CleanExit's Trash tab.
class TrashItem {
  /// Stable identifier used for restore/delete actions.
  /// Linux: the absolute path inside Trash/files.
  /// Windows: the $R… filesystem path of the recycled entry.
  final String id;

  final String name;

  /// Where the item lived before it was deleted (best effort).
  final String? originalPath;

  final DateTime? deletedAt;

  final bool isDir;

  /// Human-readable size ("12.4 KB") — Windows reports a formatted label.
  final String sizeLabel;

  const TrashItem({
    required this.id,
    required this.name,
    this.originalPath,
    this.deletedAt,
    this.isDir = false,
    this.sizeLabel = '',
  });
}

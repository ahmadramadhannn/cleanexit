import 'package:equatable/equatable.dart';

/// How we believe the file appeared during the session.
enum FileOrigin {
  /// Landed under a Downloads root — i.e. downloaded.
  downloaded,

  /// Creation timestamp falls inside the session range.
  created,

  /// Only the modification timestamp falls inside the range.
  modified,

  /// Seen live by the filesystem watcher.
  watched,
}

extension FileOriginX on FileOrigin {
  String get label => switch (this) {
        FileOrigin.downloaded => 'Downloaded',
        FileOrigin.created => 'Created',
        FileOrigin.modified => 'Modified',
        FileOrigin.watched => 'Watched',
      };

  static FileOrigin fromJson(String v) => FileOrigin.values
      .firstWhere((o) => o.name == v, orElse: () => FileOrigin.modified);
}

/// One file (or folder) the app attributes to a session.
class TrackedFile extends Equatable {
  final String path;
  final String name;
  final bool isDir;
  final int sizeBytes;
  final DateTime modified;
  final DateTime created;
  final String rootLabel;
  final FileOrigin origin;

  const TrackedFile({
    required this.path,
    required this.name,
    required this.isDir,
    required this.sizeBytes,
    required this.modified,
    required this.created,
    required this.rootLabel,
    required this.origin,
  });

  String get extension {
    final idx = name.lastIndexOf('.');
    return (idx <= 0 || idx == name.length - 1) ? '' : name.substring(idx + 1).toLowerCase();
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'isDir': isDir,
        'size': sizeBytes,
        'modified': modified.millisecondsSinceEpoch,
        'created': created.millisecondsSinceEpoch,
        'root': rootLabel,
        'origin': origin.name,
      };

  factory TrackedFile.fromJson(Map<String, dynamic> j) => TrackedFile(
        path: j['path'] as String,
        name: j['name'] as String,
        isDir: (j['isDir'] as bool?) ?? false,
        sizeBytes: (j['size'] as num?)?.toInt() ?? 0,
        modified: DateTime.fromMillisecondsSinceEpoch(j['modified'] as int? ?? 0),
        created: DateTime.fromMillisecondsSinceEpoch(j['created'] as int? ?? 0),
        rootLabel: (j['root'] as String?) ?? '',
        origin: FileOriginX.fromJson(j['origin'] as String? ?? 'modified'),
      );

  @override
  List<Object?> get props => [path];
}

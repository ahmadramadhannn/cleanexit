/// Files parked in CleanExit's vault, with enough info to put them back.
class VaultItem {
  final String originalPath;
  final String vaultPath;
  final String name;
  final int sizeBytes;
  final DateTime deletedAt;

  const VaultItem({
    required this.originalPath,
    required this.vaultPath,
    required this.name,
    required this.sizeBytes,
    required this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
        'originalPath': originalPath,
        'vaultPath': vaultPath,
        'name': name,
        'sizeBytes': sizeBytes,
        'deletedAt': deletedAt.millisecondsSinceEpoch,
      };

  factory VaultItem.fromJson(Map<String, dynamic> j) => VaultItem(
        originalPath: j['originalPath'] as String,
        vaultPath: j['vaultPath'] as String,
        name: j['name'] as String,
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
        deletedAt:
            DateTime.fromMillisecondsSinceEpoch(j['deletedAt'] as int? ?? 0),
      );
}

class VaultManifest {
  final String sessionId;
  final DateTime createdAt;
  final List<VaultItem> items;

  const VaultManifest({
    required this.sessionId,
    required this.createdAt,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory VaultManifest.fromJson(Map<String, dynamic> j) => VaultManifest(
        sessionId: j['sessionId'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int? ?? 0),
        items: ((j['items'] as List?) ?? const [])
            .map((i) => VaultItem.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}

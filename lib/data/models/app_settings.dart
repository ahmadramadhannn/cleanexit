import 'disposal_method.dart';

/// One managed root with its user-controlled enabled flag.
class RootConfig {
  final String label;
  final String path;
  final bool enabled;

  const RootConfig({
    required this.label,
    required this.path,
    required this.enabled,
  });

  RootConfig copyWith({bool? enabled}) => RootConfig(
        label: label,
        path: path,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() =>
      {'label': label, 'path': path, 'enabled': enabled};

  factory RootConfig.fromJson(Map<String, dynamic> j) => RootConfig(
        label: j['label'] as String,
        path: j['path'] as String,
        enabled: (j['enabled'] as bool?) ?? true,
      );
}

class AppSettings {
  final List<RootConfig> roots;
  final DisposalMethod defaultDisposal;
  final bool askDisposalEachRun;

  const AppSettings({
    required this.roots,
    this.defaultDisposal = DisposalMethod.recycle,
    this.askDisposalEachRun = true,
  });

  List<RootConfig> get enabledRoots =>
      roots.where((r) => r.enabled).toList(growable: false);

  AppSettings copyWith({
    List<RootConfig>? roots,
    DisposalMethod? defaultDisposal,
    bool? askDisposalEachRun,
  }) {
    return AppSettings(
      roots: roots ?? this.roots,
      defaultDisposal: defaultDisposal ?? this.defaultDisposal,
      askDisposalEachRun: askDisposalEachRun ?? this.askDisposalEachRun,
    );
  }

  Map<String, dynamic> toJson() => {
        'roots': roots.map((r) => r.toJson()).toList(),
        'defaultDisposal': defaultDisposal.name,
        'askDisposalEachRun': askDisposalEachRun,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        roots: ((j['roots'] as List?) ?? const [])
            .map((r) => RootConfig.fromJson(r as Map<String, dynamic>))
            .toList(),
        defaultDisposal:
            DisposalMethodX.fromJson(j['defaultDisposal'] as String? ?? 'recycle'),
        askDisposalEachRun: (j['askDisposalEachRun'] as bool?) ?? true,
      );
}

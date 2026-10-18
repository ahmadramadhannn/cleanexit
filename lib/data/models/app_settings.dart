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

  /// Browser ids (see [CeConstants.selectableBrowserIds]) the user explicitly
  /// chose to have watched for signed-in accounts and offered in the account
  /// cleanup step. EMPTY means "the user has not chosen yet" — and until they
  /// do, CleanExit deliberately watches NOTHING: browsers are never guessed.
  final List<String> preferredBrowsers;

  const AppSettings({
    required this.roots,
    this.defaultDisposal = DisposalMethod.recycle,
    this.askDisposalEachRun = true,
    this.preferredBrowsers = const [],
  });

  List<RootConfig> get enabledRoots =>
      roots.where((r) => r.enabled).toList(growable: false);

  bool get hasBrowserChoice => preferredBrowsers.isNotEmpty;

  AppSettings copyWith({
    List<RootConfig>? roots,
    DisposalMethod? defaultDisposal,
    bool? askDisposalEachRun,
    List<String>? preferredBrowsers,
  }) {
    return AppSettings(
      roots: roots ?? this.roots,
      defaultDisposal: defaultDisposal ?? this.defaultDisposal,
      askDisposalEachRun: askDisposalEachRun ?? this.askDisposalEachRun,
      preferredBrowsers: preferredBrowsers ?? this.preferredBrowsers,
    );
  }

  Map<String, dynamic> toJson() => {
        'roots': roots.map((r) => r.toJson()).toList(),
        'defaultDisposal': defaultDisposal.name,
        'askDisposalEachRun': askDisposalEachRun,
        'preferredBrowsers': preferredBrowsers,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        roots: ((j['roots'] as List?) ?? const [])
            .map((r) => RootConfig.fromJson(r as Map<String, dynamic>))
            .toList(),
        defaultDisposal:
            DisposalMethodX.fromJson(j['defaultDisposal'] as String? ?? 'recycle'),
        askDisposalEachRun: (j['askDisposalEachRun'] as bool?) ?? true,
        preferredBrowsers: ((j['preferredBrowsers'] as List?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );
}

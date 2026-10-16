/// One profile folder of a detected browser ("Default", "Profile 1", ...).
class BrowserProfile {
  final String name;
  final String dirPath;
  final String? cookiesPath;
  final String? historyPath;

  const BrowserProfile({
    required this.name,
    required this.dirPath,
    this.cookiesPath,
    this.historyPath,
  });
}

/// A browser installed on this machine, with the profiles CleanExit found.
class BrowserApp {
  final BrowserDefId defId;
  final String displayName;
  final String dataRoot;
  final List<BrowserProfile> profiles;
  final List<String> processNames;

  const BrowserApp({
    required this.defId,
    required this.displayName,
    required this.dataRoot,
    required this.profiles,
    required this.processNames,
  });

  bool get isDetected => profiles.isNotEmpty;
}

/// Ids we use internally; maps to [CeConstants.browsers] definitions.
enum BrowserDefId { chrome, brave, vivaldi, opera }

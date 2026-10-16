import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';
import '../../core/constants.dart';

class SettingsStore {
  final String filePath;

  SettingsStore(this.filePath);

  AppSettings load() {
    final f = File(filePath);
    if (f.existsSync()) {
      try {
        return AppSettings.fromJson(
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
        );
      } catch (_) {
        // fall through to defaults
      }
    }
    return _defaults();
  }

  Future<void> save(AppSettings settings) async {
    final f = File(filePath);
    await f.parent.create(recursive: true);
    final tmp = File('$filePath.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
    if (f.existsSync()) f.deleteSync();
    await tmp.rename(filePath);
  }

  AppSettings _defaults() {
    return AppSettings(
      roots: CeConstants.defaultRoots()
          .map(
            (r) => RootConfig(
              label: r.label,
              path: r.path,
              enabled: r.enabledByDefault,
            ),
          )
          .toList(),
    );
  }
}

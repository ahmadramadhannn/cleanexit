import 'package:flutter/material.dart';

import 'app.dart';
import 'di.dart';
import 'presentation/widgets/common.dart';
import 'startup_failure_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Assigned exactly once, here in main() — never during build.
  // A custom builder keeps a broken subtree from rendering as an
  // opaque grey box; it shows a branded card explaining the error.
  ErrorWidget.builder = (details) => CeErrorCard(details: details);

  try {
    await Services.init();
  } catch (error) {
    // Storage could not be opened (permissions, disk, sandboxing…).
    // Show a full-screen explanation instead of crashing on launch.
    runApp(StartupFailureApp(error: error));
    return;
  }

  runApp(const CleanExitApp());
}

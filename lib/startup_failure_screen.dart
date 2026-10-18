import 'package:flutter/material.dart';

import 'core/theme.dart';

/// Shown when the storage layer cannot be initialised at all (locked app
/// directory, broken profile, full disk…). Explains what happened instead
/// of dying with an opaque crash on launch.
class StartupFailureApp extends StatelessWidget {
  final Object error;

  const StartupFailureApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CleanExit',
      debugShowCheckedModeBanner: false,
      theme: buildCleanExitTheme(),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 54,
                    color: CeColors.warning,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'CleanExit could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'The private storage CleanExit needs (session records, '
                    'vault, settings) could not be opened. Nothing was '
                    'deleted — this is purely a startup problem.\n\n'
                    'Check that your user profile directory is writable and '
                    'that no security software is blocking the app, then '
                    'start CleanExit again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: CeColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        '$error',
                        style: CeText.mono(
                          size: 11.5,
                          color: CeColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

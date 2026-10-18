import 'package:cleanexit/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CleanExit theme builds with the Nord frost dark identity', () {
    final theme = buildCleanExitTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, const Color(0xFF88C0D0)); // frost
    expect(theme.scaffoldBackgroundColor, const Color(0xFF2E3440)); // polar night
  });
}

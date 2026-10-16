import 'package:cleanexit/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CleanExit theme builds with dark+teal identity', () {
    final theme = buildCleanExitTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, const Color(0xFF2DD4BF));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF14181D));
  });
}

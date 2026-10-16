import 'dart:io';

import 'package:cleanexit/data/services/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmpRoot;
  late VaultService vault;

  setUp(() {
    tmpRoot = Directory.systemTemp.createTempSync('cleanexit_test_');
    vault = VaultService(p.join(tmpRoot.path, 'vault'));
  });

  tearDown(() {
    if (tmpRoot.existsSync()) tmpRoot.deleteSync(recursive: true);
  });

  test('stash moves files, writes a manifest, restoreAll puts them back', () async {
    final work = Directory(p.join(tmpRoot.path, 'work'))..createSync();
    final f1 = File(p.join(work.path, 'report.pdf'))
      ..writeAsStringSync('hello pdf');
    final f2 = File(p.join(work.path, 'notes.txt'))
      ..writeAsStringSync('notes');

    final manifest = await vault.stash(
      sessionId: 's-test',
      paths: [f1.path, f2.path],
    );

    expect(manifest.items, hasLength(2));
    expect(f1.existsSync(), isFalse, reason: 'file must be moved, not copied');
    expect(f2.existsSync(), isFalse);

    final readBack = vault.readManifest('s-test');
    expect(readBack, isNotNull);
    expect(readBack!.items, hasLength(2));

    final restored = await vault.restoreAll('s-test');
    expect(restored, 2);
    expect(f1.existsSync(), isTrue);
    expect(f1.readAsStringSync(), 'hello pdf');
    expect(f2.existsSync(), isTrue);

    // Fully restored → vault folder for the session is cleaned up.
    expect(vault.sessionDir('s-test').existsSync(), isFalse);
  });

  test('restore picks a suffixed name when the target was recreated', () async {
    final work = Directory(p.join(tmpRoot.path, 'work2'))..createSync();
    final f = File(p.join(work.path, 'a.txt'))..writeAsStringSync('v1');
    await vault.stash(sessionId: 's-collision', paths: [f.path]);

    // The same path appears again (new content) before we restore.
    File(p.join(work.path, 'a.txt')).writeAsStringSync('v2');

    await vault.restoreAll('s-collision');
    final restored = File(p.join(work.path, 'a (restored).txt'));
    expect(restored.existsSync(), isTrue);
    expect(restored.readAsStringSync(), 'v1');
    expect(File(p.join(work.path, 'a.txt')).readAsStringSync(), 'v2');
  });

  test('purgeSession wipes the parked content permanently', () async {
    final work = Directory(p.join(tmpRoot.path, 'work3'))..createSync();
    final f = File(p.join(work.path, 'secret.bin'))
      ..writeAsStringSync('top secret');
    await vault.stash(sessionId: 's-purge', paths: [f.path]);

    final vaultPath =
        vault.readManifest('s-purge')!.items.first.vaultPath;
    expect(File(vaultPath).existsSync(), isTrue);

    final count = await vault.purgeSession('s-purge');
    expect(count, 1);
    expect(File(vaultPath).existsSync(), isFalse);
    expect(vault.readManifest('s-purge'), isNull);
  });

  test('totalBytes reflects parked content', () async {
    expect(vault.totalBytes(), 0);
    final work = Directory(p.join(tmpRoot.path, 'work4'))..createSync();
    await File(p.join(work.path, 'x.bin'))
        .writeAsBytes(List.filled(4096, 7));
    await vault.stash(sessionId: 's-size', paths: [p.join(work.path, 'x.bin')]);
    expect(vault.totalBytes(), greaterThanOrEqualTo(4096));
  });
}

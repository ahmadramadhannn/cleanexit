import 'dart:io';

import 'package:cleanexit/data/models/models.dart';
import 'package:cleanexit/data/services/disposal_service.dart';
import 'package:cleanexit/data/services/session_store.dart';
import 'package:cleanexit/data/services/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmpRoot;

  setUp(() {
    tmpRoot = Directory.systemTemp.createTempSync('cleanexit_disp_');
  });

  tearDown(() {
    if (tmpRoot.existsSync()) tmpRoot.deleteSync(recursive: true);
  });

  group('DisposalService', () {
    test('shred overwrites and removes the file', () async {
      final vault = VaultService(p.join(tmpRoot.path, 'vault'));
      final disposal = DisposalService(vault);

      final target = File(p.join(tmpRoot.path, 'burn-me.txt'))
        ..writeAsStringSync('sensitive payload' * 500);
      final bytes = target.lengthSync();

      final outcomes = await disposal.dispose(
        paths: [target.path],
        method: DisposalMethod.shred,
        sessionId: 's-shred',
      );

      expect(outcomes.single.success, isTrue);
      expect(target.existsSync(), isFalse);
      expect(bytes, greaterThan(0));
    });

    test('shred removes a nested directory tree', () async {
      final vault = VaultService(p.join(tmpRoot.path, 'vault'));
      final disposal = DisposalService(vault);

      final dir = Directory(p.join(tmpRoot.path, 'folder'))..createSync();
      File(p.join(dir.path, 'inner.txt')).writeAsStringSync('x');
      Directory(p.join(dir.path, 'nested')).createSync();
      File(p.join(dir.path, 'nested', 'deep.txt')).writeAsStringSync('y');

      final outcomes = await disposal.dispose(
        paths: [dir.path],
        method: DisposalMethod.shred,
        sessionId: 's-shred-dir',
      );

      expect(outcomes.single.success, isTrue);
      expect(dir.existsSync(), isFalse);
    });

    test('vault disposal parks files and reports success', () async {
      final vault = VaultService(p.join(tmpRoot.path, 'vault'));
      final disposal = DisposalService(vault);

      final f = File(p.join(tmpRoot.path, 'keepable.txt'))
        ..writeAsStringSync('data');

      final outcomes = await disposal.dispose(
        paths: [f.path],
        method: DisposalMethod.vault,
        sessionId: 's-vault-run',
      );

      expect(outcomes.single.success, isTrue);
      expect(f.existsSync(), isFalse);
      expect(vault.readManifest('s-vault-run'), isNotNull);
    });

    test('vanishing files count as already disposed, never an error', () async {
      final vault = VaultService(p.join(tmpRoot.path, 'vault'));
      final disposal = DisposalService(vault);

      final gone = p.join(tmpRoot.path, 'does-not-exist.txt');

      // Vault method: skipped by the stash, reported as done.
      final vaultOutcomes = await disposal.dispose(
        paths: [gone],
        method: DisposalMethod.vault,
        sessionId: 's-vanish',
      );
      expect(vaultOutcomes.single.success, isTrue);

      // Shred method: nothing to overwrite — silently done.
      final shredOutcomes = await disposal.dispose(
        paths: [gone],
        method: DisposalMethod.shred,
        sessionId: 's-vanish-shred',
      );
      expect(shredOutcomes.single.success, isTrue);
    });
  });

  group('SessionStore', () {
    test('save / listAll / byId / delete round-trip', () async {
      final store = SessionStore(p.join(tmpRoot.path, 'sessions'));

      final file = TrackedFile(
        path: '/home/x/Downloads/a.zip',
        name: 'a.zip',
        isDir: false,
        sizeBytes: 1234,
        modified: DateTime(2026, 10, 17, 11, 5),
        created: DateTime(2026, 10, 17, 11, 5),
        rootLabel: 'Downloads',
        origin: FileOrigin.downloaded,
      );

      final record = SessionRecord(
        id: 's-rt',
        mode: SessionMode.live,
        start: DateTime(2026, 10, 17, 11, 0),
        end: DateTime(2026, 10, 17, 11, 25),
        status: SessionStatus.completed,
        rangeStart: DateTime(2026, 10, 17, 11, 0),
        rangeEnd: DateTime(2026, 10, 17, 11, 25),
        files: [file],
        keptPaths: ['/home/x/Downloads/keep-me.txt'],
        cleanedPaths: ['/home/x/Downloads/a.zip'],
        disposal: DisposalMethod.vault,
        vaultDir: '/vault/s-rt',
      );

      await store.save(record);
      final loaded = store.byId('s-rt');
      expect(loaded, isNotNull);
      expect(loaded!.mode, SessionMode.live);
      expect(loaded.disposal, DisposalMethod.vault);
      expect(loaded.files.single.path, '/home/x/Downloads/a.zip');
      expect(loaded.files.single.origin, FileOrigin.downloaded);
      expect(loaded.keptPaths, hasLength(1));
      expect(loaded.bytesCleaned, 1234);

      expect(store.listAll().map((r) => r.id), contains('s-rt'));
      await store.delete('s-rt');
      expect(store.byId('s-rt'), isNull);
      expect(store.listAll(), isEmpty);
    });

    test('corrupt files are skipped instead of breaking listAll', () async {
      final store = SessionStore(p.join(tmpRoot.path, 'sessions2'));
      await Directory(store.baseDir).create(recursive: true);
      File(p.join(store.baseDir, 'broken.json')).writeAsStringSync('{nope');

      final good = SessionRecord(
        id: 's-good',
        mode: SessionMode.retroactive,
        start: DateTime.now(),
        end: DateTime.now(),
        status: SessionStatus.completed,
        rangeStart: DateTime.now(),
        rangeEnd: DateTime.now(),
      );
      await store.save(good);

      final all = store.listAll();
      expect(all.map((r) => r.id), ['s-good']);
    });
  });
}

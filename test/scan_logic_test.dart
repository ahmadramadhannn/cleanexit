import 'package:cleanexit/data/models/models.dart';
import 'package:cleanexit/data/services/scan_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScanLogic.isWithinRange', () {
    final start = DateTime(2026, 10, 17, 11, 0);
    final end = DateTime(2026, 10, 17, 11, 25);

    test('accepts boundaries inclusively', () {
      expect(ScanLogic.isWithinRange(start, end, start), isTrue);
      expect(ScanLogic.isWithinRange(start, end, end), isTrue);
    });

    test('accepts in-between and rejects outside', () {
      expect(
        ScanLogic.isWithinRange(start, end, DateTime(2026, 10, 17, 11, 10)),
        isTrue,
      );
      expect(
        ScanLogic.isWithinRange(start, end, DateTime(2026, 10, 17, 10, 59)),
        isFalse,
      );
      expect(
        ScanLogic.isWithinRange(start, end, DateTime(2026, 10, 17, 11, 26)),
        isFalse,
      );
    });
  });

  group('ScanLogic.classifyOrigin', () {
    test('Downloads root wins over everything', () {
      expect(
        ScanLogic.classifyOrigin(
          isUnderDownloadsRoot: true,
          createdInRange: true,
          creationKnown: true,
        ),
        FileOrigin.downloaded,
      );
    });

    test('created only when the OS gives real creation times', () {
      expect(
        ScanLogic.classifyOrigin(
          isUnderDownloadsRoot: false,
          createdInRange: true,
          creationKnown: true,
        ),
        FileOrigin.created,
      );
      // Linux has no creation timestamp — never claim "Created".
      expect(
        ScanLogic.classifyOrigin(
          isUnderDownloadsRoot: false,
          createdInRange: true,
          creationKnown: false,
        ),
        FileOrigin.modified,
      );
    });
  });

  group('DisposalMethod json round-trip', () {
    test('maps every value and falls back safely', () {
      for (final m in DisposalMethod.values) {
        expect(DisposalMethodX.fromJson(m.jsonValue), m);
      }
      expect(
        DisposalMethodX.fromJson('bogus'),
        DisposalMethod.recycle,
      );
    });
  });
}

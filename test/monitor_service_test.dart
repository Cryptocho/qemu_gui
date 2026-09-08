import 'package:flutter_test/flutter_test.dart';
import 'package:qemu_gui/services/monitor_service.dart';

void main() {
  group('parseCpuJiffies', () {
    test('parses utime+stime after the comm field with spaces', () {
      // utime=140 stime=40 => 180
      const stat =
          '4820 (qemu-system-x86 64) R 4811 4820 4811 0 -1 4194560 0 0 0 0 '
          '140 40 0 0 0 0 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0';
      expect(parseCpuJiffies(stat), 180);
    });

    test('returns null for truncated content', () {
      expect(parseCpuJiffies('123 (qemu) S 1'), isNull);
      expect(parseCpuJiffies(''), isNull);
    });
  });

  group('parseVmRssKb', () {
    test('parses VmRSS from a status file body', () {
      const status = '''
Name:\tqemu-system-x86
VmPeak:\t 1024000 kB
VmRSS:\t   36252 kB
Threads:\t12
''';
      expect(parseVmRssKb(status), 36252);
    });

    test('returns null when VmRSS is absent', () {
      expect(parseVmRssKb('Name:\tqemu\n'), isNull);
    });
  });

  group('computeCpuPercent', () {
    test('100% of one core on a single-processor host', () {
      final pct = computeCpuPercent(
        100,
        const Duration(seconds: 1),
        numProcessors: 1,
      );
      expect(pct, closeTo(100, 0.001));
    });

    test('normalizes by processor count', () {
      final pct = computeCpuPercent(
        100,
        const Duration(seconds: 1),
        numProcessors: 4,
      );
      expect(pct, closeTo(25, 0.001));
    });

    test('clamps above 100% (multi-core process on 1 proc)', () {
      final pct = computeCpuPercent(
        400,
        const Duration(seconds: 1),
        numProcessors: 1,
      );
      expect(pct, 100.0);
    });

    test('returns null for non-positive elapsed time', () {
      expect(
        computeCpuPercent(10, const Duration(milliseconds: 0)),
        isNull,
      );
    });
  });

  group('computeBytesPerSecond', () {
    test('divides delta by elapsed seconds', () {
      final bps = computeBytesPerSecond(2048, const Duration(seconds: 2));
      expect(bps, closeTo(1024, 0.001));
    });

    test('zero delta yields 0.0', () {
      expect(computeBytesPerSecond(0, const Duration(seconds: 1)), 0.0);
    });

    test('returns null before elapsed time is measurable', () {
      expect(computeBytesPerSecond(100, const Duration()), isNull);
    });
  });
}

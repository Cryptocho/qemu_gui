import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'qmp_client.dart';

/// Number of samples kept per metric (1 s cadence => ~2 minutes of history).
const int kMonitorSamples = 120;

/// CLK_TCK of Linux (jiffies per second used by `/proc/<pid>/stat`).
const int kClockTicksPerSec = 100;

/// CPU load in percent for a whole QEMU process, derived from two
/// `/proc/<pid>/stat` samples (utime+stime delta). Returns null when the
/// elapsed time is invalid.
double? computeCpuPercent(
  int deltaJiffies,
  Duration elapsed, {
  int clockTicksPerSec = kClockTicksPerSec,
  int numProcessors = 1,
}) {
  final seconds = elapsed.inMilliseconds / 1000;
  if (seconds <= 0 || numProcessors <= 0) return null;
  final pct = (deltaJiffies / (clockTicksPerSec * seconds)) * 100 / numProcessors;
  return pct.clamp(0.0, 100.0);
}

/// Throughput in bytes per second between two cumulative samples.
/// Returns null before the elapsed time is measurable.
double? computeBytesPerSecond(int deltaBytes, Duration elapsed) {
  final seconds = elapsed.inMilliseconds / 1000;
  if (seconds <= 0) return null;
  if (deltaBytes <= 0) return 0.0;
  return deltaBytes / seconds;
}

/// utime+stime jiffies from `/proc/<pid>/stat`. The comm field may contain
/// spaces, so parsing starts after the last ')'.
int? parseCpuJiffies(String content) {
  final close = content.lastIndexOf(')');
  if (close < 0) return null;
  final rest = content.substring(close + 1).trim().split(RegExp(r'\s+'));
  if (rest.length < 13) return null;
  final utime = int.tryParse(rest[11]);
  final stime = int.tryParse(rest[12]);
  if (utime == null || stime == null) return null;
  return utime + stime;
}

/// VmRSS in kB from `/proc/<pid>/status`.
int? parseVmRssKb(String content) {
  for (final line in content.split('\n')) {
    if (line.startsWith('VmRSS:')) {
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 2) return int.tryParse(parts[1]);
    }
  }
  return null;
}

class _VmMonitor {
  _VmMonitor(this.pid, this.socketPath);

  final int pid;
  final String socketPath;

  Timer? timer;
  QmpClient? qmp;
  bool qmpConnected = false;
  // Flips to false once query-balloon reports DeviceNotActive (no balloon
  // device / driver), so we stop polling it every second.
  bool balloonAvailable = true;
  bool busy = false;

  int? prevCpuJiffies;
  DateTime prevCpuSample = DateTime.now();
  int? prevReadBytes;
  int? prevWriteBytes;
  DateTime prevIoSample = DateTime.now();

  final List<double> cpu = [];
  final List<double> rssMB = [];
  final List<double> balloonMB = [];
  final List<double> readBps = [];
  final List<double> writeBps = [];

  void trim() {
    for (final list in [cpu, rssMB, balloonMB, readBps, writeBps]) {
      while (list.length > kMonitorSamples) {
        list.removeAt(0);
      }
    }
  }
}

/// Polls per-VM performance metrics once per second and exposes sliding
/// window series for the monitor page.
///
/// Data sources:
/// - CPU: whole QEMU process time from `/proc/<pid>/stat` (libvirt-style; the
///   QMP stats API does not expose process CPU time).
/// - Host memory: VmRSS from `/proc/<pid>/status`.
/// - Guest memory: QMP query-balloon (needs an explicit virtio-balloon device
///   and a guest balloon driver for meaningful values).
/// - Disk IO: QMP query-blockstats deltas.
class MonitorService extends ChangeNotifier {
  final Map<String, _VmMonitor> _monitors = {};

  static const int sampleCount = kMonitorSamples;

  bool isMonitoring(String vmId) => _monitors[vmId]?.timer != null;

  /// False when the VM has no monitor state or no usable balloon device.
  bool isBalloonAvailable(String vmId) =>
      _monitors[vmId]?.balloonAvailable ?? false;

  List<double> cpuSeries(String vmId) => _series(_monitors[vmId]?.cpu);
  List<double> rssSeries(String vmId) => _series(_monitors[vmId]?.rssMB);
  List<double> balloonSeries(String vmId) => _series(_monitors[vmId]?.balloonMB);
  List<double> readSeries(String vmId) => _series(_monitors[vmId]?.readBps);
  List<double> writeSeries(String vmId) => _series(_monitors[vmId]?.writeBps);

  double? latestCpu(String vmId) => _latest(_monitors[vmId]?.cpu);
  double? latestRssMB(String vmId) => _latest(_monitors[vmId]?.rssMB);
  double? latestBalloonMB(String vmId) => _latest(_monitors[vmId]?.balloonMB);
  double? latestReadBps(String vmId) => _latest(_monitors[vmId]?.readBps);
  double? latestWriteBps(String vmId) => _latest(_monitors[vmId]?.writeBps);

  void attach(String vmId, int pid, String socketPath) {
    detach(vmId);
    final monitor = _VmMonitor(pid, socketPath);
    _monitors[vmId] = monitor;
    monitor.timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tick(vmId, monitor),
    );
    _tick(vmId, monitor);
  }

  /// Stops sampling for [vmId]; the collected series stay readable so the
  /// monitor page can show the last known state after the VM exits.
  void detach(String vmId) {
    final monitor = _monitors[vmId];
    if (monitor == null) return;
    monitor.timer?.cancel();
    monitor.timer = null;
    monitor.qmp?.disconnect();
    monitor.qmp = null;
    monitor.qmpConnected = false;
    notifyListeners();
  }

  Future<void> _tick(String vmId, _VmMonitor monitor) async {
    if (monitor.busy) return;
    monitor.busy = true;
    try {
      final now = DateTime.now();

      // CPU (whole process)
      final stat = await _readFile('/proc/${monitor.pid}/stat');
      if (stat != null) {
        final jiffies = parseCpuJiffies(stat);
        if (jiffies != null) {
          final prev = monitor.prevCpuJiffies;
          if (prev != null) {
            final pct = computeCpuPercent(
              jiffies - prev,
              now.difference(monitor.prevCpuSample),
              numProcessors: Platform.numberOfProcessors,
            );
            if (pct != null) monitor.cpu.add(pct);
          }
          monitor.prevCpuJiffies = jiffies;
          monitor.prevCpuSample = now;
        }
      }

      // Host memory
      final status = await _readFile('/proc/${monitor.pid}/status');
      if (status != null) {
        final kb = parseVmRssKb(status);
        if (kb != null) monitor.rssMB.add(kb / 1024.0);
      }

      // QMP: balloon + block IO
      monitor.qmp ??= QmpClient(monitor.socketPath);
      if (!monitor.qmpConnected) {
        try {
          await monitor.qmp!.connect(timeout: const Duration(milliseconds: 700));
          monitor.qmpConnected = true;
        } catch (_) {
          monitor.qmpConnected = false;
        }
      }
      if (monitor.qmpConnected && monitor.balloonAvailable) {
        try {
          final bytes = await monitor.qmp!.queryBalloon();
          if (bytes != null) monitor.balloonMB.add(bytes / (1024 * 1024));
        } on QmpException catch (e) {
          if (e.errorClass == 'DeviceNotActive') {
            monitor.balloonAvailable = false;
          }
        } catch (_) {
          // transient error, keep the last state
        }
      }
      if (monitor.qmpConnected) {
        try {
          final stats = await monitor.qmp!.queryBlockstats();
          var read = 0;
          var write = 0;
          for (final s in stats) {
            read += s.readBytes;
            write += s.writeBytes;
          }
          if (monitor.prevReadBytes != null) {
            final elapsed = now.difference(monitor.prevIoSample);
            final rb = computeBytesPerSecond(read - monitor.prevReadBytes!, elapsed);
            final wb = computeBytesPerSecond(write - monitor.prevWriteBytes!, elapsed);
            if (rb != null) monitor.readBps.add(rb);
            if (wb != null) monitor.writeBps.add(wb);
          }
          monitor.prevReadBytes = read;
          monitor.prevWriteBytes = write;
          monitor.prevIoSample = now;
        } catch (_) {
          // transient error, keep the last state
        }
      }

      monitor.trim();
      notifyListeners();
    } finally {
      monitor.busy = false;
    }
  }

  Future<String?> _readFile(String path) async {
    try {
      return await File(path).readAsString();
    } catch (_) {
      return null; // process gone or /proc unavailable
    }
  }

  static List<double> _series(List<double>? source) =>
      source == null ? const [] : List.unmodifiable(source);

  static double? _latest(List<double>? source) {
    if (source == null || source.isEmpty) return null;
    return source.last;
  }

  @override
  void dispose() {
    for (final vmId in List<String>.from(_monitors.keys)) {
      detach(vmId);
    }
    super.dispose();
  }
}

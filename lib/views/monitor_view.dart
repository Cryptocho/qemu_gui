import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vm_config.dart';
import '../services/monitor_service.dart';
import '../services/vm_service.dart';
import '../theme/arc_dark_theme.dart';

/// Live performance page for a running VM: CPU, memory and disk IO trends.
class MonitorView extends StatelessWidget {
  const MonitorView({super.key, required this.vm});

  final VMConfig vm;

  static const _rssColor = ArcDarkTheme.primary;
  static const _cpuColor = ArcDarkTheme.primary;
  static const _readColor = ArcDarkTheme.primary;
  static const _balloonColor = Color(0xFFA9DC76);
  static const _writeColor = Color(0xFFEF6C00);
  static const _bottomLabels = {0: '-2m', 60: '-1m'};

  @override
  Widget build(BuildContext context) {
    final vmService = context.watch<VMService>();
    final monitor = context.watch<MonitorService>();
    final running = vmService.isVMRunning(vm.id);

    return Scaffold(
      appBar: AppBar(title: Text('Monitor: ${vm.name}')),
      body: !running
          ? Center(
              child: Text(
                '${vm.name} is not running. Start the VM to collect performance data.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: _chartCard(
                      context,
                      title: 'CPU',
                      valueText: _fmtPercent(monitor.latestCpu(vm.id)),
                      child: _lineChart(
                        series: monitor.cpuSeries(vm.id),
                        color: _cpuColor,
                        minY: 0,
                        maxY: 100,
                        leftInterval: 25,
                        leftLabel: (v) => '${v.toStringAsFixed(0)}%',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _chartCard(
                      context,
                      title: 'Memory',
                      valueText: _memValueText(monitor),
                      child: _lineChart(
                        series: monitor.rssSeries(vm.id),
                        color: _rssColor,
                        secondarySeries: monitor.isBalloonAvailable(vm.id)
                            ? monitor.balloonSeries(vm.id)
                            : null,
                        secondaryColor: _balloonColor,
                        minY: 0,
                        maxY: vm.memoryMB <= 0 ? 64 : vm.memoryMB.toDouble(),
                        leftInterval: vm.memoryMB <= 0 ? 16 : vm.memoryMB / 4,
                        leftLabel: _fmtMemAxis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _chartCard(
                      context,
                      title: 'Disk IO',
                      valueText: _ioValueText(monitor),
                      child: _buildIoChart(monitor),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildIoChart(MonitorService monitor) {
    final read = monitor.readSeries(vm.id);
    final write = monitor.writeSeries(vm.id);
    var maxY = 0.0;
    for (final v in read) {
      if (v > maxY) maxY = v;
    }
    for (final v in write) {
      if (v > maxY) maxY = v;
    }
    maxY = maxY <= 0 ? 1.0 : maxY * 1.25;
    return _lineChart(
      series: read,
      color: _readColor,
      secondarySeries: write,
      secondaryColor: _writeColor,
      minY: 0,
      maxY: maxY,
      leftInterval: maxY / 4,
      leftLabel: _fmtSpeedAxis,
    );
  }

  Widget _chartCard(
    BuildContext context, {
    required String title,
    required String valueText,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(ArcDarkTheme.radius),
        border: Border.all(color: scheme.outline),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: ArcDarkTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  valueText,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ArcDarkTheme.textDisabled,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _lineChart({
    required List<double> series,
    required Color color,
    List<double>? secondarySeries,
    Color? secondaryColor,
    required double minY,
    required double maxY,
    required double leftInterval,
    required String Function(double) leftLabel,
  }) {
    // Points are appended in order, so index = x. The window slides once the
    // series is full (oldest point is dropped), giving a scrolling trend.
    List<FlSpot> toSpots(List<double> data) => [
          for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i]),
        ];

    final bars = <LineChartBarData>[
      LineChartBarData(
        spots: toSpots(series),
        isCurved: true,
        preventCurveOverShooting: true,
        barWidth: 2,
        color: color,
        dotData: const FlDotData(show: false),
      ),
      if (secondarySeries != null)
        LineChartBarData(
          spots: toSpots(secondarySeries),
          isCurved: true,
          preventCurveOverShooting: true,
          barWidth: 2,
          color: secondaryColor,
          dotData: const FlDotData(show: false),
        ),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: MonitorService.sampleCount - 1,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => const FlLine(
            color: ArcDarkTheme.outline,
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: leftInterval,
              getTitlesWidget: (value, meta) =>
                  _axisTitle(leftLabel(value), meta),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: 60,
              getTitlesWidget: (value, meta) =>
                  _axisTitle(_bottomLabels[value.round()], meta),
            ),
          ),
        ),
        lineBarsData: bars,
      ),
    );
  }

  Widget _axisTitle(String? text, TitleMeta meta) {
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return SideTitleWidget(
      meta: meta,
      child: Text(
        text,
        style: const TextStyle(
          color: ArcDarkTheme.textDisabled,
          fontSize: 9,
        ),
      ),
    );
  }

  // ---- value formatting -------------------------------------------------

  String _fmtPercent(double? v) => v == null ? '—' : '${v.toStringAsFixed(0)}%';

  String _fmtMemAxis(double v) => '${v.round()}M';

  String _fmtSpeedAxis(double bytesPerSec) {
    if (bytesPerSec >= 1048576) {
      return '${(bytesPerSec / 1048576).toStringAsFixed(1)}M';
    }
    if (bytesPerSec >= 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(0)}K';
    }
    return '${bytesPerSec.round()}';
  }

  String _fmtSpeed(double? bytesPerSec) {
    if (bytesPerSec == null) return '—';
    if (bytesPerSec >= 1048576) {
      return '${(bytesPerSec / 1048576).toStringAsFixed(1)} MB/s';
    }
    if (bytesPerSec >= 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${bytesPerSec.toStringAsFixed(0)} B/s';
  }

  String _memValueText(MonitorService monitor) {
    final rss = monitor.latestRssMB(vm.id);
    if (rss == null) return 'collecting…';
    var text = 'RSS ${rss.toStringAsFixed(0)}M / ${vm.memoryMB}M';
    if (monitor.isBalloonAvailable(vm.id)) {
      final balloon = monitor.latestBalloonMB(vm.id);
      if (balloon != null) {
        text += ' · Guest ${balloon.toStringAsFixed(0)}M';
      }
    } else {
      text += ' · guest needs balloon driver';
    }
    return text;
  }

  String _ioValueText(MonitorService monitor) {
    final read = monitor.latestReadBps(vm.id);
    final write = monitor.latestWriteBps(vm.id);
    return 'R ${_fmtSpeed(read)} · W ${_fmtSpeed(write)}';
  }
}

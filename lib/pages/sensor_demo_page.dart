import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class _AccelSample {
  const _AccelSample(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  double get magnitude => math.sqrt(x * x + y * y + z * z);
}

class SensorDemoPage extends StatefulWidget {
  const SensorDemoPage({super.key});

  @override
  State<SensorDemoPage> createState() => _SensorDemoPageState();
}

class _SensorDemoPageState extends State<SensorDemoPage> {
  static const int _maxSamples = 60;
  static const double _motionThreshold = 0.8;

  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);
  static const _xColor = Color(0xFFEF4444);
  static const _yColor = Color(0xFF10B981);
  static const _zColor = Color(0xFF3B82F6);

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final ListQueue<_AccelSample> _history = ListQueue<_AccelSample>();

  _AccelSample _current = const _AccelSample(0, 0, 0);
  double _peakMagnitude = 0;
  bool _paused = false;
  bool _hasReading = false;
  String? _sensorError;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _subscription?.cancel();
    _subscription = userAccelerometerEventStream().listen(
      (event) {
        if (!mounted || _paused) return;
        final sample = _AccelSample(event.x, event.y, event.z);
        final mag = sample.magnitude;
        setState(() {
          _hasReading = true;
          _sensorError = null;
          _current = sample;
          if (mag > _peakMagnitude) {
            _peakMagnitude = mag;
          }
          _history.addLast(sample);
          while (_history.length > _maxSamples) {
            _history.removeFirst();
          }
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _sensorError = 'Sensor tidak tersedia: $error';
        });
      },
      cancelOnError: true,
    );
  }

  void _togglePause() => setState(() => _paused = !_paused);

  void _resetStats() {
    setState(() {
      _history.clear();
      _peakMagnitude = 0;
      _current = const _AccelSample(0, 0, 0);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final magnitude = _current.magnitude;
    final isMoving = _hasReading && magnitude >= _motionThreshold;

    final statusColor = _sensorError != null
        ? const Color(0xFFDC2626)
        : isMoving
            ? const Color(0xFFD97706)
            : const Color(0xFF0F766E);

    final statusTitle = _sensorError != null
        ? 'Sensor Tidak Tersedia'
        : !_hasReading
            ? 'Menunggu Pembacaan'
            : isMoving
                ? 'Perangkat Bergerak'
                : 'Perangkat Diam';

    final statusSubtitle = _sensorError ??
        (!_hasReading
            ? 'Gerakkan ponsel secara perlahan untuk mulai membaca sumbu.'
            : isMoving
                ? 'Percepatan melebihi ${_motionThreshold.toStringAsFixed(1)} m/s².'
                : 'Posisi perangkat relatif stabil.');

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accelerometer'),
            Text(
              'Monitor Sensor Gerak Real-Time',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _muted,
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _border),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _sensorError != null
                          ? Icons.error_outline_rounded
                          : isMoving
                              ? Icons.vibration_rounded
                              : Icons.stay_current_portrait_rounded,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                statusTitle,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _paused ? 'Dijeda' : 'Aktif',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          statusSubtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: _muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Grafik Sumbu X, Y, Z',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      _LegendDot(color: _xColor, label: 'X'),
                      SizedBox(width: 10),
                      _LegendDot(color: _yColor, label: 'Y'),
                      SizedBox(width: 10),
                      _LegendDot(color: _zColor, label: 'Z'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 170,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: CustomPaint(
                      painter: _AccelerometerChartPainter(
                        samples: _history.toList(growable: false),
                        gridColor: _border,
                        xColor: _xColor,
                        yColor: _yColor,
                        zColor: _zColor,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _AxisTile(
                    label: 'Sumbu X',
                    value: _current.x,
                    color: _xColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AxisTile(
                    label: 'Sumbu Y',
                    value: _current.y,
                    color: _yColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AxisTile(
                    label: 'Sumbu Z',
                    value: _current.z,
                    color: _zColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.speed_rounded,
                    label: 'Total Percepatan',
                    value: '${magnitude.toStringAsFixed(2)} m/s²',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.trending_up_rounded,
                    label: 'Gerakan Puncak',
                    value: '${_peakMagnitude.toStringAsFixed(2)} m/s²',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sensorError != null ? null : _togglePause,
                    icon: Icon(
                      _paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 19,
                    ),
                    label: Text(_paused ? 'Lanjutkan Sensor' : 'Jeda Sensor'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _resetStats,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AxisTile extends StatelessWidget {
  const _AxisTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const Text(
              'm/s²',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: const Color(0xFF0F766E)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      );
}

class _AccelerometerChartPainter extends CustomPainter {
  const _AccelerometerChartPainter({
    required this.samples,
    required this.gridColor,
    required this.xColor,
    required this.yColor,
    required this.zColor,
  });

  final List<_AccelSample> samples;
  final Color gridColor;
  final Color xColor;
  final Color yColor;
  final Color zColor;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;

    final zeroPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.2;
    final subGridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), zeroPaint);
    canvas.drawLine(
      Offset(0, size.height * 0.2),
      Offset(size.width, size.height * 0.2),
      subGridPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.8),
      Offset(size.width, size.height * 0.8),
      subGridPaint,
    );

    if (samples.length < 2) return;

    var maxAbs = 6.0;
    for (final s in samples) {
      maxAbs = math.max(maxAbs, s.x.abs());
      maxAbs = math.max(maxAbs, s.y.abs());
      maxAbs = math.max(maxAbs, s.z.abs());
    }

    void drawSeries(double Function(_AccelSample) selector, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      final stepX = size.width / (samples.length - 1);
      for (var i = 0; i < samples.length; i++) {
        final x = i * stepX;
        final normalized = (selector(samples[i]) / maxAbs).clamp(-1.0, 1.0);
        final y = midY - normalized * (size.height * 0.44);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }

    drawSeries((s) => s.x, xColor);
    drawSeries((s) => s.y, yColor);
    drawSeries((s) => s.z, zColor);
  }

  @override
  bool shouldRepaint(covariant _AccelerometerChartPainter oldDelegate) =>
      oldDelegate.samples != samples || oldDelegate.gridColor != gridColor;
}

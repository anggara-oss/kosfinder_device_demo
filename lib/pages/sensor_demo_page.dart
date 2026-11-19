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

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

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
    final theme = Theme.of(context);
    final magnitude = _current.magnitude;
    final isMoving = _hasReading && magnitude >= _motionThreshold;

    final statusColor = _sensorError != null
        ? Colors.red
        : isMoving
            ? Colors.orange.shade700
            : Colors.teal.shade700;

    final statusTitle = _sensorError != null
        ? 'Sensor Tidak Tersedia'
        : !_hasReading
            ? 'Menunggu Data Sensor'
            : isMoving
                ? 'Perangkat Bergerak'
                : 'Perangkat Diam';

    final statusSubtitle = _sensorError ??
        (!_hasReading
            ? 'Gerakkan ponsel secara perlahan untuk memulai pembacaan.'
            : isMoving
                ? 'Terdeteksi percepatan gerak di atas ${_motionThreshold.toStringAsFixed(1)} m/s².'
                : 'Perangkat relatif stabil.');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Accelerometer'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: statusColor.withValues(alpha: 0.16),
                  child: Icon(
                    _sensorError != null
                        ? Icons.error_outline
                        : isMoving
                            ? Icons.vibration
                            : Icons.stay_current_portrait,
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  statusTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  _paused ? 'Sensor dijeda' : 'Sensor aktif',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Grafik Pergerakan Real-Time (X, Y, Z)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 180,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: _AccelerometerChartPainter(
                      samples: _history.toList(growable: false),
                      gridColor: theme.colorScheme.outlineVariant,
                    ),
                    size: Size.infinite,
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendItem(color: Colors.red, label: 'Sumbu X'),
                    SizedBox(width: 16),
                    _LegendItem(color: Colors.green, label: 'Sumbu Y'),
                    SizedBox(width: 16),
                    _LegendItem(color: Colors.blue, label: 'Sumbu Z'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pembacaan Sumbu',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _AxisCard(
                  label: 'Sumbu X',
                  value: _current.x,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AxisCard(
                  label: 'Sumbu Y',
                  value: _current.y,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AxisCard(
                  label: 'Sumbu Z',
                  value: _current.z,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Informasi Gerakan',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.speed,
                  title: 'Total Percepatan',
                  value: '${magnitude.toStringAsFixed(2)} m/s²',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.show_chart,
                  title: 'Gerakan Puncak',
                  value: '${_peakMagnitude.toStringAsFixed(2)} m/s²',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _sensorError != null ? null : _togglePause,
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                  label: Text(_paused ? 'Lanjutkan Sensor' : 'Jeda Sensor'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _resetStats,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AxisCard extends StatelessWidget {
  const _AxisCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(2),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text('m/s²', style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(title, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _AccelerometerChartPainter extends CustomPainter {
  const _AccelerometerChartPainter({
    required this.samples,
    required this.gridColor,
  });

  final List<_AccelSample> samples;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    // Garis tengah (0 m/s²) dan batas atas/bawah
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), gridPaint);
    canvas.drawLine(
      Offset(0, size.height * 0.2),
      Offset(size.width, size.height * 0.2),
      gridPaint..color = gridColor.withValues(alpha: 0.25),
    );
    canvas.drawLine(
      Offset(0, size.height * 0.8),
      Offset(size.width, size.height * 0.8),
      gridPaint,
    );

    if (samples.length < 2) return;

    // Skala dinamis minimal ±6 m/s² agar grafik tetap mudah dibaca saat diam/bergerak
    var maxAbs = 6.0;
    for (final s in samples) {
      maxAbs = math.max(maxAbs, s.x.abs());
      maxAbs = math.max(maxAbs, s.y.abs());
      maxAbs = math.max(maxAbs, s.z.abs());
    }

    void drawSeries(double Function(_AccelSample) selector, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
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

    drawSeries((s) => s.x, Colors.red);
    drawSeries((s) => s.y, Colors.green);
    drawSeries((s) => s.z, Colors.blue);
  }

  @override
  bool shouldRepaint(covariant _AccelerometerChartPainter oldDelegate) =>
      oldDelegate.samples != samples || oldDelegate.gridColor != gridColor;
}

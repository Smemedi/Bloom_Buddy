// greenhouse_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'greenhouse_models.dart';

class GreenhouseService {
  final _controller = StreamController<GreenhouseReadings>.broadcast();
  Timer? _timer;
  GreenhouseReadings? _current;
  final _rng = Random();

  Stream<GreenhouseReadings> get stream => _controller.stream;

  Future<void> start() async {
    final raw = await rootBundle.loadString('assets/greenhouse_data.json');
    _current = GreenhouseReadings.fromJson(jsonDecode(raw));
    _controller.add(_current!);

    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _simulateUpdate());
  }

  void _simulateUpdate() {
    if (_current == null) return;

    double jitter(double val, double range) =>
        val + (_rng.nextDouble() * range * 2 - range);

    final c = _current!;
    _current = c.copyWith(
      timestamp: DateTime.now().toUtc().toIso8601String(),
      temperatureCelsius:
          c.temperatureCelsius != null ? jitter(c.temperatureCelsius!, 0.3) : null,
      humidityPercent: c.humidityPercent != null
          ? jitter(c.humidityPercent!, 0.5).clamp(0, 100)
          : null,
      electricalConductivity: c.electricalConductivity != null
          ? jitter(c.electricalConductivity!, 0.05)
          : null,
      ph: c.ph != null ? jitter(c.ph!, 0.05).clamp(0, 14) : null,
      nutrients: c.nutrients != null
          ? c.nutrients!.copyWith(
              nitrogen: jitter(c.nutrients!.nitrogen, 1),
              phosphorus: jitter(c.nutrients!.phosphorus, 0.5),
              potassium: jitter(c.nutrients!.potassium, 2),
            )
          : null,
      lightIntensityLux:
          c.lightIntensityLux != null ? jitter(c.lightIntensityLux!, 200) : null,
      parUmol: c.parUmol != null ? jitter(c.parUmol!, 10) : null,
    );

    _controller.add(_current!);
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
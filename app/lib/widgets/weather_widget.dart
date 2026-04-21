import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

// ─── CONFIGURATION ────────────────────────────────────────────────────────────
const String _owmApiKey = 'YOUR_OPENWEATHERMAP_API_KEY'; // <-- replace this

// ─── DATA MODEL ───────────────────────────────────────────────────────────────
class CurrentWeather {
  final String cityName;
  final double tempF;
  final double highF;
  final double lowF;
  final String description;
  final String iconCode;
  final int humidity;
  final double windMph;

  CurrentWeather({
    required this.cityName,
    required this.tempF,
    required this.highF,
    required this.lowF,
    required this.description,
    required this.iconCode,
    required this.humidity,
    required this.windMph,
  });
}

// ─── SERVICE ──────────────────────────────────────────────────────────────────
class WeatherService {
  static Future<CurrentWeather?> fetchCurrent() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=${pos.latitude}&lon=${pos.longitude}&units=imperial&appid=$_owmApiKey',
      );
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;

      final d = jsonDecode(resp.body) as Map<String, dynamic>;

      return CurrentWeather(
        cityName: d['name'] as String,
        tempF: (d['main']['temp'] as num).toDouble(),
        highF: (d['main']['temp_max'] as num).toDouble(),
        lowF: (d['main']['temp_min'] as num).toDouble(),
        description: _capitalize(d['weather'][0]['description'] as String),
        iconCode: d['weather'][0]['icon'] as String,
        humidity: (d['main']['humidity'] as num).toInt(),
        windMph: (d['wind']['speed'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String iconEmoji(String code) {
    const map = {
      '01': '☀️', '02': '⛅', '03': '☁️', '04': '☁️',
      '09': '🌧️', '10': '🌦️', '11': '⛈️', '13': '❄️', '50': '🌫️',
    };
    return map[code.length >= 2 ? code.substring(0, 2) : code] ?? '🌤️';
  }
}

// ─── WIDGET ───────────────────────────────────────────────────────────────────
class WeatherDashboard extends StatefulWidget {
  const WeatherDashboard({super.key});

  @override
  State<WeatherDashboard> createState() => _WeatherDashboardState();
}

class _WeatherDashboardState extends State<WeatherDashboard> {
  CurrentWeather? _weather;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    final data = await WeatherService.fetchCurrent();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _weather = data;
      _error = data == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error || _weather == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: Colors.black38, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Weather unavailable', style: TextStyle(color: Colors.black45, fontSize: 14)),
            ),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final w = _weather!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: temp + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: Colors.black45),
                    const SizedBox(width: 3),
                    Text(w.cityName, style: const TextStyle(fontSize: 13, color: Colors.black45)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${w.tempF.round()}°F',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                ),
                Text(
                  w.description,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),

          // Center: weather emoji
          Text(WeatherService.iconEmoji(w.iconCode), style: const TextStyle(fontSize: 42)),

          const SizedBox(width: 14),

          // Right: humidity, wind, H/L, refresh
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _statRow(Icons.water_drop_outlined, '${w.humidity}%'),
              const SizedBox(height: 6),
              _statRow(Icons.air, '${w.windMph.round()} mph'),
              const SizedBox(height: 6),
              Text(
                'H:${w.highF.round()}°  L:${w.lowF.round()}°',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _load,
                child: const Icon(Icons.refresh, size: 16, color: Colors.black38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.black45),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 13, color: Colors.black54)),
      ],
    );
  }
}
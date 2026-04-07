// BloomBuddy.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'greenhouse_models.dart';
import 'greenhouse_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _bgDark = Color(0xFF0F1A0F);
const _bgCard = Colors.white;
const _green = Color(0xFF4CAF50);
const _textPrimary = Color(0xFF1B2E1B);
const _textSecondary = Color(0xFF5A7A5A);

// ─── Scale helper ─────────────────────────────────────────────────────────────
// TODO: implement dashboard into its own plant card
class AppScale {
  final double factor;
  const AppScale(this.factor);

  factory AppScale.of(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return AppScale(width / 360);
  }

  double s(double size) => size * factor;
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class BloomBuddy extends StatelessWidget {
  const BloomBuddy({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bloom Buddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      home: const GreenhouseDashboard(),
    );
  }
}

// ─── Dashboard ────────────────────────────────────────────────────────────────
class GreenhouseDashboard extends StatefulWidget {
  const GreenhouseDashboard({super.key});

  @override
  State<GreenhouseDashboard> createState() => _GreenhouseDashboardState();
}

class _GreenhouseDashboardState extends State<GreenhouseDashboard> {
  final _service = GreenhouseService();

  @override
  void initState() {
    super.initState();
    _service.start();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc = AppScale.of(context);
    return Scaffold(
      body: StreamBuilder<GreenhouseReadings>(
        stream: _service.stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _green));
          }
          final r = snap.data!;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.all(sc.s(15)),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: sc.s(11),
                      crossAxisSpacing: sc.s(11),
                      childAspectRatio: 1.7,
                      children: [
                        if (r.temperatureCelsius != null)
                          TemperatureCard(value: r.temperatureCelsius!),
                        if (r.humidityPercent != null)
                          HumidityCard(value: r.humidityPercent!),
                        if (r.lightIntensityLux != null)
                          LightCard(value: r.lightIntensityLux!),
                        if (r.parUmol != null)
                          ParCard(value: r.parUmol!),
                        if (r.ph != null)
                          PhCard(value: r.ph!),
                        if (r.electricalConductivity != null)
                          EcCard(value: r.electricalConductivity!),
                      ],
                    ),
                    if (r.nutrients != null) ...[
                      SizedBox(height: sc.s(11)),
                      NutrientsCard(nutrients: r.nutrients!),
                    ],
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _scale = Tween(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scale,
        child: Container(
            width: 8,
            height: 8,
            decoration:
                const BoxDecoration(color: _green, shape: BoxShape.circle)),
      );
}

// ─── Base metric card ─────────────────────────────────────────────────────────
class MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;
  final Widget? bottom;

  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final sc = AppScale.of(context);
    return Container(
      padding: EdgeInsets.all(sc.s(13)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(sc.s(15)),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(.75),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(icon, color: color, size: sc.s(13)),
            SizedBox(width: sc.s(4)),
            Text(label,
                style: TextStyle(
                    color: color.withOpacity(0.85),
                    fontSize: sc.s(9),
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w500)),
          ]),
          SizedBox(height: sc.s(5)),
          Text(value,
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: sc.s(21),
                  fontWeight: FontWeight.w700,
                  height: 1.1)),
          if (subtitle != null)
            Text(subtitle!,
                style: TextStyle(color: _textSecondary, fontSize: sc.s(9))),
          SizedBox(height: sc.s(5)),
          if (bottom != null) bottom!,
        ],
      ),
    );
  }
}

// ─── Temperature ──────────────────────────────────────────────────────────────
class TemperatureCard extends StatelessWidget {
  final double value;
  const TemperatureCard({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final pct = ((value - 10) / 40).clamp(0.0, 1.0);
    return MetricCard(
      icon: Icons.thermostat,
      label: 'Temperature',
      value: '${value.toStringAsFixed(1)}°C',
      color: const Color(0xFFFF8A65),
      bottom: _ThinBar(value: pct, color: const Color(0xFFFF8A65)),
    );
  }
}

// ─── Humidity ─────────────────────────────────────────────────────────────────
class HumidityCard extends StatelessWidget {
  final double value;
  const HumidityCard({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return MetricCard(
      icon: Icons.water_drop,
      label: 'Humidity',
      value: '${value.toStringAsFixed(1)}%',
      color: const Color(0xFF26C6DA),
      bottom: _ThinBar(value: value / 100, color: const Color(0xFF26C6DA)),
    );
  }
}

// ─── Light ────────────────────────────────────────────────────────────────────
class LightCard extends StatelessWidget {
  final double value;
  const LightCard({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return MetricCard(
      icon: Icons.wb_sunny_outlined,
      label: 'Light',
      value: '${(value / 1000).toStringAsFixed(1)}k',
      subtitle: 'lux',
      color: const Color(0xFFFFCC02),
      bottom: _ThinBar(
          value: (value / 50000).clamp(0.0, 1.0),
          color: const Color(0xFFFFCC02)),
    );
  }
}

// ─── PAR ──────────────────────────────────────────────────────────────────────
class ParCard extends StatelessWidget {
  final double value;
  const ParCard({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return MetricCard(
      icon: Icons.wb_iridescent_outlined,
      label: 'PAR',
      value: value.toStringAsFixed(0),
      subtitle: 'µmol/m²/s',
      color: const Color(0xFFFFB74D),
      bottom: _ThinBar(
          value: (value / 1000).clamp(0.0, 1.0),
          color: const Color(0xFFFFB74D)),
    );
  }
}

// ─── pH ───────────────────────────────────────────────────────────────────────
class PhCard extends StatelessWidget {
  final double value;
  const PhCard({super.key, required this.value});

  Color get _phColor {
    if (value < 6.0) return const Color(0xFFEF9A9A);
    if (value > 7.5) return const Color(0xFF90CAF9);
    return const Color(0xFF81C784);
  }

  @override
  Widget build(BuildContext context) {
    return MetricCard(
      icon: Icons.science_outlined,
      label: 'pH',
      value: value.toStringAsFixed(2),
      subtitle: value < 6.0 ? 'acidic' : value > 7.5 ? 'alkaline' : 'neutral',
      color: _phColor,
      bottom: _ThinBar(value: value / 14, color: _phColor),
    );
  }
}

// ─── EC ───────────────────────────────────────────────────────────────────────
class EcCard extends StatelessWidget {
  final double value;
  const EcCard({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return MetricCard(
      icon: Icons.bolt,
      label: 'EC',
      value: value.toStringAsFixed(2),
      subtitle: 'mS/cm',
      color: const Color(0xFFA5D6A7),
      bottom: _ThinBar(
          value: (value / 5).clamp(0.0, 1.0),
          color: const Color(0xFFA5D6A7)),
    );
  }
}

// ─── Nutrients ────────────────────────────────────────────────────────────────
class NutrientsCard extends StatelessWidget {
  final Nutrients nutrients;
  const NutrientsCard({super.key, required this.nutrients});

  @override
  Widget build(BuildContext context) {
    final sc = AppScale.of(context);
    return Container(
      padding: EdgeInsets.all(sc.s(15)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(sc.s(15)),
        border: Border.all(color: _green.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.75),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.grass, color: _green, size: sc.s(15)),
            SizedBox(width: sc.s(5)),
            Text('Nutrients',
                style: TextStyle(
                    color: _green,
                    fontSize: sc.s(10),
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text('mg/kg',
                style: TextStyle(color: _textSecondary, fontSize: sc.s(9))),
          ]),
          SizedBox(height: sc.s(13)),
          _NutrientRow(
              symbol: 'N', name: 'Nitrogen',
              value: nutrients.nitrogen, max: 100,
              color: const Color(0xFF81C784)),
          SizedBox(height: sc.s(9)),
          _NutrientRow(
              symbol: 'P', name: 'Phosphorus',
              value: nutrients.phosphorus, max: 50,
              color: const Color(0xFF64B5F6)),
          SizedBox(height: sc.s(9)),
          _NutrientRow(
              symbol: 'K', name: 'Potassium',
              value: nutrients.potassium, max: 300,
              color: const Color(0xFFFFB74D)),
        ],
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  final String symbol;
  final String name;
  final double value;
  final double max;
  final Color color;

  const _NutrientRow({
    required this.symbol,
    required this.name,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final sc = AppScale.of(context);
    final frac = (value / max).clamp(0.0, 1.0);
    return Row(
      children: [
        Container(
          width: sc.s(23),
          height: sc.s(23),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(sc.s(5)),
          ),
          child: Text(symbol,
              style: TextStyle(
                  color: color,
                  fontSize: sc.s(10),
                  fontWeight: FontWeight.w700)),
        ),
        SizedBox(width: sc.s(11)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name,
                      style: TextStyle(
                          color: _textSecondary, fontSize: sc.s(10))),
                  Text(value.toStringAsFixed(1),
                      style: TextStyle(
                          color: color,
                          fontSize: sc.s(10),
                          fontWeight: FontWeight.w600)),
                ],
              ),
              SizedBox(height: sc.s(3)),
              ClipRRect(
                borderRadius: BorderRadius.circular(sc.s(3)),
                child: LinearProgressIndicator(
                  value: frac,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: sc.s(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Shared thin progress bar ─────────────────────────────────────────────────
class _ThinBar extends StatelessWidget {
  final double value;
  final Color color;
  const _ThinBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final sc = AppScale.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(sc.s(2)),
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: color.withOpacity(0.12),
        valueColor: AlwaysStoppedAnimation(color),
        minHeight: sc.s(3),
      ),
    );
  }
}
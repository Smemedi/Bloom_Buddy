import 'package:flutter/material.dart';
import '../utils/recommendation.dart';

class RecommendationCard extends StatelessWidget {
  final Recommendation rec;

  const RecommendationCard({super.key, required this.rec});

  @override
  Widget build(BuildContext context) {
    final theme      = Theme.of(context);
    final isUrgent   = rec.isUrgent;
    final isWater    = rec.isWater;

    final Color accentColor = isUrgent
        ? const Color(0xFFE24B4A)   // red-400
        : isWater
            ? const Color(0xFF378ADD) // blue-400
            : const Color(0xFFBA7517); // amber-400

    final Color bgColor = isUrgent
        ? const Color(0xFFFCEBEB)
        : isWater
            ? const Color(0xFFE6F1FB)
            : const Color(0xFFFAEEDA);

    final String icon  = isWater ? '💧' : '🌱';
    final String label = isWater ? 'Water' : 'Fertilize';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: accentColor.withOpacity(0.35), width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Plant ${rec.plantId} — $label',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SeverityBadge(severity: rec.severity, color: accentColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rec.reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MetricsRow(metrics: rec.metrics, isWater: isWater),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SeverityBadge extends StatelessWidget {
  final String severity;
  final Color  color;
  const _SeverityBadge({required this.severity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}


class _MetricsRow extends StatelessWidget {
  final Map<String, dynamic> metrics;
  final bool isWater;
  const _MetricsRow({required this.metrics, required this.isWater});

  @override
  Widget build(BuildContext context) {
    final entries = isWater
        ? [
            _Chip('Moisture', '${metrics['moisture_pct']}%'),
            _Chip('Hours low', '${metrics['hours_below']}h'),
          ]
        : [
            if (metrics['N'] != null) _Chip('N', '${metrics['N']} mg/kg'),
            if (metrics['P'] != null) _Chip('P', '${metrics['P']} mg/kg'),
            if (metrics['K'] != null) _Chip('K', '${metrics['K']} mg/kg'),
          ];

    return Wrap(spacing: 6, children: entries);
  }
}


class _Chip extends StatelessWidget {
  final String label;
  final String value;
  const _Chip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11, color: Colors.black87),
      ),
    );
  }
}

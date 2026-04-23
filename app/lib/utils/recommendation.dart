class Recommendation {
  final int plantId;
  final String type;       // "water" | "fertilize"
  final String severity;   // "urgent" | "warning"
  final String reason;
  final Map<String, dynamic> metrics;
  final DateTime createdAt;

  const Recommendation({
    required this.plantId,
    required this.type,
    required this.severity,
    required this.reason,
    required this.metrics,
    required this.createdAt,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      plantId:   json['plant_id'] as int,
      type:      json['type'] as String,
      severity:  json['severity'] as String,
      reason:    json['reason'] as String,
      metrics:   Map<String, dynamic>.from(json['metrics'] as Map? ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isUrgent => severity == 'urgent';
  bool get isWater   => type == 'water';
  bool get isFertilize => type == 'fertilize';
}


class Plant {
  final int plantId;
  final String name;
  final double? moisturePct;
  final double? phLevel;
  final double? nitrogenMgKg;
  final DateTime? lastReading;

  const Plant({
    required this.plantId,
    required this.name,
    this.moisturePct,
    this.phLevel,
    this.nitrogenMgKg,
    this.lastReading,
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      plantId:      json['plant_id'] as int,
      name:         json['name'] as String,
      moisturePct:  (json['moisture_pct'] as num?)?.toDouble(),
      phLevel:      (json['ph_level'] as num?)?.toDouble(),
      nitrogenMgKg: (json['nitrogen_mg_kg'] as num?)?.toDouble(),
      lastReading:  json['last_reading'] != null
                      ? DateTime.parse(json['last_reading'] as String)
                      : null,
    );
  }
}

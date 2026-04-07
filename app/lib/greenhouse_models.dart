// greenhouse_models.dart

class Nutrients {
  final double nitrogen;
  final double phosphorus;
  final double potassium;

  Nutrients({
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
  });

  factory Nutrients.fromJson(Map<String, dynamic> json) => Nutrients(
        nitrogen: (json['nitrogen'] as num).toDouble(),
        phosphorus: (json['phosphorus'] as num).toDouble(),
        potassium: (json['potassium'] as num).toDouble(),
      );

  Nutrients copyWith({double? nitrogen, double? phosphorus, double? potassium}) =>
      Nutrients(
        nitrogen: nitrogen ?? this.nitrogen,
        phosphorus: phosphorus ?? this.phosphorus,
        potassium: potassium ?? this.potassium,
      );
}

//device readings
class GreenhouseReadings {
  final String greenhouseId;
  final String location;
  final String timestamp;

  // Soil
  final double? temperatureCelsius;
  final double? humidityPercent;
  final double? electricalConductivity;
  final double? ph;
  final Nutrients? nutrients;

  // Light
  final double? lightIntensityLux;
  final double? parUmol;

  GreenhouseReadings({
    required this.greenhouseId,
    required this.location,
    required this.timestamp,
    this.temperatureCelsius,
    this.humidityPercent,
    this.electricalConductivity,
    this.ph,
    this.nutrients,
    this.lightIntensityLux,
    this.parUmol,
  });

  /// Parse the raw JSON and flatten all device readings into one object.
  factory GreenhouseReadings.fromJson(Map<String, dynamic> json) {
    double? temp, humidity, ec, ph, lux, par;
    Nutrients? nutrients;

    for (final device in (json['devices'] as List)) {
      final r = device['readings'] as Map<String, dynamic>;
      switch (device['type']) {
        case 'soil_multisensor':
          temp = (r['temperature_celsius'] as num?)?.toDouble();
          humidity = (r['humidity_percent'] as num?)?.toDouble();
          ec = (r['electrical_conductivity_ms_cm'] as num?)?.toDouble();
          ph = (r['ph'] as num?)?.toDouble();
          if (r['nutrients_mg_kg'] != null) {
            nutrients = Nutrients.fromJson(r['nutrients_mg_kg']);
          }
          break;
        case 'light_sensor':
          lux = (r['light_intensity_lux'] as num?)?.toDouble();
          par = (r['par_umol_m2_s'] as num?)?.toDouble();
          break;
      }
    }

    return GreenhouseReadings(
      greenhouseId: json['greenhouse_id'],
      location: json['location'],
      timestamp: json['timestamp'],
      temperatureCelsius: temp,
      humidityPercent: humidity,
      electricalConductivity: ec,
      ph: ph,
      nutrients: nutrients,
      lightIntensityLux: lux,
      parUmol: par,
    );
  }

  GreenhouseReadings copyWith({
    String? timestamp,
    double? temperatureCelsius,
    double? humidityPercent,
    double? electricalConductivity,
    double? ph,
    Nutrients? nutrients,
    double? lightIntensityLux,
    double? parUmol,
  }) =>
      GreenhouseReadings(
        greenhouseId: greenhouseId,
        location: location,
        timestamp: timestamp ?? this.timestamp,
        temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
        humidityPercent: humidityPercent ?? this.humidityPercent,
        electricalConductivity:
            electricalConductivity ?? this.electricalConductivity,
        ph: ph ?? this.ph,
        nutrients: nutrients ?? this.nutrients,
        lightIntensityLux: lightIntensityLux ?? this.lightIntensityLux,
        parUmol: parUmol ?? this.parUmol,
      );
}
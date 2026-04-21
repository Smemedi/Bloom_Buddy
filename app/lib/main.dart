import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

const String _owmApiKey = 'af12586bd2c4a19f1a1271f4bad3e7d6';
void main() => runApp(const PlantApp());
const String serverBaseUrl = "http://64.131.107.11:8000";

class PlantApp extends StatelessWidget {
  const PlantApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Plants',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const RootNav(),
    );
  }
}

class RootNav extends StatefulWidget {
  const RootNav({super.key});
  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomePlantsPage(),
      const MessagesPage(),
      const CameraDetectionPage(),
      const CalendarScreen(),
      const BloomBuddy(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.camera_alt_outlined), selectedIcon: Icon(Icons.camera_alt), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.local_florist_outlined), selectedIcon: Icon(Icons.local_florist), label: 'Statistics'),
        ],
      ),
    );
  }
}

// ─── WEATHER DATA MODEL ──────────────────────────────────────────────
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

// ─── WEATHER SERVICE ─────────────────────────────────────────────────
class WeatherService {
  static Future<CurrentWeather?> fetchByCity(String city) async {
    try {
      final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?q=${Uri.encodeComponent(city)}&units=imperial&appid=$_owmApiKey',
      );
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;
      return _parse(jsonDecode(resp.body));
    } catch (_) {
      return null;
    }
  }

  static Future<CurrentWeather?> fetchByGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=${pos.latitude}&lon=${pos.longitude}&units=imperial&appid=$_owmApiKey',
      );
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;
      return _parse(jsonDecode(resp.body));
    } catch (_) {
      return null;
    }
  }

  static CurrentWeather _parse(Map<String, dynamic> d) {
    return CurrentWeather(
      cityName: d['name'],
      tempF: (d['main']['temp'] as num).toDouble(),
      highF: (d['main']['temp_max'] as num).toDouble(),
      lowF: (d['main']['temp_min'] as num).toDouble(),
      description: _cap(d['weather'][0]['description']),
      iconCode: d['weather'][0]['icon'],
      humidity: d['main']['humidity'],
      windMph: (d['wind']['speed'] as num).toDouble(),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String iconEmoji(String code) {
    const map = {
      '01': '☀️', '02': '⛅', '03': '☁️', '04': '☁️',
      '09': '🌧️', '10': '🌦️', '11': '⛈️', '13': '❄️', '50': '🌫️',
    };
    return map[code.substring(0, 2)] ?? '🌤️';
  }
}

// ─── WEATHER WIDGET ──────────────────────────────────────────────────
class WeatherDashboard extends StatefulWidget {
  const WeatherDashboard({super.key});
  @override
  State<WeatherDashboard> createState() => _WeatherDashboardState();
}

class _WeatherDashboardState extends State<WeatherDashboard> {
  CurrentWeather? _weather;
  bool _loading = true;
  bool _error = false;
  final _cityCtrl = TextEditingController(text: 'Chicago');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    CurrentWeather? data;
    if (kIsWeb) {
      data = await WeatherService.fetchByCity(_cityCtrl.text.trim());
    } else {
      data = await WeatherService.fetchByGps();
      data ??= await WeatherService.fetchByCity(_cityCtrl.text.trim());
    }
    if (!mounted) return;
    setState(() { _loading = false; _weather = data; _error = data == null; });
  }

  void _showCityDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: _cityCtrl.text);
        return AlertDialog(
          title: const Text('Set City'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'City name'),
            autofocus: true,
            onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Search')),
          ],
        );
      },
    );
    if (result != null && result.isNotEmpty) {
      _cityCtrl.text = result;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: _loading
          ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()))
          : _error || _weather == null
              ? Row(
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.black38),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Weather unavailable', style: TextStyle(color: Colors.black54))),
                    TextButton(onPressed: _showCityDialog, child: const Text('Set city')),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: _showCityDialog,
                            child: Row(
                              children: [
                                Text(_weather!.cityName, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit, size: 13, color: Colors.black38),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('${_weather!.tempF.round()}°F',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                          Text(_weather!.description,
                              style: const TextStyle(fontSize: 14, color: Colors.black54)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.water_drop_outlined, size: 14, color: Colors.blue.shade300),
                              const SizedBox(width: 4),
                              Text('${_weather!.humidity}%', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                              const SizedBox(width: 12),
                              Icon(Icons.air, size: 14, color: Colors.blue.shade300),
                              const SizedBox(width: 4),
                              Text('${_weather!.windMph.round()} mph', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(WeatherService.iconEmoji(_weather!.iconCode),
                            style: const TextStyle(fontSize: 44)),
                        const SizedBox(height: 4),
                        Text('H:${_weather!.highF.round()}° L:${_weather!.lowF.round()}°',
                            style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
    );
  }
}

// ─── HOME PAGE ───────────────────────────────────────────────────────
class HomePlantsPage extends StatefulWidget {
  const HomePlantsPage({super.key});
  @override
  State<HomePlantsPage> createState() => _HomePlantsPageState();
}

class _HomePlantsPageState extends State<HomePlantsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<String?> _guessSpecies(String imagePath) async {
    final uri = Uri.parse("$serverBaseUrl/predict?top_k=1");
    final request = http.MultipartRequest("POST", uri);
    request.files.add(await http.MultipartFile.fromPath("file", imagePath));
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final raw = data["top"] as String?;
    if (raw == null) return null;
    String cleaned = raw.replaceAll('_', ' ');
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 3 && RegExp(r'^[A-Z]').hasMatch(parts.last)) {
      return '${parts[0]} ${parts[1]}';
    }
    return parts.join(' ');
  }

  final PageController _pageController = PageController(viewportFraction: 0.78);
  final List<Plant> _plants = [];
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _addPlantDialog() async {
    String? guessedSpecies;
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final picker = ImagePicker();
    XFile? pickedImage;

    final created = await showDialog<Plant>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Add Plant'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
                        if (x == null) return;
                        setLocalState(() { pickedImage = x; guessedSpecies = null; });
                        try {
                          final top = await _guessSpecies(x.path);
                          setLocalState(() { guessedSpecies = top ?? ''; });
                        } catch (_) {
                          setLocalState(() { guessedSpecies = ''; });
                        }
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(pickedImage == null ? 'Add Photo' : 'Change Photo'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (pickedImage != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 280, height: 140,
                        child: Image.file(File(pickedImage!.path), fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Species: ${guessedSpecies == null ? "Guessing..." : (guessedSpecies!.isEmpty ? "—" : guessedSpecies!)}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Plant name (e.g., Monstera)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Location (e.g., Kitchen)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final loc = locationController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(context, Plant(
                  name: name,
                  location: loc.isEmpty ? '—' : loc,
                  imagePath: pickedImage?.path,
                  species: guessedSpecies,
                ));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (created != null) {
      setState(() {
        _plants.add(created);
        _currentIndex = _plants.length - 1;
      });
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        _pageController.animateToPage(_currentIndex,
            duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addPlantDialog,
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(18, topPad + 18, 18, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Center(
                  child: const Text('Bloom Buddy',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Row(children: const [
                    Icon(Icons.search, size: 20, color: Colors.black45),
                    SizedBox(width: 10),
                    Expanded(child: Text('Search plants', style: TextStyle(color: Colors.black45))),
                    Icon(Icons.tune, size: 20, color: Colors.black45),
                  ]),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back, Plant Parent! 🌿',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700])),
                      const SizedBox(height: 8),
                      const Text('Come see how your plants are doing today.',
                          style: TextStyle(fontSize: 14, color: Colors.black54)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const WeatherDashboard(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Text('My Plants', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                      _plants.isEmpty ? '0' : '${_currentIndex + 1}/${_plants.length}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 320,
                  child: _plants.isEmpty
                      ? _EmptyState(onAdd: _addPlantDialog)
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: _plants.length,
                          onPageChanged: (i) => setState(() => _currentIndex = i),
                          itemBuilder: (context, i) => GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => PlantDetailsPage(plant: _plants[i])));
                              if (!mounted) return;
                              if (result == '__delete__') {
                                setState(() {
                                  _plants.removeAt(i);
                                  if (_currentIndex >= _plants.length) {
                                    _currentIndex = _plants.isEmpty ? 0 : _plants.length - 1;
                                  }
                                });
                              } else if (result is Plant) {
                                setState(() => _plants[i] = result);
                              }
                            },
                            child: PlantCard(plant: _plants[i], isActive: i == _currentIndex),
                          ),
                        ),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_florist, size: 44),
            const SizedBox(height: 10),
            const Text('No plants yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Tap + to add your first plant.',
                style: TextStyle(color: Colors.black54), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add Plant')),
          ],
        ),
      ),
    );
  }
}

class PlantCard extends StatelessWidget {
  final Plant plant;
  final bool isActive;
  const PlantCard({super.key, required this.plant, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final hasImage = plant.imagePath != null && plant.imagePath!.isNotEmpty;
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: isActive ? 1.0 : 0.96,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: Colors.black.withOpacity(0.10))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasImage)
                  Image.file(File(plant.imagePath!), fit: BoxFit.cover)
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Colors.green.shade200, Colors.green.shade500],
                      ),
                    ),
                  ),
                Container(color: Colors.black.withOpacity(0.12)),
                if (!hasImage)
                  Positioned(right: -10, top: -10,
                      child: Icon(Icons.spa, size: 140, color: Colors.white.withOpacity(0.18))),
                Positioned(
                  left: 14, right: 14, bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.40),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(plant.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Row(children: [
                                Icon(Icons.place, size: 16, color: Colors.white.withOpacity(0.9)),
                                const SizedBox(width: 6),
                                Expanded(child: Text(plant.location,
                                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                                    overflow: TextOverflow.ellipsis)),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.favorite_border, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── MESSAGES PAGE ───────────────────────────────────────────────────
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(18, topPad + 18, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Chat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('To be implemented...', style: TextStyle(color: Colors.black54)),
        ]),
      ),
    );
  }
}

// ─── CALENDAR SCREEN ─────────────────────────────────────────────────
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(18, topPad + 18, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Calendar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('To be implemented...', style: TextStyle(color: Colors.black54)),
        ]),
      ),
    );
  }
}

// ─── BLOOM BUDDY (STATISTICS) ─────────────────────────────────────────
class BloomBuddy extends StatelessWidget {
  const BloomBuddy({super.key});
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(18, topPad + 18, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Statistics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('To be implemented...', style: TextStyle(color: Colors.black54)),
        ]),
      ),
    );
  }
}

// ─── PLANT AVATAR ─────────────────────────────────────────────────────
class PlantAvatar extends StatelessWidget {
  final String? imagePath;
  final double size;
  const PlantAvatar({super.key, required this.imagePath, this.size = 120});

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.green.withOpacity(0.12),
      child: ClipOval(
        child: SizedBox(
          width: size, height: size,
          child: hasImage
              ? Image.file(File(imagePath!), fit: BoxFit.cover)
              : Container(
                  color: Colors.green.withOpacity(0.10),
                  child: Icon(Icons.local_florist, size: size * 0.55,
                      color: Colors.green.shade700.withOpacity(0.8))),
        ),
      ),
    );
  }
}

// ─── PLANT MODEL ──────────────────────────────────────────────────────
class Plant {
  final String name;
  final String location;
  final String? imagePath;
  final String? species;

  Plant({required this.name, required this.location, this.imagePath, this.species});

  Plant copyWith({String? name, String? location, String? imagePath, String? species}) {
    return Plant(
      name: name ?? this.name,
      location: location ?? this.location,
      imagePath: imagePath ?? this.imagePath,
      species: species ?? this.species,
    );
  }
}

// ─── PLANT DETAILS PAGE ───────────────────────────────────────────────
class PlantDetailsPage extends StatefulWidget {
  final Plant plant;
  const PlantDetailsPage({super.key, required this.plant});
  @override
  State<PlantDetailsPage> createState() => _PlantDetailsPageState();
}

class _PlantDetailsPageState extends State<PlantDetailsPage> {
  late Plant _plant;
  final _speciesCtrl = TextEditingController();
  final _phCtrl = TextEditingController();
  final _moistureCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _phosphorousCtrl = TextEditingController();
  final _nitrogenCtrl = TextEditingController();
  final _potassiumCtrl = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() { super.initState(); _plant = widget.plant; }

  @override
  void dispose() {
    _speciesCtrl.dispose(); _phCtrl.dispose(); _moistureCtrl.dispose();
    _tempCtrl.dispose(); _phosphorousCtrl.dispose(); _nitrogenCtrl.dispose();
    _potassiumCtrl.dispose(); super.dispose();
  }

  Future<void> _confirmDeleteFromSheet() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete plant?'),
        content: Text('This will remove "${_plant.name}" from your list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context);
      Navigator.pop(context, '__delete__');
    }
  }

  Future<String?> _getTopSpecies(String imagePath) async {
    final uri = Uri.parse("$serverBaseUrl/predict?top_k=1");
    final request = http.MultipartRequest("POST", uri);
    request.files.add(await http.MultipartFile.fromPath("file", imagePath));
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) throw Exception("Predict failed: ${resp.statusCode}");
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final raw = data["top"] as String?;
    if (raw == null) return null;
    String cleaned = raw.replaceAll('_', ' ');
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 3 && RegExp(r'^[A-Z]').hasMatch(parts.last)) {
      return '${parts[0]} ${parts[1]}';
    }
    return parts.join(' ');
  }

  Widget _infoRow(String label, String value) {
    final display = value.trim().isEmpty ? '—' : value.trim();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.08)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: Text(display, textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Future<void> _openEditSheet() async {
    _speciesCtrl.text = _plant.species ?? '';
    _phCtrl.text = _moistureCtrl.text = _tempCtrl.text =
        _phosphorousCtrl.text = _nitrogenCtrl.text = _potassiumCtrl.text = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Text('Edit Plant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                TextButton.icon(onPressed: _pickFromLibrary,
                    icon: const Icon(Icons.photo_library_outlined), label: const Text('Photo')),
              ]),
              const SizedBox(height: 8),
              TextField(decoration: const InputDecoration(labelText: 'Species'), controller: _speciesCtrl),
              TextField(decoration: const InputDecoration(labelText: 'pH'), controller: _phCtrl, keyboardType: TextInputType.number),
              TextField(decoration: const InputDecoration(labelText: 'Soil Moisture (%)'), controller: _moistureCtrl, keyboardType: TextInputType.number),
              TextField(decoration: const InputDecoration(labelText: 'Soil Temperature (C)'), controller: _tempCtrl, keyboardType: TextInputType.number),
              TextField(decoration: const InputDecoration(labelText: 'Phosphorous (%)'), controller: _phosphorousCtrl, keyboardType: TextInputType.number),
              TextField(decoration: const InputDecoration(labelText: 'Nitrogen (%)'), controller: _nitrogenCtrl, keyboardType: TextInputType.number),
              TextField(decoration: const InputDecoration(labelText: 'Potassium (%)'), controller: _potassiumCtrl, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    setState(() => _plant = _plant.copyWith(species: _speciesCtrl.text.trim()));
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Plant'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: _confirmDeleteFromSheet,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromLibrary() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    setState(() => _plant = _plant.copyWith(imagePath: picked.path));
    try {
      final top = await _getTopSpecies(picked.path);
      if (!mounted) return;
      final s = (top ?? '').trim();
      setState(() { _plant = _plant.copyWith(species: s); _speciesCtrl.text = s; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Species guess failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      appBar: AppBar(
        title: Text(_plant.name),
        leading: BackButton(onPressed: () => Navigator.pop(context, _plant)),
        actions: [IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit), onPressed: _openEditSheet)],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, topPad + 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Center(child: PlantAvatar(imagePath: _plant.imagePath, size: 260)),
              const SizedBox(height: 22),
              const Text('Plant Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _infoRow('Species', _plant.species ?? ''),
              _infoRow('pH', ''),
              _infoRow('Soil Moisture (%)', ''),
              _infoRow('Soil Temperature (C)', ''),
              _infoRow('Phosphorous (%)', ''),
              _infoRow('Nitrogen (%)', ''),
              _infoRow('Potassium (%)', ''),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => PlantHealthReportPage(plant: _plant))),
                  child: const Text('Health Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── PLANT HEALTH REPORT PAGE ──────────────────────────────────────────
class PlantHealthReportPage extends StatefulWidget {
  final Plant plant;
  const PlantHealthReportPage({super.key, required this.plant});
  @override
  State<PlantHealthReportPage> createState() => _PlantHealthReportPageState();
}

class _PlantHealthReportPageState extends State<PlantHealthReportPage> {
  final ImagePicker _picker = ImagePicker();
  String? _leafImagePath;
  bool _loading = false;
  List<Map<String, dynamic>> _predictions = [];

  Future<void> _pickLeafAndPredict() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    setState(() { _leafImagePath = picked.path; _loading = true; _predictions = []; });
    try {
      final uri = Uri.parse("$serverBaseUrl/disease_predict?top_k=3");
      final request = http.MultipartRequest("POST", uri);
      request.files.add(await http.MultipartFile.fromPath("file", picked.path));
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode != 200) throw Exception("Disease predict failed: ${resp.statusCode}");
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final preds = (data["predictions"] as List)
          .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v))).toList();
      if (!mounted) return;
      setState(() { _predictions = preds.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Disease detection failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.plant.name} Health Report')),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, topPad + 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Health Report', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Plant: ${widget.plant.name}', style: const TextStyle(fontSize: 16, color: Colors.black54)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _pickLeafAndPredict,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_loading ? 'Detecting…' : 'Select leaf photo'),
                ),
              ),
              const SizedBox(height: 14),
              if (_leafImagePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(width: double.infinity, height: 180,
                      child: Image.file(File(_leafImagePath!), fit: BoxFit.cover)),
                ),
                const SizedBox(height: 14),
              ],
              const Text('Disease Detection (Top 3)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (_loading)
                const Text('Analyzing image…', style: TextStyle(color: Colors.black54))
              else if (_predictions.isEmpty)
                const Text('No results yet. Select a leaf photo.', style: TextStyle(color: Colors.black54))
              else
                Column(children: [
                  for (int i = 0; i < _predictions.length; i++)
                    _DiseaseRow(
                      rank: i + 1,
                      label: _predictions[i]["label"]?.toString() ?? "Unknown",
                      score: (_predictions[i]["score"] as num?)?.toDouble() ?? 0.0,
                    ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── DISEASE ROW ──────────────────────────────────────────────────────
class _DiseaseRow extends StatelessWidget {
  final int rank;
  final String label;
  final double score;
  const _DiseaseRow({required this.rank, required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.08)))),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('$rank.', style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 10),
          Text('${(score * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

// ─── CAMERA DETECTION PAGE ────────────────────────────────────────────
class CameraDetectionPage extends StatefulWidget {
  const CameraDetectionPage({super.key});
  @override
  State<CameraDetectionPage> createState() => _CameraDetectionPageState();
}

class _CameraDetectionPageState extends State<CameraDetectionPage> {
  final ImagePicker _picker = ImagePicker();
  String? _imagePath;
  bool _loading = false;
  String? _species;
  List<Map<String, dynamic>> _diseases = [];

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    setState(() { _imagePath = picked.path; _loading = true; _species = null; _diseases = []; });
    try {
      final results = await Future.wait([_detectSpecies(picked.path), _detectDisease(picked.path)]);
      if (!mounted) return;
      setState(() { _species = results[0] as String?; _diseases = results[1] as List<Map<String, dynamic>>; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Detection failed: $e')));
    }
  }

  Future<String?> _detectSpecies(String imagePath) async {
    final uri = Uri.parse("$serverBaseUrl/predict?top_k=1");
    final request = http.MultipartRequest("POST", uri);
    request.files.add(await http.MultipartFile.fromPath("file", imagePath));
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final raw = data["top"] as String?;
    if (raw == null) return null;
    String cleaned = raw.replaceAll('_', ' ');
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 3 && RegExp(r'^[A-Z]').hasMatch(parts.last)) return '${parts[0]} ${parts[1]}';
    return parts.join(' ');
  }

  Future<List<Map<String, dynamic>>> _detectDisease(String imagePath) async {
    final uri = Uri.parse("$serverBaseUrl/disease_predict?top_k=3");
    final request = http.MultipartRequest("POST", uri);
    request.files.add(await http.MultipartFile.fromPath("file", imagePath));
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data["predictions"] as List)
        .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v))).toList().cast();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(18, topPad + 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scan Plant', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Identify species and detect disease', style: TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: FilledButton.icon(
                onPressed: _loading ? null : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined), label: const Text('Camera'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: _loading ? null : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery'))),
            ]),
            const SizedBox(height: 18),
            if (_imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(width: double.infinity, height: 220,
                    child: Image.file(File(_imagePath!), fit: BoxFit.cover)),
              ),
              const SizedBox(height: 18),
            ],
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _imagePath != null) ...[
              Container(
                width: double.infinity, padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Species', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text(_species ?? '—', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 14),
              const Text('Disease Detection (Top 3)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (_diseases.isEmpty)
                const Text('No disease results.', style: TextStyle(color: Colors.black54))
              else
                for (int i = 0; i < _diseases.length; i++)
                  _DiseaseRow(
                    rank: i + 1,
                    label: _diseases[i]["label"]?.toString() ?? "Unknown",
                    score: (_diseases[i]["score"] as num?)?.toDouble() ?? 0.0,
                  ),
            ],
            if (_imagePath == null)
              Expanded(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.camera_alt, size: 56, color: Colors.black26),
                    SizedBox(height: 12),
                    Text('Take or select a photo\nto identify your plant',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black45, fontSize: 15)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
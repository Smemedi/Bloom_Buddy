import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'calendar_screen.dart';
import 'statistics_dashboard.dart';

void main() => runApp(const PlantApp());
const String serverBaseUrl = "http://64.131.107.11:8000"; // may need to be changed
class PlantApp extends StatelessWidget {
  const PlantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Plants',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
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

  final _pages = const [
    HomePlantsPage(),
    MessagesPage(),
    CalendarScreen(),
    BloomBuddy()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.local_florist_outlined), selectedIcon: Icon(Icons.local_florist), label: 'Statistics'),
        ],
      ),
    );
  }
}

class HomePlantsPage extends StatefulWidget {
  const HomePlantsPage({super.key});

  @override
  State<HomePlantsPage> createState() => _HomePlantsPageState();
}

class _HomePlantsPageState extends State<HomePlantsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Future<String?> _guessSpeciesFromImageForHome(String imagePath) async {
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

    // If it's like "Genus species Author", drop the author
    if (parts.length >= 3 && RegExp(r'^[A-Z]').hasMatch(parts.last)) {
      cleaned = '${parts[0]} ${parts[1]}';
    } else {
      cleaned = parts.join(' ');
    }

    return cleaned;
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
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: const Text('Add Plant'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Photo picker + preview
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final x = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 90,
                          );
                          if (x == null) return;

                          setLocalState(() {
                            pickedImage = x;
                            guessedSpecies = null; // reset while loading
                          });

                          try {
                            final top = await _guessSpeciesFromImageForHome(x.path);
                            setLocalState(() {
                              guessedSpecies = top ?? '';
                            });
                          } catch (_) {
                            setLocalState(() {
                              guessedSpecies = '';
                            });
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
                          width: 280, // <- finite width fixes the intrinsic sizing crash
                          height: 140,
                          child: Image.file(
                            File(pickedImage!.path),
                            fit: BoxFit.cover,
                          ),
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
                      decoration: const InputDecoration(
                        labelText: 'Plant name (e.g., Monstera)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location (e.g., Kitchen)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final loc = locationController.text.trim();
                  if (name.isEmpty) return;

                  Navigator.pop(
                    context,
                    Plant(
                      name: name,
                      location: loc.isEmpty ? '—' : loc,
                      imagePath: pickedImage?.path, // <-- save the photo
                      species: guessedSpecies,
                    ),
                  );
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );

  if (created != null) {
    setState(() {
      _plants.add(created);
      _currentIndex = _plants.length - 1;
    });
    // Jump/animate to the new plant card
    await Future.delayed(const Duration(milliseconds: 50));
    if (mounted) {
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
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
      body: Padding(
        padding: EdgeInsets.fromLTRB(18, topPad + 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (similar vibe to the middle screen)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Bloom Buddy',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      //Text(
                        //'Your plants',
                        //style: TextStyle(fontSize: 14, color: Colors.black54),
                      //),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Search bar placeholder (optional; matches the layout)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.search, size: 20, color: Colors.black45),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search plants',
                      style: TextStyle(color: Colors.black45),
                    ),
                  ),
                  Icon(Icons.tune, size: 20, color: Colors.black45),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Section title
            Row(
              children: [
                const Text(
                  'My Plants',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  _plants.isEmpty ? '0' : '${_currentIndex + 1}/${_plants.length}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Swipeable plants
            Expanded(
              child: _plants.isEmpty
                  ? _EmptyState(onAdd: _addPlantDialog)
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: _plants.length,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlantDetailsPage(plant: _plants[i]),
                            ),
                          );

                          if (!mounted) return;

                          if (result == '__delete__') {
                            setState(() {
                              _plants.removeAt(i);

                              if (_currentIndex >= _plants.length) {
                                _currentIndex = (_plants.isEmpty) ? 0 : _plants.length - 1;
                              }
                            });
                          } 
                          else if (result is Plant) {
                            setState(() {
                              _plants[i] = result;
                            });
                          }
                        },
                        child: PlantCard(
                          plant: _plants[i],
                          isActive: i == _currentIndex,
                        ),
                      ),
                    ),
            ),
          ],
        ),
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
            const Text(
              'No plants yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap + to add your first plant.',
              style: TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Plant'),
            ),
          ],
        ),
      ),
    );
  }
}

class PlantCard extends StatelessWidget {
  final Plant plant;
  final bool isActive;

  const PlantCard({
    super.key,
    required this.plant,
    required this.isActive,
  });

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
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              fit: StackFit.expand,
              children: [

                // Background image
                if (hasImage)
                  Image.file(
                    File(plant.imagePath!),
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.green.shade200,
                          Colors.green.shade500,
                        ],
                      ),
                    ),
                  ),

                // overlay
                Container(color: Colors.black.withOpacity(0.12)),

                // decorative icon when no image
                if (!hasImage)
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Icon(
                      Icons.spa,
                      size: 140,
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),

                // bottom info bar
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
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
                              Text(
                                plant.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.place,
                                      size: 16,
                                      color: Colors.white.withOpacity(0.9)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      plant.location,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.favorite_border,
                              color: Colors.white, size: 18),
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

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(18, topPad + 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Chat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text('To be implemented...', style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
class PlantAvatar extends StatelessWidget {
  final String? imagePath; // will be a local file path
  final double size;

  const PlantAvatar({
    super.key,
    required this.imagePath,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.green.withOpacity(0.12),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: hasImage
              ? Image.file(
                  File(imagePath!),
                  fit: BoxFit.cover,
                )
              : Container(
                  color: Colors.green.withOpacity(0.10),
                  child: Icon(
                    Icons.local_florist,
                    size: size * 0.55,
                    color: Colors.green.shade700.withOpacity(0.8),
                  ),
                ),
        ),
      ),
    );
  }
}
class PlantDetailsPage extends StatefulWidget {
  final Plant plant;
  const PlantDetailsPage({super.key, required this.plant});

  @override
  State<PlantDetailsPage> createState() => _PlantDetailsPageState();
}

class _PlantDetailsPageState extends State<PlantDetailsPage> {
  late Plant _plant;
   //may need to replace
  // Editable fields (blank allowed for now)
  final _speciesCtrl = TextEditingController();
  final _phCtrl = TextEditingController();
  final _moistureCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _phosphorousCtrl = TextEditingController();
  final _nitrogenCtrl = TextEditingController();
  final _potassiumCtrl = TextEditingController();

  final _picker = ImagePicker();

  Future<void> _confirmDeleteFromSheet() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete plant?'),
        content: Text('This will remove "${_plant.name}" from your list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      Navigator.pop(context);            // 1) close the edit sheet
      Navigator.pop(context, '__delete__'); // 2) return to Home with delete signal
    }
  }
  Future<String?> _getTopSpecies(String imagePath) async {
    final uri = Uri.parse("$serverBaseUrl/predict?top_k=1");

    final request = http.MultipartRequest("POST", uri);
    request.files.add(await http.MultipartFile.fromPath("file", imagePath));

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      throw Exception("Predict failed: ${resp.statusCode} ${resp.body}");
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    // your backend already returns "top"
    final raw = data["top"] as String?;

    if (raw == null) return null;

    // convert underscores to spaces
    String cleaned = raw.replaceAll('_', ' ');

    // optional: remove author abbreviation (last word if capitalized)
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

    // If it's like "Genus species Author", drop the author
    if (parts.length >= 3 && RegExp(r'^[A-Z]').hasMatch(parts.last)) {
      cleaned = '${parts[0]} ${parts[1]}';
    } else {
      cleaned = parts.join(' ');
    }

    return cleaned;
  }
  @override
  void initState() {
    super.initState();
    _plant = widget.plant;
  }

  @override
  void dispose() {
    _speciesCtrl.dispose();
    _phCtrl.dispose();
    _moistureCtrl.dispose();
    _tempCtrl.dispose();
    _phosphorousCtrl.dispose();
    _nitrogenCtrl.dispose();
    _potassiumCtrl.dispose();
    super.dispose();
  }

Widget _infoRow(String label, String value) {
  final display = (value.trim().isEmpty) ? '—' : value.trim();

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label takes ~55% width
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),

        const SizedBox(width: 12),

        // Value takes ~45% width and wraps nicely
        Expanded(
          flex: 4,
          child: Text(
            display,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

  Future<void> _openEditSheet() async {
    // Pre-fill controllers (currently blank by design; later you can store these in Plant)
    _speciesCtrl.text = _plant.species ?? '';
    _phCtrl.text = '';
    _moistureCtrl.text = '';
    _tempCtrl.text = '';
    _phosphorousCtrl.text = '';
    _nitrogenCtrl.text = '';
    _potassiumCtrl.text = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Edit Plant',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickFromLibrary,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Photo'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                TextField(
                  decoration: const InputDecoration(labelText: 'Species'),
                  controller: _speciesCtrl,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'pH'),
                  controller: _phCtrl,
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Soil Moisture (%)'),
                  controller: _moistureCtrl,
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Soil Temperature (C)'),
                  controller: _tempCtrl,
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Phosphorous (%)'),
                  controller: _phosphorousCtrl,
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Nitrogen (%)'),
                  controller: _nitrogenCtrl,
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Potassium (%)'),
                  controller: _potassiumCtrl,
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                          onPressed: () {
                            final species = _speciesCtrl.text.trim();

                            setState(() {
                              _plant = _plant.copyWith(species: species);
                            });

                            Navigator.pop(context);
                          },
                          child: const Text('Save'),
                        ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Plant'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: _confirmDeleteFromSheet,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Future<void> _pickFromLibrary() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    // show image immediately
    setState(() {
      _plant = _plant.copyWith(imagePath: picked.path);
    });

    // then update species automatically from top prediction
    try {
      final top = await _getTopSpecies(picked.path);
      if (!mounted) return;

      setState(() {
        final s = (top ?? '').trim();
        _plant = _plant.copyWith(species: s);
        _speciesCtrl.text = s; // keeps the Edit Sheet field in sync
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Species guess failed: $e")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      appBar: AppBar(
        title: Text(_plant.name),
        leading: BackButton(
          onPressed: () {
            Navigator.pop(context, _plant); // return the updated plant
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit),
            onPressed: _openEditSheet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, topPad + 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              Center(
                child: PlantAvatar(
                  imagePath: _plant.imagePath,
                  size: 260,
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Plant Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              // Values blank for now (we’ll store them in Plant later)
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
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlantHealthReportPage(plant: _plant),
                      ),
                    );
                  },
                  child: const Text(
                    'Health Report',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class Plant {
  final String name;
  final String location;
  final String? imagePath;   // local file path
  final String? species;     // guessed species label

  Plant({
    required this.name,
    required this.location,
    this.imagePath,
    this.species,
  });

  Plant copyWith({
    String? name,
    String? location,
    String? imagePath,
    String? species,
  }) {
    return Plant(
      name: name ?? this.name,
      location: location ?? this.location,
      imagePath: imagePath ?? this.imagePath,
      species: species ?? this.species,
    );
  }
}
class PlantHealthReportPage extends StatefulWidget {
  final Plant plant;

  const PlantHealthReportPage({
    super.key,
    required this.plant,
  });

  @override
  State<PlantHealthReportPage> createState() => _PlantHealthReportPageState();
}

class _PlantHealthReportPageState extends State<PlantHealthReportPage> {
  final ImagePicker _picker = ImagePicker();

  String? _leafImagePath;
  bool _loading = false;
  List<Map<String, dynamic>> _predictions = []; // [{label, score}, ...]

  Future<void> _pickLeafAndPredict() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() {
      _leafImagePath = picked.path;
      _loading = true;
      _predictions = [];
    });

    try {
      final uri = Uri.parse("$serverBaseUrl/disease_predict?top_k=3");
      final request = http.MultipartRequest("POST", uri);
      request.files.add(await http.MultipartFile.fromPath("file", picked.path));

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode != 200) {
        throw Exception("Disease predict failed: ${resp.statusCode} ${resp.body}");
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final preds = (data["predictions"] as List)
          .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
          .toList();

      if (!mounted) return;
      setState(() {
        _predictions = preds.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Disease detection failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.plant.name} Health Report'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, topPad + 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Health Report',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Plant: ${widget.plant.name}',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),

              const SizedBox(height: 18),

              // Leaf photo picker
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _pickLeafAndPredict,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_loading ? 'Detecting…' : 'Select leaf photo'),
                ),
              ),

              const SizedBox(height: 14),

              // Preview leaf image
              if (_leafImagePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 180,
                    child: Image.file(
                      File(_leafImagePath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Results
              const Text(
                'Disease Detection (Top 3)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              if (_loading)
                const Text('Analyzing image…', style: TextStyle(color: Colors.black54))
              else if (_predictions.isEmpty)
                const Text('No results yet. Select a leaf photo.', style: TextStyle(color: Colors.black54))
              else
                Column(
                  children: [
                    for (int i = 0; i < _predictions.length; i++)
                      _DiseaseRow(
                        rank: i + 1,
                        label: _predictions[i]["label"]?.toString() ?? "Unknown",
                        score: (_predictions[i]["score"] as num?)?.toDouble() ?? 0.0,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiseaseRow extends StatelessWidget {
  final int rank;
  final String label;
  final double score;

  const _DiseaseRow({
    required this.rank,
    required this.label,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (score * 100);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
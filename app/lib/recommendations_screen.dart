import 'package:flutter/material.dart';
import '../utils/recommendation.dart';
import '../utils/plant_api_service.dart';
import '../widgets/recommendation_card.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _api = PlantApiService();

  List<Recommendation> _alerts  = [];
  List<Plant>          _plants  = [];
  int?                 _selectedPlant;
  bool                 _loading = false;
  String?              _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.fetchRecommendations(plantId: _selectedPlant),
        _api.fetchPlants(),
      ]);
      setState(() {
        _alerts = results[0] as List<Recommendation>;
        _plants = results[1] as List<Plant>;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _onPlantSelected(int? plantId) async {
    setState(() => _selectedPlant = plantId);
    await _loadAll();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final urgent  = _alerts.where((a) => a.isUrgent).toList();
    final warning = _alerts.where((a) => !a.isUrgent).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Plant alerts',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _PlantFilterBar(
            plants: _plants,
            selected: _selectedPlant,
            onSelected: _onPlantSelected,
          ),
          Expanded(child: _buildBody(urgent, warning)),
        ],
      ),
    );
  }

  Widget _buildBody(
    List<Recommendation> urgent,
    List<Recommendation> warning,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _loadAll);
    }
    if (_alerts.isEmpty) {
      return const _EmptyView();
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (urgent.isNotEmpty) ...[
            _SectionHeader(
              label: 'Urgent',
              count: urgent.length,
              color: const Color(0xFFE24B4A),
            ),
            ...urgent.map((r) => RecommendationCard(rec: r)),
          ],
          if (warning.isNotEmpty) ...[
            _SectionHeader(
              label: 'Warnings',
              count: warning.length,
              color: const Color(0xFFBA7517),
            ),
            ...warning.map((r) => RecommendationCard(rec: r)),
          ],
        ],
      ),
    );
  }
}


// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PlantFilterBar extends StatelessWidget {
  final List<Plant> plants;
  final int?        selected;
  final void Function(int?) onSelected;

  const _PlantFilterBar({
    required this.plants,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (plants.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _FilterChip(
            label: 'All plants',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          ...plants.map((p) => _FilterChip(
                label: p.name,
                selected: selected == p.plantId,
                onTap: () => onSelected(p.plantId),
              )),
        ],
      ),
    );
  }
}


class _FilterChip extends StatelessWidget {
  final String label;
  final bool   selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF1D9E75);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.transparent,
          border: Border.all(
            color: selected ? activeColor : Colors.black26,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}


class _SectionHeader extends StatelessWidget {
  final String label;
  final int    count;
  final Color  color;
  const _SectionHeader({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}


class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🌿', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text(
            'No active alerts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'All plants are within normal ranges.',
            style: TextStyle(fontSize: 13, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}


class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.black26),
            const SizedBox(height: 12),
            const Text(
              'Could not reach backend',
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black38),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

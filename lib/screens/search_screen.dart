import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../services/api_service.dart';
import '../models/nursery_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final ApiService _apiService;

  // Tab 1 State
  List<NurseryModel>? _allNurseries;
  NurseryModel? _selectedNursery;
  List<Map<String, dynamic>>? _nurseryPlantsResults;
  bool _isLoadingNursery = true;

  // Tab 2 State
  final TextEditingController _plantNameController = TextEditingController();
  List<Map<String, dynamic>>? _plantSearchResults;
  bool _isSearchingPlant = false;

  // Tab 3 State
  final TextEditingController _plantNameSizeController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  List<Map<String, dynamic>>? _plantSizeSearchResults;
  bool _isSearchingPlantSize = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _apiService = ApiService(ApiClient());
    _loadNurseries();
  }

  Future<void> _loadNurseries() async {
    try {
      final nurseries = await _apiService.fetchNurseries();
      if (mounted) {
        setState(() {
          _allNurseries = nurseries;
          _isLoadingNursery = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingNursery = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading nurseries: $e')));
      }
    }
  }

  Future<void> _searchNurseryPlants(NurseryModel nursery) async {
    setState(() {
      _selectedNursery = nursery;
      _nurseryPlantsResults = null;
    });
    final results = await _apiService.searchPlantsByNursery(nursery.nurseryId);
    if (mounted) {
      setState(() {
        _nurseryPlantsResults = results;
      });
    }
  }

  Future<void> _searchByPlant() async {
    if (_plantNameController.text.trim().isEmpty) return;
    setState(() {
      _isSearchingPlant = true;
      _plantSearchResults = null;
    });
    final results = await _apiService.searchByPlant(_plantNameController.text.trim());
    if (mounted) {
      setState(() {
        _plantSearchResults = results;
        _isSearchingPlant = false;
      });
    }
  }

  Future<void> _searchByPlantAndSize() async {
    if (_plantNameSizeController.text.trim().isEmpty || _sizeController.text.trim().isEmpty) return;
    final size = double.tryParse(_sizeController.text.trim());
    if (size == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid numeric size.')));
      return;
    }

    setState(() {
      _isSearchingPlantSize = true;
      _plantSizeSearchResults = null;
    });
    final results = await _apiService.searchByPlantAndSize(_plantNameSizeController.text.trim(), size);
    if (mounted) {
      setState(() {
        _plantSizeSearchResults = results;
        _isSearchingPlantSize = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Search'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(text: 'By Nursery', icon: Icon(Icons.park)),
            Tab(text: 'By Plant', icon: Icon(Icons.eco)),
            Tab(text: 'Plant & Size', icon: Icon(Icons.straighten)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNurseryTab(),
          _buildPlantTab(),
          _buildPlantSizeTab(),
        ],
      ),
    );
  }

  Widget _buildNurseryTab() {
    if (_isLoadingNursery) return const Center(child: CircularProgressIndicator());
    if (_allNurseries == null || _allNurseries!.isEmpty) {
      return const Center(child: Text('No nurseries found.'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButtonFormField<NurseryModel>(
            decoration: const InputDecoration(
              labelText: 'Select a Nursery',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
            items: _allNurseries!.map((n) {
              return DropdownMenuItem(
                value: n,
                child: Text(n.name),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _searchNurseryPlants(val);
            },
          ),
        ),
        const Divider(),
        Expanded(
          child: _nurseryPlantsResults == null
              ? const Center(child: Text('Select a nursery to view plants'))
              : _nurseryPlantsResults!.isEmpty
                  ? const Center(child: Text('No plants logged in this nursery.'))
                  : ListView.builder(
                      itemCount: _nurseryPlantsResults!.length,
                      itemBuilder: (context, index) {
                        final plant = _nurseryPlantsResults![index];
                        return ListTile(
                          leading: const Icon(Icons.eco, color: Colors.green),
                          title: Text(plant['CommonName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Size: ${plant['SizingMetric']}  |  Bag: ${plant['BagSize']}'),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPlantTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _plantNameController,
                  decoration: const InputDecoration(
                    labelText: 'Plant Name (e.g. Mango)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _searchByPlant(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _searchByPlant,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: _isSearchingPlant
              ? const Center(child: CircularProgressIndicator())
              : _plantSearchResults == null
                  ? const Center(child: Text('Enter a plant name to search.'))
                  : _plantSearchResults!.isEmpty
                      ? const Center(child: Text('No nurseries found carrying this plant.'))
                      : ListView.builder(
                          itemCount: _plantSearchResults!.length,
                          itemBuilder: (context, index) {
                            final nurseryData = _plantSearchResults![index];
                            final List<dynamic> plants = nurseryData['plants'] ?? [];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ExpansionTile(
                                leading: const Icon(Icons.store, color: Colors.indigo),
                                title: Text(nurseryData['Name'] ?? 'Unknown Nursery', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Farmer: ${nurseryData['FarmerName'] ?? 'N/A'}'),
                                children: plants.map((p) {
                                  return ListTile(
                                    title: Text(p['CommonName'] ?? 'Unknown'),
                                    trailing: Text('Size: ${p['SizingMetric']} (Bag: ${p['BagSize']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildPlantSizeTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _plantNameSizeController,
                  decoration: const InputDecoration(
                    labelText: 'Plant Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _sizeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Size (Metric)',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _searchByPlantAndSize(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _searchByPlantAndSize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Icon(Icons.search),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: _isSearchingPlantSize
              ? const Center(child: CircularProgressIndicator())
              : _plantSizeSearchResults == null
                  ? const Center(child: Text('Enter plant name and numeric size to search.'))
                  : _plantSizeSearchResults!.isEmpty
                      ? const Center(child: Text('No exact matches found for this size.'))
                      : ListView.builder(
                          itemCount: _plantSizeSearchResults!.length,
                          itemBuilder: (context, index) {
                            final match = _plantSizeSearchResults![index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: const Icon(Icons.check_circle, color: Colors.green),
                                title: Text(match['Name'] ?? 'Unknown Nursery', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Farmer: ${match['FarmerName'] ?? 'N/A'}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${match['MatchedSize']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('${match['MatchedBagSize']}'),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

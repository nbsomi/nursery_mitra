import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiService _apiService;
  late Future<Map<String, dynamic>> _telemetryFuture;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(ApiClient());
    _loadTelemetry();
  }

  void _loadTelemetry() {
    setState(() {
      _telemetryFuture = _apiService.fetchStatsTelemetry();
    });
  }

  Future<void> _handleRefresh() async {
    _loadTelemetry();
    await _telemetryFuture.catchError((_) {}); // Prevent error from breaking refresh indicator animation
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nursery Mitra Dashboard'),
        centerTitle: true,
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTelemetryCard(),
              const SizedBox(height: 24),
              _buildActionGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _telemetryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 140,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return SizedBox(
                height: 140,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.red, size: 36),
                      const SizedBox(height: 12),
                      Text(
                        'Unable to connect to tunnel.\nPull down to retry.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data ?? {};
            final int totalNurseries = data['totalNurseries'] ?? 0;
            final int totalPlants = data['totalPlants'] ?? 0;
            final String lastSync = data['lastSyncTimestamp'] ?? 'Never';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Live Telemetry',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Nurseries', totalNurseries.toString(), Icons.park),
                    _buildStatItem('Tracked Plants', totalPlants.toString(), Icons.eco),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Last Server Sync: $lastSync',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 36, color: Colors.green.shade600),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildActionTile(
          context,
          title: 'Start New\nField Visit',
          icon: Icons.add_location_alt,
          color: Colors.teal,
          onTap: () {
            // Routing placeholder linking forward to the setup phase
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Navigating to Field Visit Setup...')),
            );
          },
        ),
        _buildActionTile(
          context,
          title: 'System\nOperational Settings',
          icon: Icons.settings_applications,
          color: Colors.blueGrey,
          onTap: () {
            // Future management configurations routing
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening Operational Settings...')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.4), width: 2.0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color.withOpacity(0.9)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

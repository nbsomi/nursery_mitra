import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_config.dart';
import '../core/network/api_client.dart';
import '../services/api_service.dart';
import 'nursery_setup_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  final int _sessionNurseriesAdded = 0;
  final int _sessionPlantsAdded = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nursery Mitra Dashboard'),
        centerTitle: true,
        elevation: 2,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green.shade700,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.spa, color: Colors.white, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Nursery Mitra',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Session Stats'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Current Session Stats'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.park, color: Colors.green),
                          title: const Text('Nurseries Added'),
                          trailing: Text('$_sessionNurseriesAdded', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                        ListTile(
                          leading: const Icon(Icons.eco, color: Colors.teal),
                          title: const Text('Plants Captured'),
                          trailing: Text('$_sessionPlantsAdded', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                        const Divider(),
                        const Text('Stats are only tracked for this active session.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.system_update),
              title: const Text('Check for OTA Update'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _checkForUpdates(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening Settings...')),
                );
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            _buildActionGrid(context),
          ],
        ),
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Text('Checking server for updates...'),
          ],
        ),
      ),
    );

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersion = packageInfo.version;

      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/ota/latest'));
      
      if (context.mounted) Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final remoteVersion = data['version'] as String;
        final downloadUrlPath = data['download_url'] as String;

        // Simple string comparison for versions (e.g. "1.0.1" != "1.0.0")
        if (remoteVersion != localVersion) {
          if (!context.mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Update Available!'),
              content: Text('A new version ($remoteVersion) is available. Would you like to download and install it now?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final fullUrl = '${AppConfig.baseUrl}$downloadUrlPath';
                    final uri = Uri.parse(fullUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open download link.')),
                        );
                      }
                    }
                  },
                  child: const Text('Download'),
                ),
              ],
            ),
          );
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('System is up to date. (v$localVersion)'), backgroundColor: Colors.green),
            );
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to check for updates (Server error).'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check for updates: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NurserySetupScreen(),
              ),
            );
          },
        ),
        _buildActionTile(
          context,
          title: 'Database Search',
          icon: Icons.manage_search,
          color: Colors.indigo,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
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
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.2),
        highlightColor: color.withValues(alpha: 0.1),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.4), width: 2.0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color.withValues(alpha: 0.9)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

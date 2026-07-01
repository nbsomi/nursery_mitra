import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';

import '../core/network/api_client.dart';
import '../services/api_service.dart';
import '../models/nursery_model.dart';
import 'plant_capture_screen.dart';

class NurserySetupScreen extends StatefulWidget {
  const NurserySetupScreen({Key? key}) : super(key: key);

  @override
  State<NurserySetupScreen> createState() => _NurserySetupScreenState();
}

class _NurserySetupScreenState extends State<NurserySetupScreen> {
  late final ApiService _apiService;

  // Location State
  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  bool _locationPermissionGranted = false;

  // Form State
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _farmerNameController = TextEditingController();
  int _selectedMethod = 0; // 0: Auto, 1: Manual, 2: Existing
  bool _isLoading = false;
  Future<List<NurseryModel>>? _nurseriesFuture;
  NurseryModel? _selectedNursery;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(ApiClient());
    _nameController.addListener(_onFormChanged);
    _farmerNameController.addListener(_onFormChanged);
    _checkPermissionsAndStartLocation();
    _nurseriesFuture = _apiService.fetchNurseries();
    _nurseriesFuture!.then((nurseries) {
      if (mounted && _currentPosition != null) {
        final tenAcres = 113.5;
        final hasNearby = nurseries.any((n) => Geolocator.distanceBetween(
              _currentPosition!.latitude, _currentPosition!.longitude,
              n.latitude, n.longitude) <= tenAcres);
        setState(() {
          _selectedMethod = hasNearby ? 2 : 0;
        });
      }
    });
  }

  void _onFormChanged() {
    setState(() {}); // Trigger rebuild to evaluate validation rules dynamically
  }

  Future<void> _checkPermissionsAndStartLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorDialog('Location services are disabled on your device. Please enable them in settings.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorDialog('Location permissions are denied. The app requires GPS to tag the nursery.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorDialog('Location permissions are permanently denied. Please enable them in system settings.');
      return;
    }

    setState(() {
      _locationPermissionGranted = true;
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _nameController.dispose();
    _farmerNameController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Access Denied'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  Future<bool> _shouldProceedWithCreation() async {
    if (_currentPosition == null) return true; // Can't check without GPS

    List<NurseryModel> nurseries = [];
    try {
      nurseries = await (_nurseriesFuture ?? Future.value([]));
    } catch (e) {
      // If fetching fails, proceed anyway
      return true;
    }

    final double tenAcresRadiusMeters = 113.5;
    final nearbyNurseries = nurseries.where((n) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        n.latitude,
        n.longitude,
      );
      return distance <= tenAcresRadiusMeters;
    }).toList();

    if (nearbyNurseries.isEmpty) return true;

    bool proceed = false;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Similar Nursery Nearby'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('We found existing nurseries within 10 acres. Are you sure you want to create a new one instead of using an existing one?'),
            const SizedBox(height: 12),
            ...nearbyNurseries.map((n) => Text('• ${n.name}', style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              proceed = false;
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              proceed = true;
            },
            child: const Text('Create Anyway'),
          ),
        ],
      ),
    );

    return proceed;
  }

  Future<void> _captureSignboard() async {
    if (!await _shouldProceedWithCreation()) return;

    List<CameraDescription> cameras = [];
    try {
      cameras = await availableCameras();
    } catch (e) {
      _showErrorDialog('Error detecting cameras: $e');
      return;
    }

    if (cameras.isEmpty) {
      _showErrorDialog('No cameras available on this device.');
      return;
    }

    if (!mounted) return;

    // Await camera interface capturing an image
    final String? imagePath = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraCaptureScreen(camera: cameras.first),
      ),
    );

    if (imagePath != null) {
      _uploadSignboard(imagePath);
    }
  }

  Future<void> _uploadSignboard(String path) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final nursery = await _apiService.submitNurserySignboard(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nursery Profile Created: ${nursery.name}')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PlantCaptureScreen(
              nursery: nursery,
              visitId: DateTime.now().millisecondsSinceEpoch.toString(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Signboard upload failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitManualEntry() async {
    if (_currentPosition == null) return;
    if (!await _shouldProceedWithCreation()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nursery = await _apiService.submitGeoTaggedNursery(
        _nameController.text.trim(),
        _farmerNameController.text.trim().isNotEmpty ? _farmerNameController.text.trim() : null,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Manual Nursery Created: ${nursery.name}')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PlantCaptureScreen(
              nursery: nursery,
              visitId: DateTime.now().millisecondsSinceEpoch.toString(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Manual submission failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isManualFormValid() {
    if (_nameController.text.trim().isEmpty) return false;
    if (_currentPosition == null) return false;
    if (_currentPosition!.accuracy >= 15.0) return false; // Strict spatial validation
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nursery Setup Environment'),
        elevation: 2,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTelemetryBanner(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMethodToggle(),
                      const SizedBox(height: 24),
                      if (_selectedMethod == 0) _buildMethodAUI(),
                      if (_selectedMethod == 1) _buildMethodBUI(),
                      if (_selectedMethod == 2) _buildMethodCUI(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTelemetryBanner() {
    return Container(
      width: double.infinity,
      color: Colors.blueGrey.shade900,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Real-time Spatial Telemetry',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          if (_currentPosition != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAT: ${_currentPosition!.latitude.toStringAsFixed(5)}',
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                    ),
                    Text(
                      'LNG: ${_currentPosition!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _currentPosition!.accuracy < 15.0 ? Colors.green.shade700 : Colors.red.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ACC: ${_currentPosition!.accuracy.toStringAsFixed(1)} m',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            )
          else
            const Text(
              'Awaiting GPS fix...',
              style: TextStyle(color: Colors.orangeAccent),
            ),
        ],
      ),
    );
  }

  Widget _buildMethodToggle() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(
          value: 0,
          label: Text('Auto'),
          icon: Icon(Icons.camera_alt),
        ),
        ButtonSegment(
          value: 1,
          label: Text('Manual'),
          icon: Icon(Icons.edit_location_alt),
        ),
        ButtonSegment(
          value: 2,
          label: Text('Existing'),
          icon: Icon(Icons.list),
        ),
      ],
      selected: {_selectedMethod},
      onSelectionChanged: (Set<int> newSelection) {
        setState(() {
          _selectedMethod = newSelection.first;
        });
      },
    );
  }

  Widget _buildMethodAUI() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.document_scanner, size: 64, color: Colors.teal),
            const SizedBox(height: 16),
            const Text(
              'Capture Nursery Signboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Take a clear picture of the signboard to automatically create the nursery profile and extract metadata.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _captureSignboard,
                icon: const Icon(Icons.camera),
                label: const Text('Capture Signboard Image', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodBUI() {
    final bool isValid = _isManualFormValid();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manual Geo-Tagged Entry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Only use this method if the signboard OCR fails or is missing. Requires < 15m GPS accuracy to proceed.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nursery Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.park),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _farmerNameController,
              decoration: InputDecoration(
                labelText: 'Farmer Name (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isValid ? _submitManualEntry : null,
                icon: const Icon(Icons.save),
                label: const Text('Geo-Tag & Save Nursery', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodCUI() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Existing Nursery',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose an already registered nursery from the database to continue your field visit.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<NurseryModel>>(
              future: _nurseriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error loading nurseries: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                }
                final allNurseries = snapshot.data ?? [];
                
                // 10 acres is ~40,468.6 square meters. 
                // A circle with this area has a radius of ~113.5 meters.
                final double tenAcresRadiusMeters = 113.5;
                
                final nurseries = _currentPosition != null 
                    ? allNurseries.where((n) {
                        final distance = Geolocator.distanceBetween(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                          n.latitude,
                          n.longitude,
                        );
                        return distance <= tenAcresRadiusMeters;
                      }).toList()
                    : <NurseryModel>[]; // Wait for GPS to filter

                if (_currentPosition == null) {
                  return const Text('Awaiting GPS fix to locate nearby nurseries...', style: TextStyle(color: Colors.orangeAccent));
                }
                
                if (nurseries.isEmpty) {
                  return const Text('No nurseries found within 10 acres of your current location.');
                }
                
                // Ensure the selected nursery is still in the filtered list, otherwise reset it
                if (_selectedNursery != null && !nurseries.contains(_selectedNursery)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _selectedNursery = null);
                  });
                }

                return DropdownButtonFormField<NurseryModel>(
                  decoration: InputDecoration(
                    labelText: 'Nursery',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.park),
                  ),
                  value: _selectedNursery,
                  items: nurseries.map((n) {
                    return DropdownMenuItem<NurseryModel>(
                      value: n,
                      child: Text(n.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedNursery = val;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _selectedNursery != null ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Selected Nursery: ${_selectedNursery!.name}')),
                  );
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlantCaptureScreen(
                        nursery: _selectedNursery!,
                        visitId: DateTime.now().millisecondsSinceEpoch.toString(),
                      ),
                    ),
                  );
                } : null,
                icon: const Icon(Icons.check),
                label: const Text('Confirm Selection', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Inline Camera Screen to prevent truncation and provide full functionality
class CameraCaptureScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraCaptureScreen({Key? key, required this.camera}) : super(key: key);

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Capture Signboard Image'),
        backgroundColor: Colors.black,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Center(
              child: CameraPreview(_controller),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            final image = await _controller.takePicture();
            if (context.mounted) {
              Navigator.pop(context, image.path); // Return the image path to the setup screen
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to take picture: $e')),
              );
            }
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';

import '../core/network/api_client.dart';
import '../services/api_service.dart';

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
  bool _isMethodA = true; // true for Signboard OCR, false for Manual Tag
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(ApiClient());
    _nameController.addListener(_onFormChanged);
    _checkPermissionsAndStartLocation();
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

  Future<void> _captureSignboard() async {
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
        Navigator.pop(context); // Advance workflow upon completion
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

    setState(() {
      _isLoading = true;
    });

    try {
      final nursery = await _apiService.submitGeoTaggedNursery(
        _nameController.text.trim(),
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Manual Nursery Created: ${nursery.name}')),
        );
        Navigator.pop(context); // Advance workflow upon completion
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
                      if (_isMethodA) _buildMethodAUI() else _buildMethodBUI(),
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
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: true,
          label: Text('Signboard OCR (Auto)'),
          icon: Icon(Icons.camera_alt),
        ),
        ButtonSegment(
          value: false,
          label: Text('Manual Tag (Backup)'),
          icon: Icon(Icons.edit_location_alt),
        ),
      ],
      selected: {_isMethodA},
      onSelectionChanged: (Set<bool> newSelection) {
        setState(() {
          _isMethodA = newSelection.first;
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

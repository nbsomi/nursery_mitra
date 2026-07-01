import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'package:geolocator/geolocator.dart';

import '../core/constants/app_config.dart';
import '../core/network/api_client.dart';
import '../models/observation_payload.dart';
import '../models/nursery_model.dart';
import '../services/api_service.dart';
import 'review_screen.dart';

class PlantCaptureScreen extends StatefulWidget {
  final NurseryModel nursery;
  final String visitId;

  const PlantCaptureScreen({
    Key? key,
    required this.nursery,
    required this.visitId,
  }) : super(key: key);

  @override
  State<PlantCaptureScreen> createState() => _PlantCaptureScreenState();
}

class _PlantCaptureScreenState extends State<PlantCaptureScreen> {
  late final ApiService _apiService;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(ApiClient());
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndSubmit() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // SAFE CHECK: Geolocation
      bool isOutOfRange = false;
      try {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          widget.nursery.latitude,
          widget.nursery.longitude,
        );
        if (distance > 113.5) {
          isOutOfRange = true;
        }
      } catch (e) {
        debugPrint('Safe check GPS failed: $e');
      }

      if (isOutOfRange) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          
          bool proceed = false;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Out of Range Warning'),
              content: Text('You appear to be more than 10 acres away from ${widget.nursery.name}. Are you sure you want to add this plant to this nursery?'),
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
                  child: const Text('Yes, Continue'),
                ),
              ],
            ),
          );
          if (!proceed) return;
          
          setState(() {
            _isSubmitting = true;
          });
        }
      }

      final image = await _cameraController!.takePicture();
      
      final payload = ObservationPayload(
        visitId: widget.visitId,
        nurseryId: widget.nursery.nurseryId,
        plantName: '',
        plantHeight: '',
        bagSize: '',
        remarks: '',
      );

      if (AppConfig.processingTiming == ProcessingTiming.later) {
        // Path A: ProcessingTiming.later
        await _apiService.sendObservationStream(payload, image.path, false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Photo captured and saved for batch processing.'),
              backgroundColor: Colors.green.shade800,
            ),
          );
        }
      } else {
        // Path B: ProcessingTiming.immediate
        final review = await _apiService.sendObservationStream(
          payload,
          image.path,
          false,
        );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReviewScreen(reviewItem: review),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Network Error'),
            content: Text('Failed to deliver payload to backend. Ensure tunnel is active.\n\nError: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Plant Observation'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Banner for Nursery details
              Container(
                color: Colors.green.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📍 ${widget.nursery.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (widget.nursery.farmerName.isNotEmpty)
                            Text(
                              'Farmer: ${widget.nursery.farmerName}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Change'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.black,
                  child: _isCameraInitialized
                      ? Center(
                          child: AspectRatio(
                            aspectRatio: 1 / _cameraController!.value.aspectRatio,
                            child: CameraPreview(_cameraController!),
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.amber),
                        ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.white,
                child: SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _captureAndSubmit,
                    icon: const Icon(Icons.camera_alt, size: 28),
                    label: Text(
                      _isSubmitting ? 'Processing...' : 'Capture Photo',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          if (_isSubmitting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              ),
            ),
        ],
      ),
    );
  }

}

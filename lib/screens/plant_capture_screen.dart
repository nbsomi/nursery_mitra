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
  
  final TextEditingController _plantNameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _bagSizeController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  bool _autoApprove = false;
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
    _plantNameController.dispose();
    _heightController.dispose();
    _bagSizeController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _captureAndSubmit() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
    if (_plantNameController.text.trim().isEmpty || _heightController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill out Plant Name and Height.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

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
        plantName: _plantNameController.text.trim(),
        plantHeight: _heightController.text.trim(),
        bagSize: _bagSizeController.text.trim(),
        remarks: _remarksController.text.trim(),
      );

      if (AppConfig.processingTiming == ProcessingTiming.later) {
        // Path A: ProcessingTiming.later
        await _apiService.sendObservationStream(payload, image.path, _autoApprove);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Observation saved for later processing.'),
              backgroundColor: Colors.green.shade800,
            ),
          );
          _plantNameController.clear();
          _heightController.clear();
          _bagSizeController.clear();
          _remarksController.clear();
        }
      } else {
        // Path B: ProcessingTiming.immediate
        final review = await _apiService.sendObservationStream(
          payload,
          image.path,
          _autoApprove,
        );

        if (mounted) {
          if (_autoApprove) {
            // Sub-Path 1: Auto-Approve ON
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Success! Data integrated immediately.'),
                backgroundColor: Colors.green.shade800,
              ),
            );
            Navigator.pop(context); // Go back to Home Dashboard
          } else {
            // Sub-Path 2: Auto-Approve OFF
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReviewScreen(reviewItem: review),
              ),
            );
          }
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
    // Track keyboard height to dynamically shrink the camera view and keep inputs visible
    final screenHeight = MediaQuery.of(context).size.height;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    
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
                child: Column(
                  children: [
                    // Live Viewfinder (Upper Half)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      height: viewInsets > 0 ? screenHeight * 0.15 : screenHeight * 0.35,
                      width: double.infinity,
                      color: Colors.black,
                      child: _isCameraInitialized
                          ? CameraPreview(_cameraController!)
                          : const Center(
                              child: CircularProgressIndicator(color: Colors.amber),
                            ),
                    ),
                    
                    // Data Entry Sheet (Lower Half)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTextField(
                              controller: _plantNameController,
                              label: 'Plant Name',
                              icon: Icons.local_florist,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _heightController,
                                    label: 'Height Dimensions (cm)',
                                    icon: Icons.height,
                                    inputType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _bagSizeController,
                                    label: 'Bag Size',
                                    icon: Icons.shopping_bag,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _remarksController,
                              label: 'General Remarks',
                              icon: Icons.notes,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 24),
                            
                            // The Bypass Toggle Engine
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.amber.shade700, width: 2),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.amber.withOpacity(0.1),
                              ),
                              child: SwitchListTile(
                                title: const Text(
                                  'Auto-Approve Data Entry',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: const Text('Commit directly without manual review phase'),
                                activeColor: Colors.amber.shade700,
                                value: _autoApprove,
                                onChanged: (bool value) {
                                  setState(() {
                                    _autoApprove = value;
                                  });
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting ? null : _captureAndSubmit,
                                icon: const Icon(Icons.cloud_upload),
                                label: Text(
                                  _isSubmitting ? 'Uploading Data...' : 'Capture & Submit',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade800,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: maxLines == 1 ? Icon(icon, color: Colors.green.shade700) : null,
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade800, width: 2),
        ),
      ),
    );
  }
}

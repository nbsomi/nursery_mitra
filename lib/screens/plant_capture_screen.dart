import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  
  final List<XFile> _capturedImages = [];
  bool _isLiveCamera = true;
  int _currentPreviewIndex = 0;
  late PageController _pageController;
  
  bool _isSubmitting = false;

  int _plantSeq = 1;
  int _imageSeq = 1;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(ApiClient());
    _pageController = PageController(initialPage: 0);
    _loadSequences();
    _initializeCamera();
  }

  Future<void> _loadSequences() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${widget.nursery.nurseryId}_plantSeq';
    if (mounted) {
      setState(() {
        _plantSeq = prefs.getInt(key) ?? 1;
      });
    }
  }

  Future<void> _nextPlant() async {
    if (_capturedImages.isNotEmpty) {
       // Just in case they click Next Plant while they have unuploaded images
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Please upload or delete current photos first.')),
       );
       return;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = '${widget.nursery.nurseryId}_plantSeq';
    setState(() {
      _plantSeq++;
      _imageSeq = 1;
      _capturedImages.clear();
      _isLiveCamera = true;
    });
    await prefs.setInt(key, _plantSeq);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Started Plant #$_plantSeq')),
      );
    }
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
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_capturedImages.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 images allowed per upload.')),
      );
      return;
    }
    
    try {
      final image = await _cameraController!.takePicture();
      setState(() {
        _capturedImages.add(image);
        _isLiveCamera = false;
        _currentPreviewIndex = _capturedImages.length - 1;
      });
      // Delay jumping to page until the PageView is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentPreviewIndex);
        }
      });
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  void _deleteImage(int index) {
    setState(() {
      _capturedImages.removeAt(index);
      if (_capturedImages.isEmpty) {
        _isLiveCamera = true;
      } else {
        if (_currentPreviewIndex >= _capturedImages.length) {
          _currentPreviewIndex = _capturedImages.length - 1;
        }
      }
    });
  }

  Future<void> _uploadImage() async {
    if (_capturedImages.isEmpty) return;

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
              content: Text('You appear to be more than 10 acres away from ${widget.nursery.name}. Are you sure you want to add these plants to this nursery?'),
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
      
      dynamic lastReview;

      for (int i = 0; i < _capturedImages.length; i++) {
        final payload = ObservationPayload(
          visitId: widget.visitId,
          nurseryId: widget.nursery.nurseryId,
          plantName: '${widget.nursery.nurseryId}_plant_${_plantSeq}_${_imageSeq}',
          plantHeight: '',
          bagSize: '',
          remarks: '',
        );

        if (AppConfig.processingTiming == ProcessingTiming.later) {
          // Path A: ProcessingTiming.later
          await _apiService.sendObservationStream(payload, _capturedImages[i].path, false);
        } else {
          // Path B: ProcessingTiming.immediate
          lastReview = await _apiService.sendObservationStream(
            payload,
            _capturedImages[i].path,
            false,
          );
        }
        
        setState(() {
          _imageSeq++;
        });
      }

      if (mounted) {
        if (AppConfig.processingTiming == ProcessingTiming.later) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_capturedImages.length} photo(s) captured and saved for batch processing.'),
              backgroundColor: Colors.green.shade800,
            ),
          );
          setState(() {
            _capturedImages.clear();
            _isLiveCamera = true;
          });
        } else {
          setState(() {
            _capturedImages.clear();
            _isLiveCamera = true;
          });
          // Show the review screen for the last item (as a placeholder for Real Time Review)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReviewScreen(reviewItem: lastReview),
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
                            '📍 ${widget.nursery.name} (Plant #$_plantSeq)',
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
                  child: !_isLiveCamera && _capturedImages.isNotEmpty
                      ? PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPreviewIndex = index;
                            });
                          },
                          itemCount: _capturedImages.length,
                          itemBuilder: (context, index) {
                            return Center(
                              child: AspectRatio(
                                aspectRatio: 1 / _cameraController!.value.aspectRatio,
                                child: Image.file(
                                  File(_capturedImages[index].path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        )
                      : _isCameraInitialized
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
                color: Colors.white,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: !_isLiveCamera && _capturedImages.isNotEmpty
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 64,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _capturedImages.length + (_capturedImages.length < 10 ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index == _capturedImages.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _isLiveCamera = true;
                                            });
                                          },
                                          child: Container(
                                            width: 64,
                                            height: 64,
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey.shade400, width: 2),
                                              borderRadius: BorderRadius.circular(8),
                                              color: Colors.grey.shade200,
                                            ),
                                            child: const Icon(Icons.add, size: 32, color: Colors.grey),
                                          ),
                                        ),
                                      );
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Stack(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                                            },
                                            child: Container(
                                              width: 64,
                                              height: 64,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: _currentPreviewIndex == index ? Colors.green.shade800 : Colors.transparent,
                                                  width: 3,
                                                ),
                                                borderRadius: BorderRadius.circular(8),
                                                image: DecorationImage(
                                                  image: FileImage(File(_capturedImages[index].path)),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: GestureDetector(
                                              onTap: () => _deleteImage(index),
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.red,
                                                ),
                                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton.icon(
                                  onPressed: _isSubmitting ? null : _uploadImage,
                                  icon: const Icon(Icons.cloud_upload),
                                  label: Text(
                                    _isSubmitting ? 'Uploading...' : 'Upload (${_capturedImages.length})',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade800,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: SizedBox(
                                  height: 64,
                                  child: OutlinedButton(
                                    onPressed: _isSubmitting ? null : _nextPlant,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green.shade800,
                                      side: BorderSide(color: Colors.green.shade800, width: 2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: const Text('Next\nPlant', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 64,
                                  child: ElevatedButton.icon(
                                    onPressed: _isSubmitting ? null : _takePicture,
                                    icon: const Icon(Icons.camera_alt, size: 24),
                                    label: Text(
                                      _isSubmitting ? 'Wait...' : 'Capture Photo',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

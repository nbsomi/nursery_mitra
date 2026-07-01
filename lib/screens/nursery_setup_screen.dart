import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'package:geocoding/geocoding.dart';

import '../core/network/api_client.dart';
import '../services/api_service.dart';
import '../models/nursery_model.dart';
import 'plant_capture_screen.dart';
import 'package:latlong2/latlong.dart';
import 'location_picker_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NurserySetupScreen extends StatefulWidget {
  const NurserySetupScreen({super.key});

  @override
  State<NurserySetupScreen> createState() => _NurserySetupScreenState();
}

class _NurserySetupScreenState extends State<NurserySetupScreen> {
  late final ApiService _apiService;

  // Location State
  Position? _currentPosition;
  LatLng? _pickedLocation;
  StreamSubscription<Position>? _positionStream;
  String? _resolvedAddress;
  bool _hasInitialGeocode = false;

  // Form State
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _farmerNameController = TextEditingController();
  final TextEditingController _phone1Controller = TextEditingController();
  final TextEditingController _phone2Controller = TextEditingController();
  int _selectedMethod = 2; // 0: Auto, 1: Manual, 2: Existing
  bool _isLoading = false;
  Future<List<NurseryModel>>? _nurseriesFuture;
  NurseryModel? _selectedNursery;
  String _geocodingProvider = 'Merged';

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(ApiClient());
    _nameController.addListener(_onFormChanged);
    _farmerNameController.addListener(_onFormChanged);
    _phone1Controller.addListener(_onFormChanged);
    _phone2Controller.addListener(_onFormChanged);
    _checkPermissionsAndStartLocation();
    _nurseriesFuture = _apiService.fetchNurseries();
    _nurseriesFuture!.then((nurseries) {
      if (mounted && _currentPosition != null) {
        // Telemetry available, keeping default to Existing (2)
      }
    });
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _geocodingProvider = prefs.getString('geocodingProvider') ?? 'Merged';
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

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      if (!_hasInitialGeocode && _pickedLocation == null) {
        _hasInitialGeocode = true;
        _updateAddress(position.latitude, position.longitude);
      }
    });
  }

  Future<void> _updateAddress(double lat, double lng) async {
    try {
      final List<String> microLocalities = [];
      final List<String> macroLocalities = [];
      final List<String> states = [];

      Future<void> fetchNominatim() async {
        try {
          final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');
          final response = await http.get(url, headers: {'User-Agent': 'NurseryMitra/1.0'}).timeout(const Duration(seconds: 4));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['address'] != null) {
              final addr = data['address'];
              if (addr['village'] != null) microLocalities.add(addr['village']);
              if (addr['hamlet'] != null) microLocalities.add(addr['hamlet']);
              if (addr['suburb'] != null) microLocalities.add(addr['suburb']);
              if (addr['neighbourhood'] != null) microLocalities.add(addr['neighbourhood']);
              if (addr['road'] != null) microLocalities.add(addr['road']);
              
              if (addr['city'] != null) macroLocalities.add(addr['city']);
              if (addr['county'] != null) macroLocalities.add(addr['county']);
              
              if (addr['state'] != null) states.add(addr['state']);
            }
          }
        } catch (e) {
          debugPrint('Nominatim error: $e');
        }
      }

      Future<void> fetchBigDataCloud() async {
        try {
          final url = Uri.parse('https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=en');
          final response = await http.get(url).timeout(const Duration(seconds: 4));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['locality'] != null) microLocalities.add(data['locality']);
            if (data['city'] != null) macroLocalities.add(data['city']);
            if (data['principalSubdivision'] != null) states.add(data['principalSubdivision']);
          }
        } catch (e) {
          debugPrint('BigDataCloud error: $e');
        }
      }

      Future<void> fetchNativeGeocoding() async {
        try {
          final placemarks = await placemarkFromCoordinates(lat, lng).timeout(const Duration(seconds: 4));
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            if (place.name != null && place.name!.isNotEmpty) microLocalities.add(place.name!);
            if (place.street != null && place.street!.isNotEmpty) microLocalities.add(place.street!);
            if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) microLocalities.add(place.thoroughfare!);
            if (place.subLocality != null && place.subLocality!.isNotEmpty) microLocalities.add(place.subLocality!);
            if (place.locality != null && place.locality!.isNotEmpty) macroLocalities.add(place.locality!);
            if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) macroLocalities.add(place.subAdministrativeArea!);
            if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) states.add(place.administrativeArea!);
          }
        } catch (e) {
          debugPrint('Native Geocoding error: $e');
        }
      }

      // Run geocoding service based on selection
      if (_geocodingProvider == 'Nominatim') {
        await fetchNominatim();
      } else if (_geocodingProvider == 'BigDataCloud') {
        await fetchBigDataCloud();
      } else if (_geocodingProvider == 'Native Geocoding') {
        await fetchNativeGeocoding();
      } else {
        // Default to running all simultaneously
        await Future.wait([
          fetchNominatim(),
          fetchBigDataCloud(),
          fetchNativeGeocoding(),
        ]);
      }
      
      // Helper function for phonetic similarity
      int levenshtein(String a, String b) {
        a = a.toLowerCase(); b = b.toLowerCase();
        if (a == b) return 0;
        if (a.isEmpty) return b.length;
        if (b.isEmpty) return a.length;
        List<int> v0 = List<int>.generate(b.length + 1, (i) => i);
        List<int> v1 = List<int>.filled(b.length + 1, 0);
        for (int i = 0; i < a.length; i++) {
          v1[0] = i + 1;
          for (int j = 0; j < b.length; j++) {
            int cost = (a[i] == b[j]) ? 0 : 1;
            int min = v1[j] + 1;
            if (v0[j + 1] + 1 < min) min = v0[j + 1] + 1;
            if (v0[j] + cost < min) min = v0[j] + cost;
            v1[j + 1] = min;
          }
          for (int j = 0; j < v0.length; j++) {
            v0[j] = v1[j];
          }
        }
        return v1[b.length];
      }

      // Order: Micro -> Macro -> State
      final allParts = [...microLocalities, ...macroLocalities, ...states];
      final List<String> finalParts = [];

      for (String p in allParts) {
        String part = p.trim();
        if (part.isEmpty || part.contains('+')) continue;
        
        // Remove short alphanumeric codes like 'mdr0214' or 'sh12'
        if (RegExp(r'^[a-zA-Z0-9]+$').hasMatch(part) && RegExp(r'\d').hasMatch(part) && part.length < 10) continue;
        // Remove pure numbers unless it's a 6 digit pincode (though we didn't add pincodes in this iteration)
        if (RegExp(r'^\d+$').hasMatch(part) && part.length != 6) continue;

        bool isDuplicate = false;
        for (int i = 0; i < finalParts.length; i++) {
          String existing = finalParts[i];
          
          // Check substring matching
          if (existing.toLowerCase().contains(part.toLowerCase()) || part.toLowerCase().contains(existing.toLowerCase())) {
            // Keep the longer/more detailed one
            if (part.length > existing.length) {
              finalParts[i] = part;
            }
            isDuplicate = true;
            break;
          }
          
          // Check phonetic similarity for spelling mismatches (e.g. Kadiam vs Kadiyam)
          if (existing.length >= 4 && part.length >= 4) {
            int dist = levenshtein(existing, part);
            if (dist <= 2) { // 1 or 2 character difference
              if (part.length > existing.length) {
                finalParts[i] = part;
              }
              isDuplicate = true;
              break;
            }
          }
        }
        
        if (!isDuplicate) {
          finalParts.add(part);
        }
      }

      final address = finalParts.join(', ');
          
      if (mounted) {
        setState(() {
          _resolvedAddress = address.isEmpty ? 'Unknown Location' : address;
        });
      }
    } catch (e) {
      debugPrint('Overall reverse geocoding error: $e');
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _nameController.dispose();
    _farmerNameController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
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
    if (_currentPosition == null && _pickedLocation == null) return;
    if (!await _shouldProceedWithCreation()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final lat = _pickedLocation?.latitude ?? _currentPosition!.latitude;
      final lng = _pickedLocation?.longitude ?? _currentPosition!.longitude;

      final nursery = await _apiService.submitGeoTaggedNursery(
        _nameController.text.trim(),
        _farmerNameController.text.trim().isNotEmpty ? _farmerNameController.text.trim() : null,
        lat,
        lng,
        _phone1Controller.text.trim().isNotEmpty ? _phone1Controller.text.trim() : null,
        _phone2Controller.text.trim().isNotEmpty ? _phone2Controller.text.trim() : null,
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
    if (_currentPosition == null && _pickedLocation == null) return false;
    // Spatial validation only if we haven't manually picked location
    if (_pickedLocation == null && _currentPosition != null && _currentPosition!.accuracy >= 15.0) return false; 
    return true;
  }

  Future<void> _showSettingsDialog() async {
    final List<String> providers = ['Merged', 'Nominatim', 'BigDataCloud', 'Native Geocoding'];
    String tempProvider = _geocodingProvider;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Geocoding Provider'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: providers.map((p) {
                  return RadioListTile<String>(
                    title: Text(p),
                    value: p,
                    groupValue: tempProvider,
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          tempProvider = val;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('geocodingProvider', tempProvider);
                    setState(() {
                      _geocodingProvider = tempProvider;
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      if (_currentPosition != null) {
                        _updateAddress(_currentPosition!.latitude, _currentPosition!.longitude);
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nursery Setup Environment'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              if (_currentPosition != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    final initialLoc = _pickedLocation ?? LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationPickerScreen(initialLocation: initialLoc),
                      ),
                    );
                    if (result != null && result is LatLng) {
                      setState(() {
                        _pickedLocation = result;
                      });
                      _updateAddress(result.latitude, result.longitude);
                    }
                  },
                  icon: const Icon(Icons.map, size: 14),
                  label: const Text('Map'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_currentPosition != null || _pickedLocation != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAT: ${_pickedLocation?.latitude.toStringAsFixed(5) ?? _currentPosition!.latitude.toStringAsFixed(5)}',
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                    ),
                    Text(
                      'LNG: ${_pickedLocation?.longitude.toStringAsFixed(5) ?? _currentPosition!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                    ),
                    if (_resolvedAddress != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _resolvedAddress!,
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                        ),
                      ),
                  ],
                ),
                if (_pickedLocation != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'MANUAL',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _currentPosition!.accuracy < 15.0 ? Colors.green.shade700 : Colors.red.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ACC: ${_currentPosition!.accuracy.toStringAsFixed(1)} m',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phone1Controller,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Primary Phone',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.phone),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _phone2Controller,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Alt Phone',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.phone),
                    ),
                  ),
                ),
              ],
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

  void _showAddMethodDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Nursery'),
          content: const Text('How would you like to add the new nursery?'),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Auto OCR'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _selectedMethod = 0);
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit_location_alt),
              label: const Text('Manual Entry'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _selectedMethod = 1);
              },
            ),
          ],
        );
      },
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
              'Select Nursery',
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
                
                final lat = _pickedLocation?.latitude ?? _currentPosition?.latitude;
                final lng = _pickedLocation?.longitude ?? _currentPosition?.longitude;
                
                final nurseries = lat != null && lng != null
                    ? allNurseries.where((n) {
                        final distance = Geolocator.distanceBetween(
                          lat,
                          lng,
                          n.latitude,
                          n.longitude,
                        );
                        return distance <= tenAcresRadiusMeters;
                      }).toList()
                    : <NurseryModel>[]; // Wait for GPS to filter

                if (lat == null || lng == null) {
                  return const Text('Awaiting GPS fix to locate nearby nurseries...', style: TextStyle(color: Colors.orangeAccent));
                }
                
                if (nurseries.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No nurseries found within 10 acres of your current location.'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _showAddMethodDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text("Couldn't find the nursery? Add new."),
                      ),
                    ],
                  );
                }
                
                // Ensure the selected nursery is still in the filtered list, otherwise reset it
                if (_selectedNursery != null && !nurseries.contains(_selectedNursery)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _selectedNursery = null);
                  });
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownMenu<NurseryModel>(
                      width: MediaQuery.of(context).size.width - 80, // Adjust width based on card padding
                      label: const Text('Nursery'),
                      leadingIcon: const Icon(Icons.park),
                      enableFilter: true,
                      initialSelection: _selectedNursery,
                      dropdownMenuEntries: nurseries.map((n) {
                        return DropdownMenuEntry<NurseryModel>(
                          value: n,
                          label: n.name,
                        );
                      }).toList(),
                      onSelected: (val) {
                        setState(() {
                          _selectedNursery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _showAddMethodDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text("Couldn't find the nursery? Add new."),
                    ),
                  ],
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

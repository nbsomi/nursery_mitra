import 'package:flutter/material.dart';
import '../models/review_item_model.dart';
import '../core/network/api_client.dart';
import '../services/api_service.dart';

class ReviewScreen extends StatefulWidget {
  final ReviewItemModel reviewItem;

  const ReviewScreen({Key? key, required this.reviewItem}) : super(key: key);

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final ApiService _apiService;
  
  late TextEditingController _plantNameController;
  late TextEditingController _sizeController;
  late TextEditingController _bagSizeController;

  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(ApiClient());
    
    _plantNameController = TextEditingController(text: widget.reviewItem.extractedPlantName);
    _sizeController = TextEditingController(text: widget.reviewItem.extractedSize);
    _bagSizeController = TextEditingController(text: widget.reviewItem.extractedBagSize);
  }

  @override
  void dispose() {
    _plantNameController.dispose();
    _sizeController.dispose();
    _bagSizeController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndCommit() async {
    if (!_formKey.currentState!.validate()) {
      return; // Stop submission if validation fails
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _apiService.confirmStagedData(
        widget.reviewItem.reviewId,
        _plantNameController.text.trim(),
        _sizeController.text.trim(),
        _bagSizeController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Data successfully confirmed and committed!'),
            backgroundColor: Colors.green.shade800,
          ),
        );
        Navigator.pop(context); // Return cleanly to previous screen stack
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Commit Failed'),
            content: Text('Could not confirm review data.\n\nError: $e'),
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

  Color _getConfidenceColor(double score) {
    if (score >= 0.8) return Colors.green.shade700;
    if (score >= 0.5) return Colors.amber.shade700;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final confidenceScore = widget.reviewItem.confidence;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review OCR Predictions'),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey, // Enforces strict validators
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildConfidenceBadge(confidenceScore),
                  const SizedBox(height: 24),
                  const Text(
                    'Please review and correct the extracted data below:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildValidatedTextField(
                    controller: _plantNameController,
                    label: 'Predicted Plant Name',
                    icon: Icons.local_florist,
                    validatorMessage: 'Plant name cannot be empty',
                  ),
                  const SizedBox(height: 16),
                  _buildValidatedTextField(
                    controller: _sizeController,
                    label: 'Predicted Size Dimensions',
                    icon: Icons.height,
                    validatorMessage: 'Size dimension cannot be empty',
                  ),
                  const SizedBox(height: 16),
                  _buildValidatedTextField(
                    controller: _bagSizeController,
                    label: 'Predicted Bag Size',
                    icon: Icons.shopping_bag,
                    validatorMessage: 'Bag size cannot be empty',
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _confirmAndCommit,
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        'Confirm & Commit Data',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade900,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildConfidenceBadge(double score) {
    final color = _getConfidenceColor(score);
    final percentage = (score * 100).toStringAsFixed(1);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics, color: color, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prediction Confidence',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '$percentage% Reliability',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidatedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String validatorMessage,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blueGrey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueGrey.shade900, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return validatorMessage;
        }
        return null;
      },
    );
  }
}

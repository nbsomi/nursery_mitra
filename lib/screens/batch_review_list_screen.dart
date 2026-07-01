import 'package:flutter/material.dart';
import '../core/constants/app_config.dart';
import '../core/network/api_client.dart';
import '../services/api_service.dart';
import '../models/review_item_model.dart';
import 'review_screen.dart';

class BatchReviewListScreen extends StatefulWidget {
  const BatchReviewListScreen({super.key});

  @override
  State<BatchReviewListScreen> createState() => _BatchReviewListScreenState();
}

class _BatchReviewListScreenState extends State<BatchReviewListScreen> {
  late final ApiService _apiService;
  List<ReviewItemModel> _pendingReviews = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(ApiClient());
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reviews = await _apiService.getPendingReviews();
      setState(() {
        _pendingReviews = reviews;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getConfidenceColor(double score) {
    if (score >= 0.8) return Colors.green.shade700;
    if (score >= 0.5) return Colors.amber.shade700;
    return Colors.red.shade700;
  }

  void _openReviewScreen(ReviewItemModel item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewScreen(reviewItem: item),
      ),
    );
    // Refresh the list when returning to ensure the submitted item disappears
    _fetchReviews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Reviews Queue'),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReviews,
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load reviews.',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchReviews,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pendingReviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            const Text(
              'All caught up!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'No pending plants to review.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchReviews,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pendingReviews.length,
        itemBuilder: (context, index) {
          final item = _pendingReviews[index];
          final color = _getConfidenceColor(item.confidence);
          final percent = (item.confidence * 100).toStringAsFixed(1);
          
          String? imageUrl;
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
            imageUrl = '${AppConfig.baseUrl}${item.imageUrl}';
          }

          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: color.withOpacity(0.5), width: 1),
            ),
            child: InkWell(
              onTap: () => _openReviewScreen(item),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        image: imageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imageUrl == null
                          ? const Icon(Icons.image_not_supported, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.extractedPlantName.isEmpty ? 'Unknown Plant' : item.extractedPlantName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bag Size: ${item.extractedBagSize.isEmpty ? 'N/A' : item.extractedBagSize}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.analytics, size: 16, color: color),
                              const SizedBox(width: 4),
                              Text(
                                '$percent% Confidence',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

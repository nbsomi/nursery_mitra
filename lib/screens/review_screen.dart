import 'package:flutter/material.dart';
import '../models/review_item_model.dart';

class ReviewScreen extends StatelessWidget {
  final ReviewItemModel reviewItem;

  const ReviewScreen({Key? key, required this.reviewItem}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Observation')),
      body: Center(
        child: Text('Reviewing OCR extraction for: ${reviewItem.extractedPlantName}'),
      ),
    );
  }
}

class ReviewItemModel {
  final String reviewId;
  final String extractedPlantName;
  final String extractedBagSize;
  final double confidence;
  final String? imageUrl;

  ReviewItemModel({
    required this.reviewId,
    required this.extractedPlantName,
    required this.extractedBagSize,
    required this.confidence,
    this.imageUrl,
  });

  factory ReviewItemModel.fromJson(Map<String, dynamic> json) {
    return ReviewItemModel(
      reviewId: json['reviewId'] as String? ?? '',
      extractedPlantName: json['extractedPlantName'] as String? ?? '',
      extractedBagSize: json['extractedBagSize'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reviewId': reviewId,
      'extractedPlantName': extractedPlantName,
      'extractedBagSize': extractedBagSize,
      'confidence': confidence,
      'imageUrl': imageUrl,
    };
  }
}

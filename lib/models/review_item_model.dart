class ReviewItemModel {
  final String reviewId;
  final String extractedPlantName;
  final String extractedSize;
  final String extractedBagSize;
  final double confidenceScore;

  ReviewItemModel({
    required this.reviewId,
    required this.extractedPlantName,
    required this.extractedSize,
    required this.extractedBagSize,
    required this.confidenceScore,
  });

  factory ReviewItemModel.fromJson(Map<String, dynamic> json) {
    return ReviewItemModel(
      reviewId: json['reviewId'] as String,
      extractedPlantName: json['extractedPlantName'] as String,
      extractedSize: json['extractedSize'] as String,
      extractedBagSize: json['extractedBagSize'] as String,
      confidenceScore: (json['confidenceScore'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reviewId': reviewId,
      'extractedPlantName': extractedPlantName,
      'extractedSize': extractedSize,
      'extractedBagSize': extractedBagSize,
      'confidenceScore': confidenceScore,
    };
  }
}

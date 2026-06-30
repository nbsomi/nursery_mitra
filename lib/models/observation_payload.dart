class ObservationPayload {
  final String visitId;
  final String nurseryId;
  final String plantName;
  final String plantHeight;
  final String bagSize;
  final String remarks;

  ObservationPayload({
    required this.visitId,
    required this.nurseryId,
    required this.plantName,
    required this.plantHeight,
    required this.bagSize,
    required this.remarks,
  });

  factory ObservationPayload.fromJson(Map<String, dynamic> json) {
    return ObservationPayload(
      visitId: json['visitId'] as String? ?? '',
      nurseryId: json['nurseryId'] as String? ?? '',
      plantName: json['plantName'] as String? ?? '',
      plantHeight: json['plantHeight'] as String? ?? '',
      bagSize: json['bagSize'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'visitId': visitId,
      'nurseryId': nurseryId,
      'plantName': plantName,
      'plantHeight': plantHeight,
      'bagSize': bagSize,
      'remarks': remarks,
    };
  }
}

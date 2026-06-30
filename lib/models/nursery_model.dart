class NurseryModel {
  final String nurseryId;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final String phone;
  final DateTime? firstSeenDate;
  final DateTime? lastVerifiedDate;

  NurseryModel({
    required this.nurseryId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.phone,
    this.firstSeenDate,
    this.lastVerifiedDate,
  });

  factory NurseryModel.fromJson(Map<String, dynamic> json) {
    return NurseryModel(
      nurseryId: json['nurseryId'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String,
      phone: json['phone'] as String,
      firstSeenDate: json['firstSeenDate'] != null
          ? DateTime.parse(json['firstSeenDate'] as String)
          : null,
      lastVerifiedDate: json['lastVerifiedDate'] != null
          ? DateTime.parse(json['lastVerifiedDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nurseryId': nurseryId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'phone': phone,
      'firstSeenDate': firstSeenDate?.toIso8601String(),
      'lastVerifiedDate': lastVerifiedDate?.toIso8601String(),
    };
  }
}

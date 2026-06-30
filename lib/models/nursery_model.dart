class NurseryModel {
  final String nurseryId;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final String phone;
  final String firstSeenDate;
  final String lastVerifiedDate;

  NurseryModel({
    required this.nurseryId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.phone,
    required this.firstSeenDate,
    required this.lastVerifiedDate,
  });

  factory NurseryModel.fromJson(Map<String, dynamic> json) {
    return NurseryModel(
      nurseryId: json['nurseryId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      firstSeenDate: json['firstSeenDate'] as String? ?? '',
      lastVerifiedDate: json['lastVerifiedDate'] as String? ?? '',
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
      'firstSeenDate': firstSeenDate,
      'lastVerifiedDate': lastVerifiedDate,
    };
  }
}

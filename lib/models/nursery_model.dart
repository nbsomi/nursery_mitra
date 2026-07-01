class NurseryModel {
  final String nurseryId;
  final String name;
  final String farmerName;
  final double latitude;
  final double longitude;
  final String address;
  final String phone1;
  final String phone2;
  final String firstSeenDate;
  final String lastVerifiedDate;

  NurseryModel({
    required this.nurseryId,
    required this.name,
    required this.farmerName,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.phone1,
    required this.phone2,
    required this.firstSeenDate,
    required this.lastVerifiedDate,
  });

  factory NurseryModel.fromJson(Map<String, dynamic> json) {
    return NurseryModel(
      nurseryId: json['nurseryId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      farmerName: json['farmerName'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String? ?? '',
      phone1: json['phone1'] as String? ?? '',
      phone2: json['phone2'] as String? ?? '',
      firstSeenDate: json['firstSeenDate'] as String? ?? '',
      lastVerifiedDate: json['lastVerifiedDate'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nurseryId': nurseryId,
      'name': name,
      'farmerName': farmerName,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'phone1': phone1,
      'phone2': phone2,
      'firstSeenDate': firstSeenDate,
      'lastVerifiedDate': lastVerifiedDate,
    };
  }
}

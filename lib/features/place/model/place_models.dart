class PlaceSuggestion {
  final String placeId;
  final String name;
  final String? address;

  const PlaceSuggestion({
    required this.placeId,
    required this.name,
    required this.address,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      placeId: json['placeId'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
    );
  }
}

class PlaceSelection {
  final String? placeId;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;

  const PlaceSelection({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  factory PlaceSelection.fromJson(Map<String, dynamic> json) {
    return PlaceSelection(
      placeId: json['placeId'] as String?,
      name: json['name'] as String,
      address: json['address'] as String? ?? json['name'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  factory PlaceSelection.manual(String name) {
    final normalized = name.trim();
    return PlaceSelection(
      placeId: null,
      name: normalized,
      address: normalized,
      latitude: null,
      longitude: null,
    );
  }
}

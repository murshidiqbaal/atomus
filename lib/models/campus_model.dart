class Campus {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double allowedRadiusMeters;

  const Campus({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.allowedRadiusMeters,
  });

  factory Campus.fromMap(Map<String, dynamic> map) {
    return Campus(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Unnamed Campus',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      allowedRadiusMeters: (map['allowed_radius_meters'] as num?)?.toDouble() ??
                           (map['geofence_radius_meters'] as num?)?.toDouble() ??
                           25.0,
    );
  }

  String get shortCode {
    final lower = name.toLowerCase();
    if (lower.contains('aroor') || lower.contains('campus 1') || lower.contains('arr')) {
      return 'ARR';
    } else if (lower.contains('piravom') || lower.contains('campus 2') || lower.contains('prv')) {
      return 'PRV';
    } else if (lower.contains('main')) {
      return 'MAIN';
    }
    return name.toUpperCase();
  }

  String get displayName {
    final lower = name.toLowerCase();
    if (lower.contains('aroor') || lower.contains('campus 1') || lower.contains('arr')) {
      return 'ARR - Campus 1 Aroor';
    } else if (lower.contains('piravom') || lower.contains('campus 2') || lower.contains('prv')) {
      return 'PRV - Campus 2 Piravom';
    } else if (lower.contains('main')) {
      return 'MAIN - Main Campus';
    }
    return name;
  }

  bool get isMainCampus => name.toLowerCase().contains('main');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'allowed_radius_meters': allowedRadiusMeters,
    };
  }
}

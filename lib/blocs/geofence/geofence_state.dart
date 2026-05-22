import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

enum GeofenceStatus { unknown, checking, inside, outside, permissionDenied, serviceDisabled, error }

class GeofenceState extends Equatable {
  final GeofenceStatus status;
  final double distanceMeters;
  final Position? position;
  final String? errorMessage;

  const GeofenceState({
    this.status = GeofenceStatus.unknown,
    this.distanceMeters = double.infinity,
    this.position,
    this.errorMessage,
  });

  bool get isInside => status == GeofenceStatus.inside;
  bool get isChecking => status == GeofenceStatus.checking;
  bool get hasError => status == GeofenceStatus.error ||
      status == GeofenceStatus.permissionDenied ||
      status == GeofenceStatus.serviceDisabled;

  String get statusMessage {
    switch (status) {
      case GeofenceStatus.inside:
        return 'You are inside campus (${distanceMeters.toInt()}m away)';
      case GeofenceStatus.outside:
        return 'You are outside campus (${distanceMeters.toInt()}m away)';
      case GeofenceStatus.permissionDenied:
        return 'Location permission denied. Please allow location access.';
      case GeofenceStatus.serviceDisabled:
        return 'GPS is disabled. Please enable location services.';
      case GeofenceStatus.checking:
        return 'Checking your location...';
      case GeofenceStatus.error:
        return errorMessage ?? 'Could not determine location.';
      case GeofenceStatus.unknown:
        return 'Location not checked yet.';
    }
  }

  GeofenceState copyWith({
    GeofenceStatus? status,
    double? distanceMeters,
    Position? position,
    String? errorMessage,
  }) {
    return GeofenceState(
      status:         status        ?? this.status,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      position:       position      ?? this.position,
      errorMessage:   errorMessage  ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, distanceMeters, errorMessage];
}

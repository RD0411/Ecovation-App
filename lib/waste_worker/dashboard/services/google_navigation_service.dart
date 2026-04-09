import 'dart:math' as math;
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

enum StopStatus { pending, inProgress, completed }

class WaypointStop {
  const WaypointStop({
    required this.id,
    required this.name,
    required this.latLng,
    required this.status,
    this.address,
    this.isAdditional = false,
    this.distanceFromPreviousMeters,
    this.etaFromPrevious,
  });

  final String id;
  final String name;
  final LatLng latLng;
  final StopStatus status;
  final String? address;
  final bool isAdditional;
  final double? distanceFromPreviousMeters;
  final Duration? etaFromPrevious;

  bool get isPending => status == StopStatus.pending;
  bool get isCompleted => status == StopStatus.completed;

  WaypointStop copyWith({
    String? id,
    String? name,
    LatLng? latLng,
    StopStatus? status,
    String? address,
    bool? isAdditional,
    double? distanceFromPreviousMeters,
    Duration? etaFromPrevious,
  }) {
    return WaypointStop(
      id: id ?? this.id,
      name: name ?? this.name,
      latLng: latLng ?? this.latLng,
      status: status ?? this.status,
      address: address ?? this.address,
      isAdditional: isAdditional ?? this.isAdditional,
      distanceFromPreviousMeters:
          distanceFromPreviousMeters ?? this.distanceFromPreviousMeters,
      etaFromPrevious: etaFromPrevious ?? this.etaFromPrevious,
    );
  }
}

class RouteInfo {
  const RouteInfo({
    required this.polylinePoints,
    required this.orderedStops,
    required this.totalDistanceMeters,
    required this.totalDuration,
  });

  final List<LatLng> polylinePoints;
  final List<WaypointStop> orderedStops;
  final double totalDistanceMeters;
  final Duration totalDuration;
}

class NavigationSnapshot {
  const NavigationSnapshot({
    required this.totalStops,
    required this.completedStops,
    required this.pendingStops,
    required this.distanceToNextMeters,
    required this.deviationMeters,
    this.currentStop,
  });

  final int totalStops;
  final int completedStops;
  final int pendingStops;
  final double distanceToNextMeters;
  final double deviationMeters;
  final WaypointStop? currentStop;
}

class GoogleNavigationService {
  static const double _avgSpeedMetersPerSec = 6.94;
  static final PolylinePoints _polylinePoints = PolylinePoints();

  static Future<RouteInfo> fetchOptimizedRoute({
    required LatLng origin,
    required List<WaypointStop> stops,
    required LatLng destination,
  }) async {
    try {
      return await _fetchRoadOptimizedRoute(
        origin: origin,
        stops: stops,
        destination: destination,
      );
    } catch (_) {
      // Fallback keeps navigation functional if network routing is unavailable.
    }

    return _buildFallbackRouteInfo(
      origin: origin,
      stops: stops,
      destination: destination,
    );
  }

  static Future<RouteInfo> _fetchRoadOptimizedRoute({
    required LatLng origin,
    required List<WaypointStop> stops,
    required LatLng destination,
  }) async {
    final List<WaypointStop> pendingStops = stops
        .where((WaypointStop stop) => !stop.isCompleted)
        .map((WaypointStop stop) => stop.copyWith(status: StopStatus.pending))
        .toList(growable: true);

    if (pendingStops.isEmpty) {
      final List<LatLng> path = <LatLng>[origin, destination];
      final double directMeters = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );
      return RouteInfo(
        polylinePoints: path,
        orderedStops: const <WaypointStop>[],
        totalDistanceMeters: directMeters,
        totalDuration: Duration(
          seconds: math.max(1, (directMeters / _avgSpeedMetersPerSec).round()),
        ),
      );
    }

    final List<LatLng> coordinates = <LatLng>[origin];
    coordinates.addAll(pendingStops.map((WaypointStop stop) => stop.latLng));
    coordinates.add(destination);

    final String coordString = coordinates
        .map((LatLng p) => '${p.longitude},${p.latitude}')
        .join(';');

    final Uri tripUri = Uri.parse(
      'https://router.project-osrm.org/trip/v1/driving/$coordString'
      '?source=first&destination=last&roundtrip=false&overview=full&geometries=polyline',
    );

    final http.Response response = await http.get(tripUri);
    if (response.statusCode != 200) {
      throw Exception('Road route API failed with ${response.statusCode}');
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    if (body['code']?.toString() != 'Ok') {
      throw Exception('Road route API did not return a valid route.');
    }

    final List<dynamic> trips = body['trips'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> waypoints = body['waypoints'] as List<dynamic>? ?? <dynamic>[];
    if (trips.isEmpty || waypoints.length != coordinates.length) {
      throw Exception('Incomplete optimized route response.');
    }

    final Map<String, dynamic> trip = trips.first as Map<String, dynamic>;
    final String geometry = trip['geometry']?.toString() ?? '';
    final List<PointLatLng> decoded = _polylinePoints.decodePolyline(geometry);
    if (decoded.length < 2) {
      throw Exception('Unable to decode road polyline.');
    }

    final List<LatLng> path = decoded
        .map((PointLatLng p) => LatLng(p.latitude, p.longitude))
        .toList(growable: false);

    final List<_StopSequenceMeta> sequenceMeta = <_StopSequenceMeta>[];
    for (int i = 1; i <= pendingStops.length; i++) {
      final Map<String, dynamic> wp = waypoints[i] as Map<String, dynamic>;
      final int sequence = _toInt(wp['waypoint_index']) ?? i;
      sequenceMeta.add(_StopSequenceMeta(stop: pendingStops[i - 1], sequence: sequence));
    }
    sequenceMeta.sort((a, b) => a.sequence.compareTo(b.sequence));

    final List<dynamic> legs = trip['legs'] as List<dynamic>? ?? <dynamic>[];
    final List<WaypointStop> withMeta = sequenceMeta.map((_StopSequenceMeta meta) {
      final int legIndex = meta.sequence - 1;
      double? segmentDistance;
      Duration? segmentEta;

      if (legIndex >= 0 && legIndex < legs.length) {
        final Map<String, dynamic> leg = legs[legIndex] as Map<String, dynamic>;
        final double distance = _toDouble(leg['distance']) ?? 0;
        final double durationSeconds = _toDouble(leg['duration']) ?? 0;
        segmentDistance = distance;
        segmentEta = Duration(seconds: math.max(1, durationSeconds.round()));
      }

      return meta.stop.copyWith(
        distanceFromPreviousMeters: segmentDistance,
        etaFromPrevious: segmentEta,
      );
    }).toList(growable: false);

    final double totalDistance = _toDouble(trip['distance']) ?? 0;
    final double totalDurationSeconds = _toDouble(trip['duration']) ?? 0;

    return RouteInfo(
      polylinePoints: path,
      orderedStops: withMeta,
      totalDistanceMeters: totalDistance,
      totalDuration: Duration(seconds: math.max(1, totalDurationSeconds.round())),
    );
  }

  static RouteInfo _buildFallbackRouteInfo({
    required LatLng origin,
    required List<WaypointStop> stops,
    required LatLng destination,
  }) {
    final List<WaypointStop> pendingStops = stops
        .where((WaypointStop stop) => !stop.isCompleted)
        .map((WaypointStop stop) => stop.copyWith(status: StopStatus.pending))
        .toList(growable: true);

    final List<WaypointStop> orderedStops = _optimizeNearestNeighbor(
      origin: origin,
      stops: pendingStops,
    );

    final List<LatLng> path = <LatLng>[origin];
    path.addAll(orderedStops.map((WaypointStop stop) => stop.latLng));
    path.add(destination);

    double totalDistance = 0;
    LatLng previous = origin;
    final List<WaypointStop> withMeta = <WaypointStop>[];

    for (final WaypointStop stop in orderedStops) {
      final double segment = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        stop.latLng.latitude,
        stop.latLng.longitude,
      );
      totalDistance += segment;
      withMeta.add(
        stop.copyWith(
          distanceFromPreviousMeters: segment,
          etaFromPrevious: Duration(
            seconds: math.max(1, (segment / _avgSpeedMetersPerSec).round()),
          ),
        ),
      );
      previous = stop.latLng;
    }

    final double lastLeg = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      destination.latitude,
      destination.longitude,
    );
    totalDistance += lastLeg;

    final Duration totalDuration = Duration(
      seconds: math.max(1, (totalDistance / _avgSpeedMetersPerSec).round()),
    );

    return RouteInfo(
      polylinePoints: path,
      orderedStops: withMeta,
      totalDistanceMeters: totalDistance,
      totalDuration: totalDuration,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value.toString());
  }

  static List<WaypointStop> _optimizeNearestNeighbor({
    required LatLng origin,
    required List<WaypointStop> stops,
  }) {
    if (stops.isEmpty) {
      return const <WaypointStop>[];
    }

    final List<WaypointStop> remaining = List<WaypointStop>.from(stops);
    final List<WaypointStop> ordered = <WaypointStop>[];
    LatLng cursor = origin;

    while (remaining.isNotEmpty) {
      remaining.sort((WaypointStop a, WaypointStop b) {
        final double da = Geolocator.distanceBetween(
          cursor.latitude,
          cursor.longitude,
          a.latLng.latitude,
          a.latLng.longitude,
        );
        final double db = Geolocator.distanceBetween(
          cursor.latitude,
          cursor.longitude,
          b.latLng.latitude,
          b.latLng.longitude,
        );
        return da.compareTo(db);
      });

      final WaypointStop next = remaining.removeAt(0);
      ordered.add(next);
      cursor = next.latLng;
    }

    return ordered;
  }

  static NavigationSnapshot buildNavigationSnapshot({
    required List<WaypointStop> stops,
    required int currentStopIndex,
    required LatLng userLocation,
    required List<LatLng> routePolyline,
  }) {
    final int completed = stops.where((WaypointStop s) => s.isCompleted).length;
    final int pending = stops.where((WaypointStop s) => s.isPending).length;

    WaypointStop? current;
    if (currentStopIndex >= 0 && currentStopIndex < stops.length) {
      current = stops[currentStopIndex];
    }

    final double distToNext = current == null
        ? 0
        : Geolocator.distanceBetween(
            userLocation.latitude,
            userLocation.longitude,
            current.latLng.latitude,
            current.latLng.longitude,
          );

    final double deviation = _minDistanceToPolyline(userLocation, routePolyline);

    return NavigationSnapshot(
      totalStops: stops.length,
      completedStops: completed,
      pendingStops: pending,
      distanceToNextMeters: distToNext,
      deviationMeters: deviation,
      currentStop: current,
    );
  }

  static bool isWithinCompletionRadius(LatLng user, WaypointStop stop) {
    final double distance = Geolocator.distanceBetween(
      user.latitude,
      user.longitude,
      stop.latLng.latitude,
      stop.latLng.longitude,
    );
    return distance <= 50;
  }

  static bool shouldRecalculate(LatLng user, List<LatLng> routePolyline) {
    final double deviation = _minDistanceToPolyline(user, routePolyline);
    return deviation >= 70;
  }

  static String formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  static String formatDuration(Duration duration) {
    final int hrs = duration.inHours;
    final int mins = duration.inMinutes.remainder(60);
    if (hrs == 0) {
      return '${duration.inMinutes} min';
    }
    return '${hrs}h ${mins}m';
  }

  static double _minDistanceToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.length < 2) {
      return 0;
    }

    double minDistance = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final LatLng a = polyline[i];
      final LatLng b = polyline[i + 1];
      final double d = _distancePointToSegmentMeters(point, a, b);
      if (d < minDistance) {
        minDistance = d;
      }
    }

    return minDistance.isFinite ? minDistance : 0;
  }

  static double _distancePointToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    final double latScale = 111320;
    final double lonScale = 111320 * math.cos(_degToRad(p.latitude));

    final double ax = a.longitude * lonScale;
    final double ay = a.latitude * latScale;
    final double bx = b.longitude * lonScale;
    final double by = b.latitude * latScale;
    final double px = p.longitude * lonScale;
    final double py = p.latitude * latScale;

    final double abx = bx - ax;
    final double aby = by - ay;
    final double apx = px - ax;
    final double apy = py - ay;

    final double ab2 = (abx * abx) + (aby * aby);
    if (ab2 == 0) {
      final double dx = px - ax;
      final double dy = py - ay;
      return math.sqrt((dx * dx) + (dy * dy));
    }

    double t = ((apx * abx) + (apy * aby)) / ab2;
    t = t.clamp(0, 1);

    final double cx = ax + (abx * t);
    final double cy = ay + (aby * t);
    final double dx = px - cx;
    final double dy = py - cy;
    return math.sqrt((dx * dx) + (dy * dy));
  }

  static double _degToRad(double degrees) {
    return degrees * math.pi / 180;
  }
}

class _StopSequenceMeta {
  const _StopSequenceMeta({
    required this.stop,
    required this.sequence,
  });

  final WaypointStop stop;
  final int sequence;
}

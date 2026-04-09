import 'package:citizen_impetus/Authentication/services/auth_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:citizen_impetus/waste_worker/dashboard/services/google_navigation_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkerAssignedRouteData {
  const WorkerAssignedRouteData({
    required this.assignmentId,
    required this.routeId,
    required this.routeName,
    required this.startLocation,
    required this.endLocation,
    required this.assignmentStatus,
    required this.routeStatus,
    required this.stops,
    required this.origin,
    required this.destination,
  });

  final String? assignmentId;
  final String? routeId;
  final String routeName;
  final String startLocation;
  final String endLocation;
  final String assignmentStatus;
  final String routeStatus;
  final List<WaypointStop> stops;
  final LatLng origin;
  final LatLng destination;
}

class WasteWorkerDashboardService {
  WasteWorkerDashboardService() : _client = Supabase.instance.client;

  final SupabaseClient _client;
  static const Duration _statusCacheTtl = Duration(seconds: 25);
  static const Duration _analyticsCacheTtl = Duration(seconds: 25);
  static const Duration _assignedStopsCacheTtl = Duration(seconds: 30);

  String? _cachedWorkerStatus;
  DateTime? _cachedWorkerStatusAt;
  Future<String>? _workerStatusInFlight;

  Map<String, int>? _cachedAnalytics;
  DateTime? _cachedAnalyticsAt;
  Future<Map<String, int>>? _analyticsInFlight;

  WorkerAssignedRouteData? _cachedAssignedStops;
  DateTime? _cachedAssignedStopsAt;
  Future<WorkerAssignedRouteData>? _assignedStopsInFlight;

  Future<String> getWorkerStatus({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedWorkerStatus != null && _cachedWorkerStatusAt != null) {
      if (DateTime.now().difference(_cachedWorkerStatusAt!) <= _statusCacheTtl) {
        return _cachedWorkerStatus!;
      }
    }

    if (!forceRefresh && _workerStatusInFlight != null) {
      return _workerStatusInFlight!;
    }

    final Future<String> inFlight = _loadWorkerStatus();
    _workerStatusInFlight = inFlight;
    try {
      final String status = await inFlight;
      _cachedWorkerStatus = status;
      _cachedWorkerStatusAt = DateTime.now();
      return status;
    } finally {
      _workerStatusInFlight = null;
    }
  }

  Future<String> _loadWorkerStatus() async {
    final String userId = _requireUserId();
    final Map<String, dynamic>? worker = await _client
        .from('workers')
        .select('status')
        .eq('id', userId)
        .maybeSingle();

    return worker?['status']?.toString().toLowerCase() ?? 'available';
  }

  Future<Map<String, int>> getAssignmentAnalytics({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedAnalytics != null && _cachedAnalyticsAt != null) {
      if (DateTime.now().difference(_cachedAnalyticsAt!) <= _analyticsCacheTtl) {
        return _cachedAnalytics!;
      }
    }

    if (!forceRefresh && _analyticsInFlight != null) {
      return _analyticsInFlight!;
    }

    final Future<Map<String, int>> inFlight = _loadAssignmentAnalytics();
    _analyticsInFlight = inFlight;
    try {
      final Map<String, int> analytics = await inFlight;
      _cachedAnalytics = analytics;
      _cachedAnalyticsAt = DateTime.now();
      return analytics;
    } finally {
      _analyticsInFlight = null;
    }
  }

  Future<Map<String, int>> _loadAssignmentAnalytics() async {
    final String userId = _requireUserId();
    final List<dynamic> rows = await _client
        .from('route_assignments')
        .select('status')
        .eq('worker_id', userId);

    int assigned = 0;
    int active = 0;
    int completed = 0;

    for (final dynamic item in rows) {
      final String status =
          ((item as Map<String, dynamic>)['status']?.toString() ?? '').toLowerCase();
      if (status == 'assigned') {
        assigned++;
      } else if (status == 'active') {
        active++;
      } else if (status == 'completed') {
        completed++;
      }
    }

    return <String, int>{
      'assigned': assigned,
      'active': active,
      'completed': completed,
    };
  }

  Future<WorkerAssignedRouteData> fetchAssignedStops({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedAssignedStops != null && _cachedAssignedStopsAt != null) {
      if (DateTime.now().difference(_cachedAssignedStopsAt!) <= _assignedStopsCacheTtl) {
        return _cachedAssignedStops!;
      }
    }

    if (!forceRefresh && _assignedStopsInFlight != null) {
      return _assignedStopsInFlight!;
    }

    final Future<WorkerAssignedRouteData> inFlight = _loadAssignedStops();
    _assignedStopsInFlight = inFlight;
    try {
      final WorkerAssignedRouteData data = await inFlight;
      _cachedAssignedStops = data;
      _cachedAssignedStopsAt = DateTime.now();
      return data;
    } finally {
      _assignedStopsInFlight = null;
    }
  }

  Future<WorkerAssignedRouteData> _loadAssignedStops() async {
    final String userId = _requireUserId();

    final List<dynamic> parallelBase = await Future.wait<dynamic>([
      _client
          .from('workers')
          .select('address, latitude, longitude')
          .eq('id', userId)
          .maybeSingle(),
      _client
          .from('route_assignments')
          .select('id, route_id, status, assigned_at')
          .eq('worker_id', userId)
          .order('assigned_at', ascending: true),
    ]);

    final Map<String, dynamic>? worker = parallelBase[0] as Map<String, dynamic>?;
    final List<dynamic> assignmentRows = parallelBase[1] as List<dynamic>;

    if (assignmentRows.isEmpty) {
      return const WorkerAssignedRouteData(
        assignmentId: null,
        routeId: null,
        routeName: 'No Active Route',
        startLocation: '-',
        endLocation: '-',
        assignmentStatus: 'assigned',
        routeStatus: 'planned',
        stops: <WaypointStop>[],
        origin: LatLng(18.4516, 73.8544),
        destination: LatLng(18.5018, 73.8636),
      );
    }

    final List<Map<String, dynamic>> assignments = assignmentRows
        .map((dynamic item) => item as Map<String, dynamic>)
        .where((Map<String, dynamic> row) =>
            (row['route_id']?.toString() ?? '').trim().isNotEmpty)
        .toList(growable: false);

    if (assignments.isEmpty) {
      return const WorkerAssignedRouteData(
        assignmentId: null,
        routeId: null,
        routeName: 'No Active Route',
        startLocation: '-',
        endLocation: '-',
        assignmentStatus: 'assigned',
        routeStatus: 'planned',
        stops: <WaypointStop>[],
        origin: LatLng(18.4516, 73.8544),
        destination: LatLng(18.5018, 73.8636),
      );
    }

    Map<String, dynamic>? primaryAssignment;
    for (final Map<String, dynamic> row in assignments) {
      if ((row['status']?.toString() ?? '').toLowerCase() == 'active') {
        primaryAssignment = row;
        break;
      }
    }
    primaryAssignment ??= assignments.firstWhere(
      (Map<String, dynamic> row) =>
          (row['status']?.toString() ?? '').toLowerCase() == 'assigned',
      orElse: () => assignments.last,
    );

    final String assignmentId = primaryAssignment['id']?.toString() ?? '';
    final String routeId = primaryAssignment['route_id']?.toString() ?? '';

    final List<String> routeIdsInOrder = assignments
        .map((Map<String, dynamic> row) => row['route_id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final List<dynamic> routeRows = await _client
        .from('routes')
        .select('id, route_name, start_location, end_location, status')
        .inFilter('id', routeIdsInOrder);

    final Map<String, Map<String, dynamic>> routeById = <String, Map<String, dynamic>>{};
    for (final dynamic item in routeRows) {
      final Map<String, dynamic> row = item as Map<String, dynamic>;
      final String id = row['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        routeById[id] = row;
      }
    }

    final List<dynamic> mappedSpotsByRoute = await Future.wait<dynamic>(
      routeIdsInOrder.map((String rid) {
        return _client
            .from('route_collection_spots')
            .select(
              'sequence, collection_spot_id, collection_spots(id, name, address, latitude, longitude)',
            )
            .eq('route_id', rid);
      }),
    );

    final List<WaypointStop> plannedStops = <WaypointStop>[];
    final List<WaypointStop> stops = <WaypointStop>[];

    for (int routeIndex = 0; routeIndex < routeIdsInOrder.length; routeIndex++) {
      final String rid = routeIdsInOrder[routeIndex];
      final List<dynamic> mappedSpots = mappedSpotsByRoute[routeIndex] as List<dynamic>;

      final List<Map<String, dynamic>> orderedSpots = mappedSpots
          .map((dynamic item) => item as Map<String, dynamic>)
          .toList(growable: true)
        ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          final int sa = _parseInt(a['sequence']) ?? 0;
          final int sb = _parseInt(b['sequence']) ?? 0;
          return sa.compareTo(sb);
        });

      for (int i = 0; i < orderedSpots.length; i++) {
        final Map<String, dynamic> item = orderedSpots[i];
        final Map<String, dynamic>? spot =
            item['collection_spots'] as Map<String, dynamic>?;
        if (spot == null) {
          continue;
        }

        final double? lat = _parseDouble(spot['latitude']);
        final double? lng = _parseDouble(spot['longitude']);
        if (lat == null || lng == null) {
          continue;
        }

        final String spotId =
            spot['id']?.toString() ?? item['collection_spot_id']?.toString() ?? '';
        if (spotId.isEmpty) {
          continue;
        }

        final String routeName = routeById[rid]?['route_name']?.toString() ?? 'Route';
        final String spotName = spot['name']?.toString().trim().isNotEmpty == true
            ? spot['name'].toString()
            : 'Collection Spot ${i + 1}';

        final WaypointStop stop = WaypointStop(
          id: 'spot_${rid}_$spotId',
          name: '$routeName - $spotName',
          latLng: LatLng(lat, lng),
          address: spot['address']?.toString(),
          status: StopStatus.pending,
        );
        plannedStops.add(stop);
        stops.add(stop);
      }
    }

    final List<dynamic> mappedReportsByRoute = await Future.wait<dynamic>(
      routeIdsInOrder.map((String rid) {
        return _client
            .from('route_reports')
            .select('report_id, waste_reports(*)')
            .eq('route_id', rid);
      }),
    );

    for (int routeIndex = 0; routeIndex < routeIdsInOrder.length; routeIndex++) {
      final String rid = routeIdsInOrder[routeIndex];
      final List<dynamic> mappedReports = mappedReportsByRoute[routeIndex] as List<dynamic>;

      for (final dynamic item in mappedReports) {
        final Map<String, dynamic> row = item as Map<String, dynamic>;
        final Map<String, dynamic>? report = row['waste_reports'] as Map<String, dynamic>?;
        if (report == null) {
          continue;
        }

        final String reportStatus =
            (report['status']?.toString() ?? '').trim().toLowerCase();
        if (reportStatus == 'completed' ||
            reportStatus == 'verified' ||
            reportStatus == 'rejected') {
          continue;
        }

        final String reportId = report['id']?.toString() ?? row['report_id']?.toString() ?? '';
        final double? lat = _parseDouble(report['latitude']);
        final double? lng = _parseDouble(report['longitude']);
        if (reportId.isEmpty || lat == null || lng == null) {
          continue;
        }

        final bool tooCloseToExisting = stops.any((WaypointStop existing) {
          final double distanceMeters = Geolocator.distanceBetween(
            existing.latLng.latitude,
            existing.latLng.longitude,
            lat,
            lng,
          );
          return distanceMeters <= 20;
        });
        if (tooCloseToExisting) {
          continue;
        }

        final String category = report['category']?.toString().trim().isNotEmpty == true
            ? report['category'].toString()
            : 'Waste Report';
        final String routeName = routeById[rid]?['route_name']?.toString() ?? 'Route';

        stops.add(
          WaypointStop(
            id: 'report_${rid}_$reportId',
            name: '$routeName - Report Spot - $category',
            latLng: LatLng(lat, lng),
            address: report['address']?.toString(),
            status: StopStatus.pending,
            isAdditional: true,
          ),
        );
      }
    }

    final double? workerLat = _parseDouble(worker?['latitude']);
    final double? workerLng = _parseDouble(worker?['longitude']);

    final LatLng origin = (workerLat != null && workerLng != null)
      ? LatLng(workerLat, workerLng)
      : (plannedStops.isNotEmpty
        ? plannedStops.first.latLng
        : const LatLng(18.4516, 73.8544));

    final LatLng destination = plannedStops.isNotEmpty
      ? plannedStops.last.latLng
      : (stops.isNotEmpty ? stops.last.latLng : const LatLng(18.5018, 73.8636));

    final String workerAddress = worker?['address']?.toString().trim() ?? '';
    final String? rawEnd = plannedStops.isNotEmpty
      ? plannedStops.last.address
      : routeById[routeId]?['end_location']?.toString();

    final List<String> readableLocations = await Future.wait<String>([
      _resolveReadableLocation(
        preferredLabel: workerAddress,
        latitude: origin.latitude,
        longitude: origin.longitude,
      ),
      _resolveReadableLocation(
        preferredLabel: rawEnd,
        latitude: destination.latitude,
        longitude: destination.longitude,
      ),
    ]);
    final String computedStartText = readableLocations[0];
    final String computedEndText = readableLocations[1];

    return WorkerAssignedRouteData(
      assignmentId: assignmentId,
      routeId: routeId,
      routeName: routeIdsInOrder.length > 1
          ? '${routeIdsInOrder.length} Routes Assigned'
          : (routeById[routeId]?['route_name']?.toString() ?? 'Assigned Route'),
      startLocation: computedStartText,
      endLocation: computedEndText,
      assignmentStatus:
          primaryAssignment['status']?.toString().toLowerCase() ?? 'assigned',
      routeStatus:
          routeById[routeId]?['status']?.toString().toLowerCase() ?? 'planned',
      stops: stops,
      origin: origin,
      destination: destination,
    );
  }

  Future<void> updateWorkerAvailability(String status) async {
    const Set<String> allowed = <String>{'available', 'busy', 'offline'};
    final String normalized = status.trim().toLowerCase();
    if (!allowed.contains(normalized)) {
      throw Exception('Invalid worker status selected.');
    }

    final String userId = _requireUserId();
    await _client.from('workers').update({'status': normalized}).eq('id', userId);
    _cachedWorkerStatus = normalized;
    _cachedWorkerStatusAt = DateTime.now();
  }

  Future<void> updateWorkerLocation({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    final String userId = _requireUserId();
    await _client.from('workers').update({
      'latitude': latitude,
      'longitude': longitude,
      'address': address.trim(),
    }).eq('id', userId);
  }

  Future<void> markRouteActive({
    required String assignmentId,
    required String routeId,
  }) async {
    await _client.from('route_assignments').update({
      'status': 'active',
    }).eq('id', assignmentId);

    await _client.from('routes').update({
      'status': 'in_progress',
    }).eq('id', routeId);

    _invalidateOverviewCaches();
    _invalidateAssignedStopsCache();
  }

  Future<void> markRouteCompleted({
    required String assignmentId,
    required String routeId,
  }) async {
    await _client.from('route_assignments').update({
      'status': 'completed',
    }).eq('id', assignmentId);

    await _client.from('routes').update({
      'status': 'completed',
    }).eq('id', routeId);

    _invalidateOverviewCaches();
    _invalidateAssignedStopsCache();
  }

  void _invalidateOverviewCaches() {
    _cachedAnalytics = null;
    _cachedAnalyticsAt = null;
    _analyticsInFlight = null;

    _cachedWorkerStatus = null;
    _cachedWorkerStatusAt = null;
    _workerStatusInFlight = null;
  }

  void _invalidateAssignedStopsCache() {
    _cachedAssignedStops = null;
    _cachedAssignedStopsAt = null;
    _assignedStopsInFlight = null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  double? _parseDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  Future<String> _resolveReadableLocation({
    required String? preferredLabel,
    required double latitude,
    required double longitude,
  }) async {
    final String cleaned = (preferredLabel ?? '').trim();
    if (cleaned.isNotEmpty && !_looksLikeCoordinates(cleaned)) {
      return cleaned;
    }

    try {
      final List<Placemark> marks =
          await placemarkFromCoordinates(latitude, longitude);
      if (marks.isNotEmpty) {
        final Placemark p = marks.first;
        final List<String> parts = <String>[
          p.name ?? '',
          p.subLocality ?? '',
          p.locality ?? '',
          p.administrativeArea ?? '',
          p.postalCode ?? '',
        ].where((String v) => v.trim().isNotEmpty).toList(growable: false);

        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (_) {
      // Keep fallback below.
    }

    if (cleaned.isNotEmpty) {
      return cleaned;
    }

    return 'Lat ${latitude.toStringAsFixed(5)}, Lng ${longitude.toStringAsFixed(5)}';
  }

  bool _looksLikeCoordinates(String text) {
    final String value = text.trim();
    final RegExp simple = RegExp(r'^-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?$');
    if (simple.hasMatch(value)) {
      return true;
    }

    final String lower = value.toLowerCase();
    return lower.contains('lat') && lower.contains('lng');
  }

  String _requireUserId() {
    final String? userId = AuthService.currentUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('User session not found. Please login again.');
    }
    return userId;
  }
}

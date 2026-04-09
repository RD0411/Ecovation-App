import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/google_navigation_service.dart';
import '../services/waste_worker_dashboard_service.dart';

const LatLng _kFallbackOrigin = LatLng(18.4516, 73.8544);
const LatLng _kFallbackDest = LatLng(18.5018, 73.8636);

const Color _kRouteColor = Color(0xFF00BFFF);
const Color _kGreen = Color(0xFF2E7D32);
const Color _kPanelGradStart = Color(0xFF1B5E20);
const Color _kPanelGradEnd = Color(0xFF388E3C);

const String _kMapStyleDark = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#242f3e"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#263c3f"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#6b9a76"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212a37"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9ca5b3"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#746855"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#1f2835"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#f3d19c"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#2f3948"}]},
  {"featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#515c6d"}]},
  {"featureType": "water", "elementType": "labels.text.stroke", "stylers": [{"color": "#17263c"}]}
]
''';

class WasteWorkerDashboardScreen extends StatefulWidget {
  const WasteWorkerDashboardScreen({
    super.key,
    this.openRouteView = false,
    this.onRouteViewHandled,
  });

  final bool openRouteView;
  final VoidCallback? onRouteViewHandled;

  @override
  State<WasteWorkerDashboardScreen> createState() =>
      _WasteWorkerDashboardScreenState();
}

class _WasteWorkerDashboardScreenState extends State<WasteWorkerDashboardScreen> {
  final WasteWorkerDashboardService _service = WasteWorkerDashboardService();

  GoogleMapController? _mapController;
  final Set<Marker> _markers = <Marker>{};
  final Set<Polyline> _polylines = <Polyline>{};

  LatLng? _origin;
  LatLng? _destination;
  String _routeName = 'Assigned Route';
  String _routeStartText = '-';
  String _routeEndText = '-';
  String _assignmentStatus = 'assigned';
  String _routeStatus = 'planned';

  List<WaypointStop> _stops = <WaypointStop>[];
  bool _fetchingStops = true;
  bool _loadingOverview = true;
  RouteInfo? _routeInfo;
  int _currentStopIndex = 0;
  bool _routeStarted = false;
  bool _routeLoading = false;
  bool _showRouteUi = false;

  String _workerStatus = 'available';
  int _assignedCount = 0;
  int _activeCount = 0;
  int _completedCount = 0;
  bool _updatingStatus = false;

  String? _assignmentId;
  String? _routeId;

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;

  NavigationSnapshot _navSnapshot = const NavigationSnapshot(
    totalStops: 0,
    completedStops: 0,
    pendingStops: 0,
    distanceToNextMeters: 0,
    deviationMeters: 0,
  );

  bool _recalculating = false;
  bool _syncingPosition = false;
  DateTime? _lastPositionSyncAt;

  Timer? _dwellTimer;
  int? _dwellingStopIndex;

  bool _autoTrack = true;

  BitmapDescriptor? _iconCar;
  BitmapDescriptor? _iconOrigin;
  BitmapDescriptor? _iconDest;

  @override
  void initState() {
    super.initState();
    _showRouteUi = widget.openRouteView;
    _loadCustomIcons();
    _loadInitialData();
    _initLocation();
  }

  Future<void> _loadInitialData() async {
    await Future.wait<void>([
      _loadOverview(),
      _fetchDynamicStops(),
    ]);
  }

  @override
  void didUpdateWidget(covariant WasteWorkerDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.openRouteView && widget.openRouteView) {
      setState(() {
        _showRouteUi = true;
      });
      widget.onRouteViewHandled?.call();
    }
  }

  Future<void> _loadOverview({bool forceRefresh = false}) async {
    setState(() {
      _loadingOverview = true;
    });
    try {
      final List<dynamic> overview = await Future.wait<dynamic>([
        _service.getWorkerStatus(forceRefresh: forceRefresh),
        _service.getAssignmentAnalytics(forceRefresh: forceRefresh),
      ]);
      final String status = overview[0] as String;
      final Map<String, int> analytics = overview[1] as Map<String, int>;
      if (!mounted) {
        return;
      }
      setState(() {
        _workerStatus = status;
        _assignedCount = analytics['assigned'] ?? 0;
        _activeCount = analytics['active'] ?? 0;
        _completedCount = analytics['completed'] ?? 0;
      });
    } catch (_) {
      // Keep fallback values.
    } finally {
      if (mounted) {
        setState(() {
          _loadingOverview = false;
        });
      }
    }
  }

  Future<void> _fetchDynamicStops({bool forceRefresh = false}) async {
    try {
      final WorkerAssignedRouteData routeData =
          await _service.fetchAssignedStops(forceRefresh: forceRefresh);
      if (!mounted) {
        return;
      }
      setState(() {
        _assignmentId = routeData.assignmentId;
        _routeId = routeData.routeId;
        _routeName = routeData.routeName;
        _routeStartText = routeData.startLocation;
        _routeEndText = routeData.endLocation;
        _assignmentStatus = routeData.assignmentStatus;
        _routeStatus = routeData.routeStatus;
        _stops = routeData.stops;
        _origin = routeData.origin;
        _destination = routeData.destination;
        _fetchingStops = false;
      });
      _buildStaticMarkers();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _fetchingStops = false;
      });
      _showSnack('Failed to load assignment: $e');
    }
  }

  Future<void> _loadCustomIcons() async {
    _iconCar = await _createNavigationArrow();
    _iconOrigin = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    _iconDest = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  Future<BitmapDescriptor> _createNavigationArrow() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paintOuter = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint paintInner = Paint()
      ..color = Colors.blue.shade700
      ..style = PaintingStyle.fill;

    final Path outerPath = Path()
      ..moveTo(50, 0)
      ..lineTo(100, 100)
      ..lineTo(50, 75)
      ..lineTo(0, 100)
      ..close();

    final Path innerPath = Path()
      ..moveTo(50, 10)
      ..lineTo(90, 92)
      ..lineTo(50, 70)
      ..lineTo(10, 92)
      ..close();

    canvas.save();
    canvas.scale(0.8);
    canvas.drawShadow(outerPath, Colors.black45, 6, false);
    canvas.drawPath(outerPath, paintOuter);
    canvas.drawPath(innerPath, paintInner);
    canvas.restore();

    final ui.Image image = await pictureRecorder.endRecording().toImage(80, 80);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  Future<void> _initLocation() async {
    final PermissionStatus status = await Permission.location.request();
    if (!status.isGranted) {
      _showSnack('Location permission denied. Using fallback origin.');
      _buildStaticMarkers();
      return;
    }

    try {
      final Position pos = await Geolocator.getCurrentPosition();
      if (!mounted) {
        return;
      }
      setState(() {
        _currentPosition = pos;
      });
      await _syncWorkerLocationIfNeeded(force: true);
    } catch (_) {
      // Keep fallback.
    }

    _buildStaticMarkers();
    _startLocationStream();
  }

  void _startLocationStream() {
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPositionUpdate, onError: (_) {});
  }

  Future<void> _onPositionUpdate(Position pos) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _currentPosition = pos;
    });

    await _syncWorkerLocationIfNeeded();
    _updateCarMarker(LatLng(pos.latitude, pos.longitude), pos.heading);

    if (!_routeStarted || _routeInfo == null) {
      return;
    }

    final LatLng userLL = LatLng(pos.latitude, pos.longitude);

    if (_autoTrack && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: userLL,
            bearing: pos.heading,
            tilt: 60,
            zoom: 18,
          ),
        ),
      );
    }

    if (_currentStopIndex < _stops.length) {
      final WaypointStop target = _stops[_currentStopIndex];
      final bool insideRadius = target.isPending &&
          GoogleNavigationService.isWithinCompletionRadius(userLL, target);

      if (insideRadius) {
        if (_dwellTimer == null || _dwellingStopIndex != _currentStopIndex) {
          _dwellTimer?.cancel();
          _dwellingStopIndex = _currentStopIndex;
          _showSnack('Stop detected within 50m. Hold for 60s to auto-complete.');

          _dwellTimer = Timer(const Duration(seconds: 60), () {
            if (_dwellingStopIndex == _currentStopIndex) {
              _autoCompleteStop(_currentStopIndex);
              _dwellTimer?.cancel();
              _dwellTimer = null;
              _dwellingStopIndex = null;
            }
          });
        }
      } else if (_dwellTimer != null) {
        _dwellTimer?.cancel();
        _dwellTimer = null;
        _dwellingStopIndex = null;
        _showSnack('Left 50m radius. Arrival timer reset.');
      }
    }

    if (!_recalculating &&
        GoogleNavigationService.shouldRecalculate(userLL, _routeInfo!.polylinePoints)) {
      _recalculateRoute();
    }

    _refreshNavSnapshot(userLL);
  }

  Future<void> _syncWorkerLocationIfNeeded({bool force = false}) async {
    if (_syncingPosition) {
      return;
    }

    final Position? pos = _currentPosition;
    if (pos == null) {
      return;
    }

    final DateTime now = DateTime.now();
    final bool intervalPassed = _lastPositionSyncAt == null ||
        now.difference(_lastPositionSyncAt!).inSeconds >= 20;

    if (!force && !intervalPassed) {
      return;
    }

    _syncingPosition = true;
    try {
      await _service.updateWorkerLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        address:
            'Lat ${pos.latitude.toStringAsFixed(5)}, Lng ${pos.longitude.toStringAsFixed(5)}',
      );
      _lastPositionSyncAt = now;
    } catch (_) {
      // Ignore intermittent sync failures while tracking.
    } finally {
      _syncingPosition = false;
    }
  }

  Future<void> _changeWorkerStatus(String status) async {
    if (_updatingStatus || _workerStatus == status) {
      return;
    }

    setState(() {
      _updatingStatus = true;
    });

    try {
      await _service.updateWorkerAvailability(status);
      if (!mounted) {
        return;
      }
      setState(() {
        _workerStatus = status;
      });
      _showSnack('Status updated to ${status.toUpperCase()}');
    } catch (e) {
      _showSnack('Failed to update status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _updatingStatus = false;
        });
      }
    }
  }

  Future<void> _autoCompleteStop(int index) async {
    if (index < 0 || index >= _stops.length) {
      return;
    }

    final WaypointStop stop = _stops[index];
    setState(() {
      _stops[index] = _stops[index].copyWith(status: StopStatus.completed);
    });
    _rebuildStopMarkers();

    if (index < _stops.length - 1) {
      setState(() {
        _currentStopIndex = index + 1;
        _stops[_currentStopIndex] =
            _stops[_currentStopIndex].copyWith(status: StopStatus.inProgress);
      });

      final WaypointStop next = _stops[_currentStopIndex];
      _mapController?.animateCamera(CameraUpdate.newLatLng(next.latLng));
    } else {
      setState(() {
        _routeStarted = false;
      });
      await _completeRouteOnServer();
      _showSnack('All stops completed. Great work!');
    }

    _showSnack('${stop.name} marked complete.');
    if (_currentPosition != null) {
      _refreshNavSnapshot(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      );
    }
  }

  Future<void> _completeRouteOnServer() async {
    if (_assignmentId == null || _routeId == null) {
      return;
    }
    try {
      await _service.markRouteCompleted(
        assignmentId: _assignmentId!,
        routeId: _routeId!,
      );
      _assignmentStatus = 'completed';
      _routeStatus = 'completed';
      await _loadOverview();
    } catch (e) {
      _showSnack('Route completion pending: $e');
    }
  }

  void _refreshNavSnapshot(LatLng userLL) {
    if (_routeInfo == null) {
      return;
    }

    final NavigationSnapshot snap = GoogleNavigationService.buildNavigationSnapshot(
      stops: _stops,
      currentStopIndex: _currentStopIndex,
      userLocation: userLL,
      routePolyline: _routeInfo!.polylinePoints,
    );
    setState(() {
      _navSnapshot = snap;
    });
  }

  Future<void> _startRoute() async {
    if (_stops.isEmpty) {
      _showSnack('No collection spots mapped to this route.');
      return;
    }

    setState(() {
      _routeLoading = true;
      _currentStopIndex = 0;
      _stops = _stops
          .map((WaypointStop s) => s.copyWith(status: StopStatus.pending))
          .toList();
      _autoTrack = true;
      _showRouteUi = true;
    });

    final LatLng origin = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : (_origin ?? _kFallbackOrigin);

    try {
      if (_assignmentId != null && _routeId != null) {
        await _service.markRouteActive(
          assignmentId: _assignmentId!,
          routeId: _routeId!,
        );
      }

      final RouteInfo info = await GoogleNavigationService.fetchOptimizedRoute(
        origin: origin,
        stops: _stops,
        destination: _destination ?? _kFallbackDest,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _routeInfo = info;
        _stops = info.orderedStops;
        if (_stops.isNotEmpty) {
          _stops[0] = _stops[0].copyWith(status: StopStatus.inProgress);
        }
        _routeStarted = true;
        _routeLoading = false;
        _assignmentStatus = 'active';
        _routeStatus = 'in_progress';
      });

      _drawPolyline(info.polylinePoints);
      _rebuildStopMarkers();
      _fitCameraToRoute(info.polylinePoints);
      _refreshNavSnapshot(origin);
      _showSnack('Optimized route started.');
      await _loadOverview();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _routeLoading = false;
      });
      _showSnack('Failed to start route: $e');
    }
  }

  Future<void> _recalculateRoute() async {
    if (_recalculating || _currentPosition == null) {
      return;
    }

    setState(() {
      _recalculating = true;
    });

    final LatLng currentLL =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final List<WaypointStop> remaining = _stops.skip(_currentStopIndex).toList();

    try {
      final RouteInfo info = await GoogleNavigationService.fetchOptimizedRoute(
        origin: currentLL,
        stops: remaining,
        destination: _destination ?? _kFallbackDest,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _routeInfo = info;
        _stops = [
          ..._stops.sublist(0, _currentStopIndex),
          ...info.orderedStops,
        ];
        _recalculating = false;
      });

      _drawPolyline(info.polylinePoints);
      _rebuildStopMarkers();
      _refreshNavSnapshot(currentLL);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _recalculating = false;
      });
    }
  }

  void _buildStaticMarkers() {
    final Set<Marker> markers = <Marker>{};

    markers.add(
      Marker(
        markerId: const MarkerId('origin'),
        position: _origin ?? _kFallbackOrigin,
        icon: _iconOrigin ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(
          title: 'Route Start',
          snippet: 'Starting point',
        ),
      ),
    );

    markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: _destination ?? _kFallbackDest,
        icon: _iconDest ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(
          title: 'Route Destination',
          snippet: 'Final point',
        ),
      ),
    );

    for (int i = 0; i < _stops.length; i++) {
      markers.add(_buildStopMarker(_stops[i], i));
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
    });
  }

  void _rebuildStopMarkers() {
    _markers.removeWhere((Marker m) => m.markerId.value.startsWith('stop_'));
    for (int i = 0; i < _stops.length; i++) {
      _markers.add(_buildStopMarker(_stops[i], i));
    }
    setState(() {});
  }

  Marker _buildStopMarker(WaypointStop stop, int index) {
    final bool isCurrent = _routeStarted && index == _currentStopIndex && !stop.isCompleted;
    final bool isCompleted = stop.isCompleted;

    double hue;
    if (isCompleted) {
      hue = BitmapDescriptor.hueGreen;
    } else if (isCurrent) {
      hue = BitmapDescriptor.hueCyan;
    } else {
      hue = BitmapDescriptor.hueRed;
    }

    final String statusLabel = isCompleted
        ? 'Completed'
        : isCurrent
            ? 'Current target'
            : 'Pending';

    final String distSnippet = stop.distanceFromPreviousMeters != null
        ? 'Distance ${GoogleNavigationService.formatDistance(stop.distanceFromPreviousMeters!)}'
            '${stop.etaFromPrevious != null ? '  ETA ${GoogleNavigationService.formatDuration(stop.etaFromPrevious!)}' : ''}'
        : '';

    final String addressLine =
        stop.address != null && stop.address!.trim().isNotEmpty ? '\n${stop.address}' : '';

    return Marker(
      markerId: MarkerId('stop_${stop.id}'),
      position: stop.latLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      onTap: () => _showStopDetails(stop, index),
      infoWindow: InfoWindow(
        title: '${index + 1}. ${stop.name}',
        snippet: '$statusLabel$addressLine${distSnippet.isNotEmpty ? '\n$distSnippet' : ''}',
      ),
    );
  }

  void _showStopDetails(WaypointStop stop, int index) {
    final bool isCurrent = _routeStarted && index == _currentStopIndex && !stop.isCompleted;
    final bool isCompleted = stop.isCompleted;

    String status;
    if (isCompleted) {
      status = 'Completed';
    } else if (isCurrent) {
      status = 'Current Target';
    } else {
      status = 'Pending';
    }

    final Position? pos = _currentPosition;
    final double? distanceFromWorker = pos == null
        ? null
        : Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            stop.latLng.latitude,
            stop.latLng.longitude,
          );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. ${stop.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF25323C),
                  ),
                ),
                const SizedBox(height: 8),
                _detailRow('Status', status),
                _detailRow('Type', stop.isAdditional ? 'Report Spot' : 'Collection Spot'),
                _detailRow(
                  'Address',
                  (stop.address ?? '').trim().isEmpty
                      ? 'Address unavailable'
                      : stop.address!.trim(),
                ),
                _detailRow(
                  'Coordinates',
                  '${stop.latLng.latitude.toStringAsFixed(6)}, ${stop.latLng.longitude.toStringAsFixed(6)}',
                ),
                if (stop.distanceFromPreviousMeters != null)
                  _detailRow(
                    'Distance From Previous',
                    GoogleNavigationService.formatDistance(stop.distanceFromPreviousMeters!),
                  ),
                if (stop.etaFromPrevious != null)
                  _detailRow(
                    'ETA From Previous',
                    GoogleNavigationService.formatDuration(stop.etaFromPrevious!),
                  ),
                if (distanceFromWorker != null)
                  _detailRow(
                    'Distance From You',
                    GoogleNavigationService.formatDistance(distanceFromWorker),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(stop.latLng, 17),
                      );
                    },
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Focus This Spot'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF687783),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Text(':  '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF25323C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateCarMarker(LatLng pos, double heading) {
    _markers.removeWhere((Marker m) => m.markerId.value == 'car');
    _markers.add(
      Marker(
        markerId: const MarkerId('car'),
        position: pos,
        icon: _iconCar ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Live driver position',
        ),
        rotation: heading,
        flat: true,
        anchor: const Offset(0.5, 0.5),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _drawPolyline(List<LatLng> points) {
    setState(() {
      _polylines
        ..clear()
        ..add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: _kRouteColor,
            width: 8,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
    });
  }

  void _fitCameraToRoute(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) {
      return;
    }

    final double south = points
        .map((LatLng p) => p.latitude)
        .reduce((double a, double b) => a < b ? a : b);
    final double north = points
        .map((LatLng p) => p.latitude)
        .reduce((double a, double b) => a > b ? a : b);
    final double west = points
        .map((LatLng p) => p.longitude)
        .reduce((double a, double b) => a < b ? a : b);
    final double east = points
        .map((LatLng p) => p.longitude)
        .reduce((double a, double b) => a > b ? a : b);

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        60,
      ),
    );
  }

  void _centerOnUser() {
    final Position? pos = _currentPosition;
    if (pos == null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_origin ?? _kFallbackOrigin, 14),
      );
      return;
    }
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15),
    );
  }

  Future<void> _markCurrentStopComplete() async {
    if (!_routeStarted || _currentStopIndex >= _stops.length) {
      return;
    }
    await _autoCompleteStop(_currentStopIndex);
  }

  void _showSnack(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Widget _statusButton(String value, IconData icon) {
    final bool selected = _workerStatus == value;
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: _updatingStatus || selected ? null : () => _changeWorkerStatus(value),
        icon: Icon(icon, size: 16),
        label: Text(value.toUpperCase()),
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? Colors.white : _kGreen,
          backgroundColor: selected ? _kGreen : null,
        ),
      ),
    );
  }

  Widget _analyticsCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
             color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
             border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewBody() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait<void>([
          _loadOverview(forceRefresh: true),
          _fetchDynamicStops(forceRefresh: true),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kPanelGradStart, _kPanelGradEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _routeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Journey Start Point: $_routeStartText', style: const TextStyle(color: Colors.white)),
                Text('Journey End Point: $_routeEndText', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  'Assignment: ${_assignmentStatus.toUpperCase()} | Route: ${_routeStatus.toUpperCase()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mapped Collection Stops: ${_stops.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Change Status',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statusButton('available', Icons.check_circle_outline),
                      const SizedBox(width: 8),
                      _statusButton('busy', Icons.local_shipping_outlined),
                      const SizedBox(width: 8),
                      _statusButton('offline', Icons.power_settings_new),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assignment Analytics',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _analyticsCard('Assigned', _assignedCount, const Color(0xFFE67E22)),
                      const SizedBox(width: 8),
                      _analyticsCard('Active', _activeCount, const Color(0xFF2D9CDB)),
                      const SizedBox(width: 8),
                      _analyticsCard('Done', _completedCount, const Color(0xFF27AE60)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assigned Route Card',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(_routeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.trip_origin, size: 16, color: Color(0xFF1E8449)),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Start Point: $_routeStartText')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.flag, size: 16, color: Color(0xFFC0392B)),
                      const SizedBox(width: 6),
                      Expanded(child: Text('End Point: $_routeEndText')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: (_stops.isEmpty || _routeLoading) ? null : _startRoute,
                    icon: _routeLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.map_outlined),
                    label: const Text('Start Map Navigation'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Map mode opens only after Assigned -> View or Start Map Navigation.',
                    style: TextStyle(color: Color(0xFF6F7C82), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPanel() {
    final NavigationSnapshot snap = _navSnapshot;
    final bool isNavigating = _routeStarted && snap.currentStop != null;

    if (!isNavigating) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kPanelGradStart, _kPanelGradEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.alt_route, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _routeName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_routeLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: const Color(0xFF0B6A48),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.turn_right_rounded, color: Colors.white, size: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snap.currentStop!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      GoogleNavigationService.formatDistance(
                        snap.distanceToNextMeters,
                      ),
                      style: TextStyle(
                        color: Colors.white.withAlpha(230),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    if (!_routeStarted) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 8,
            ),
            onPressed: _routeLoading || _fetchingStops ? null : _startRoute,
            icon: _routeLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.navigation_rounded),
            label: Text(
              _routeLoading ? 'Optimizing...' : 'Start Route',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    final RouteInfo? routeInfo = _routeInfo;
    if (routeInfo == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _routeStarted = false;
                  _showRouteUi = false;
                  _polylines.clear();
                });
              },
              child: const Icon(Icons.close, color: Colors.white70, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    GoogleNavigationService.formatDuration(routeInfo.totalDuration),
                    style: const TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${GoogleNavigationService.formatDistance(routeInfo.totalDistanceMeters)} • '
                    '${DateTime.now().add(routeInfo.totalDuration).hour.toString().padLeft(2, '0')}:'
                    '${DateTime.now().add(routeInfo.totalDuration).minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: _recalculateRoute,
              child: Icon(
                Icons.alt_route,
                color: _recalculating ? Colors.grey : Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatsDialog() {
    final NavigationSnapshot snap = _navSnapshot;
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Trip Progress',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow(
                'Total Stops',
                _stops.length.toString(),
                Colors.blueAccent,
              ),
              const SizedBox(height: 16),
              _buildStatRow(
                'Completed',
                snap.completedStops.toString(),
                const Color(0xFF4ADE80),
              ),
              const SizedBox(height: 16),
              _buildStatRow(
                'Pending',
                snap.pendingStops.toString(),
                Colors.orangeAccent,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _markCurrentStopComplete();
              },
              child: const Text('Mark Current Complete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(50),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _mapFab(
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
    Color? iconColor,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: iconColor ?? Colors.black87),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingOverview || _fetchingStops) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_showRouteUi) {
      return _buildOverviewBody();
    }

    return Scaffold(
      body: Column(
        children: [
          _buildTopPanel(),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (GoogleMapController ctrl) {
                    _mapController = ctrl;
                    final Position? pos = _currentPosition;
                    if (pos != null) {
                      ctrl.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(pos.latitude, pos.longitude),
                          13,
                        ),
                      );
                    } else {
                      ctrl.moveCamera(
                        CameraUpdate.newLatLngZoom(_origin ?? _kFallbackOrigin, 13),
                      );
                    }
                    _buildStaticMarkers();
                  },
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          )
                        : (_origin ?? _kFallbackOrigin),
                    zoom: 13,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  style: _kMapStyleDark,
                  mapType: MapType.normal,
                  buildingsEnabled: true,
                  trafficEnabled: true,
                  onCameraMoveStarted: () {
                    if (_routeStarted && _autoTrack) {
                      setState(() {
                        _autoTrack = false;
                      });
                    }
                  },
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      _mapFab(Icons.list_alt, _showStatsDialog, tooltip: 'Route Stats'),
                      const SizedBox(height: 8),
                      _mapFab(
                        _autoTrack ? Icons.my_location : Icons.explore_outlined,
                        () {
                          setState(() {
                            _autoTrack = true;
                          });
                          _centerOnUser();
                        },
                        tooltip: 'Center on me',
                        iconColor: _autoTrack ? Colors.blue : Colors.black87,
                      ),
                      if (_routeInfo != null) ...[
                        const SizedBox(height: 8),
                        _mapFab(
                          Icons.fit_screen,
                          () {
                            setState(() {
                              _autoTrack = false;
                            });
                            if (_routeInfo != null) {
                              _fitCameraToRoute(_routeInfo!.polylinePoints);
                            }
                          },
                          tooltip: 'Fit route',
                        ),
                      ],
                    ],
                  ),
                ),
                if (_recalculating)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(strokeWidth: 2),
                              SizedBox(width: 14),
                              Text('Recalculating route...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                _buildBottomSheet(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

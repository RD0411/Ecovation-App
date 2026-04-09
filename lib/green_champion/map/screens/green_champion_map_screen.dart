import '../../models/green_champion_report.dart';
import '../../services/green_champion_data_source.dart';
import '../../services/green_champion_module_models.dart';
import '../../services/green_champion_module_provider.dart';
import '../../widgets/green_champion_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GreenChampionMapScreen extends StatefulWidget {
  const GreenChampionMapScreen({super.key});

  @override
  State<GreenChampionMapScreen> createState() => _GreenChampionMapScreenState();
}

class _GreenChampionMapScreenState extends State<GreenChampionMapScreen> {
  final GreenChampionDataSource _repository = GreenChampionModuleProvider.instance;
  static const double _coverageRadiusMeters = 2000;

  late Future<_MapViewData> _mapFuture;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _mapFuture = _loadMapData();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<_MapViewData> _loadMapData() async {
    final List<dynamic> results = await Future.wait<dynamic>([
      _repository.getMapReports(),
      _repository.getProfile(),
    ]);
    final List<GreenChampionReport> reports = results[0] as List<GreenChampionReport>;
    final GreenChampionProfileData profile = results[1] as GreenChampionProfileData;
    return _MapViewData(reports: reports, profile: profile);
  }

  Future<_MapViewData> _loadMapDataForceRefresh() async {
    final List<dynamic> results = await Future.wait<dynamic>([
      _repository.getMapReports(forceRefresh: true),
      _repository.getProfile(forceRefresh: true),
    ]);
    final List<GreenChampionReport> reports = results[0] as List<GreenChampionReport>;
    final GreenChampionProfileData profile = results[1] as GreenChampionProfileData;
    return _MapViewData(reports: reports, profile: profile);
  }

  Future<void> _refresh() async {
    final Future<_MapViewData> next = _loadMapDataForceRefresh();
    setState(() {
      _mapFuture = next;
    });
    await next;
  }

  Future<void> _moveCameraTo(LatLng target, {double zoom = 15}) async {
    final GoogleMapController? controller = _mapController;
    if (controller == null) {
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom),
      ),
    );
  }

  void _showMarkerInfo(GreenChampionReport report) {
    if (report.lat != null && report.lng != null) {
      _moveCameraTo(LatLng(report.lat!, report.lng!), zoom: 16);
    }

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(report.category),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(report.notes),
            const SizedBox(height: 12),
            Text(
              'Status: ${report.status.toUpperCase()}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: report.isVerified
                    ? GreenChampionUi.verified
                    : GreenChampionUi.pending,
              ),
            ),
            const SizedBox(height: 6),
            Text('Location: ${report.lat}, ${report.lng}'),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_MapViewData>(
        future: _mapFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Text(
                  'Failed to load map data: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            );
          }

          final _MapViewData mapData = snapshot.data ??
              const _MapViewData(
                reports: <GreenChampionReport>[],
                profile: GreenChampionProfileData(
                  name: 'Green Champion',
                  email: '-',
                  points: 0,
                  ward: '-',
                  badge: '-',
                  missionsCompleted: 0,
                  verificationAccuracy: 0,
                  latitude: null,
                  longitude: null,
                ),
              );

          final List<GreenChampionReport> reports = mapData.reports;
          if (reports.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: const <Widget>[
                Text('No report coordinates available yet.'),
              ],
            );
          }

              final LatLng? championCenter =
                mapData.profile.latitude != null && mapData.profile.longitude != null
                ? LatLng(mapData.profile.latitude!, mapData.profile.longitude!)
                : null;
              final GreenChampionReport first = reports.first;
              final LatLng center = championCenter ?? LatLng(first.lat!, first.lng!);
          final int pending =
              reports.where((GreenChampionReport r) => r.isPending).length;
          final int verified =
              reports.where((GreenChampionReport r) => r.isVerified).length;

          final Set<Marker> markers = reports.map((GreenChampionReport report) {
            return Marker(
              markerId: MarkerId(report.id),
              position: LatLng(report.lat!, report.lng!),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                report.isVerified
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueOrange,
              ),
              onTap: () => _showMarkerInfo(report),
              infoWindow: InfoWindow(
                title: report.category,
                snippet: 'Status: ${report.status.toUpperCase()}',
                onTap: () => _showMarkerInfo(report),
              ),
            );
          }).toSet();

          if (championCenter != null) {
            markers.add(
              Marker(
                markerId: const MarkerId('champion_area_center'),
                position: championCenter,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
                infoWindow: const InfoWindow(
                  title: 'Your Responsibility Area',
                  snippet: '2 km coverage center',
                ),
                onTap: () => _moveCameraTo(championCenter, zoom: 15),
              ),
            );
          }

          final Set<Circle> circles = championCenter == null
              ? const <Circle>{}
              : <Circle>{
                  Circle(
                    circleId: const CircleId('champion_coverage_radius'),
                    center: championCenter,
                    radius: _coverageRadiusMeters,
                    fillColor: const Color(0x33246BFD),
                    strokeColor: const Color(0xFF246BFD),
                    strokeWidth: 2,
                  ),
                };

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Container(
                  width: double.infinity,
                  decoration: GreenChampionUi.heroDecoration,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Hotspot Map',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Active Pins: ${reports.length}   •   Pending: $pending   •   Verified: $verified',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: center,
                        zoom: championCenter != null ? 14.5 : 13,
                      ),
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        if (championCenter != null) {
                          _moveCameraTo(championCenter, zoom: 14.5);
                        }
                      },
                      markers: markers,
                      circles: circles,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      mapToolbarEnabled: true,
                      zoomControlsEnabled: false,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _legendChip('Pending', GreenChampionUi.pending),
                    _legendChip('Verified', GreenChampionUi.verified),
                    if (championCenter != null)
                      _legendChip('Your 2 km Area', const Color(0xFF246BFD)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _legendChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.location_pin, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapViewData {
  const _MapViewData({
    required this.reports,
    required this.profile,
  });

  final List<GreenChampionReport> reports;
  final GreenChampionProfileData profile;
}

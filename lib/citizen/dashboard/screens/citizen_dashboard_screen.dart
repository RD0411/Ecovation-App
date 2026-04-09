import 'package:citizen_impetus/citizen/dashboard/services/citizen_dashboard_service.dart';
import 'package:citizen_impetus/citizen/dashboard/screens/citizen_report_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

class CitizenDashboardScreen extends StatefulWidget {
  const CitizenDashboardScreen({super.key});

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen> {
  final CitizenDashboardService _service = CitizenDashboardService();

  CitizenDashboardData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
    });

    try {
      final CitizenDashboardData data =
          await _service.getDashboardData(forceRefresh: forceRefresh);
      if (!mounted) {
        return;
      }

      setState(() {
        _data = data;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final CitizenDashboardData data = _data!;

    return RefreshIndicator(
      onRefresh: () => _loadDashboard(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
        children: [
          _buildHeroCard(data),
          const SizedBox(height: 12),
          _buildKpiGrid(data),
          const SizedBox(height: 12),
          _buildCollectionMapCard(data),
          const SizedBox(height: 12),
          _buildCollectionSpotsCard(data),
          const SizedBox(height: 12),
          _buildRecentReportsHeader(),
          const SizedBox(height: 8),
          ...data.recentReports.map(_buildRecentReportCard),
          if (data.recentReports.isEmpty)
            _buildEmptyRecentReports(),
        ],
      ),
    );
  }

  Widget _buildHeroCard(CitizenDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D9A44), Color(0xFF1E7833)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${data.citizenName}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            data.address,
            style: const TextStyle(
              color: Color(0xFFE3F1E6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _heroValue('Green Coins', data.greenPoints.toString()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroValue('Total Reports', data.totalReports.toString()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroValue(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE4F0E6),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(CitizenDashboardData data) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _kpiCard(
          title: 'Pending',
          value: data.pendingReports.toString(),
          icon: Icons.schedule_outlined,
          color: const Color(0xFFDD8C2F),
        ),
        _kpiCard(
          title: 'Completed',
          value: data.completedReports.toString(),
          icon: Icons.check_circle_outline,
          color: const Color(0xFF2F9A55),
        ),
        _kpiCard(
          title: 'Verified',
          value: data.verifiedReports.toString(),
          icon: Icons.verified_outlined,
          color: const Color(0xFF2D8CD7),
        ),
        _kpiCard(
          title: 'Events',
          value: data.upcomingEvents.toString(),
          icon: Icons.event_available_outlined,
          color: const Color(0xFF8156B8),
        ),
        _kpiCard(
          title: 'Training',
          value: data.trainingCourses.toString(),
          icon: Icons.ondemand_video_outlined,
          color: const Color(0xFF2A8D84),
        ),
        _kpiCard(
          title: 'Market Live',
          value: data.availableMarketplaceItems.toString(),
          icon: Icons.storefront_outlined,
          color: const Color(0xFF947132),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return LayoutBuilder(
      builder: (context, _) {
        return Container(
          width: (MediaQuery.of(context).size.width - 44) / 2,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDCE4DF)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF27333D),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF75828D),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCollectionMapCard(CitizenDashboardData data) {
    final Set<gmaps.Marker> markers = <gmaps.Marker>{
      gmaps.Marker(
        markerId: const gmaps.MarkerId('citizen_location'),
        position: gmaps.LatLng(data.location.latitude, data.location.longitude),
        infoWindow: const gmaps.InfoWindow(title: 'Your Location'),
      ),
      ...data.collectionSpots.asMap().entries.map(
            (entry) => gmaps.Marker(
              markerId: gmaps.MarkerId('spot_${entry.key}'),
              position: gmaps.LatLng(
                entry.value.location.latitude,
                entry.value.location.longitude,
              ),
              icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                gmaps.BitmapDescriptor.hueGreen,
              ),
              infoWindow: gmaps.InfoWindow(title: entry.value.name),
            ),
          ),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nearby Collection Network',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF2C3944),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Active spots: ${data.collectionSpots.length}  •  My active listings: ${data.myActiveListings}',
              style: const TextStyle(
                color: Color(0xFF71808A),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 220,
                child: gmaps.GoogleMap(
                  initialCameraPosition: gmaps.CameraPosition(
                    target: gmaps.LatLng(data.location.latitude, data.location.longitude),
                    zoom: 13.8,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  markers: markers,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionSpotsCard(CitizenDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Collection Spots',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF2C3944),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (data.collectionSpots.isEmpty)
            const Text(
              'No active collection spots available right now.',
              style: TextStyle(
                color: Color(0xFF74818B),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...data.collectionSpots.map(_buildCollectionSpotTile),
        ],
      ),
    );
  }

  Widget _buildCollectionSpotTile(CollectionSpotItem spot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 13,
            backgroundColor: Color(0xFF2E9B45),
            child: Icon(Icons.location_pin, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spot.name,
                  style: const TextStyle(
                    color: Color(0xFF2C3944),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  spot.address.isEmpty ? 'Address unavailable' : spot.address,
                  style: const TextStyle(
                    color: Color(0xFF6E7C86),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2E9B45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              spot.area.isEmpty ? 'Local' : spot.area,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReportsHeader() {
    return Text(
      'Recent Reports',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF2D3A45),
            fontWeight: FontWeight.w800,
          ),
    );
  }

  Widget _buildRecentReportCard(CitizenReportItem item) {
    final Color chipColor = _statusColor(item.status);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openReportDetails(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.grid_view_rounded, size: 18, color: Color(0xFF4F5B66)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF37414B),
                          ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A939C)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  item.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (item.address.trim().isNotEmpty)
                Text(
                  item.address,
                  style: const TextStyle(
                    color: Color(0xFF6F7D87),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF8A939C)),
                  const SizedBox(width: 6),
                  Text(
                    item.timestamp,
                    style: const TextStyle(
                      color: Color(0xFF8A939C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReportDetails(CitizenReportItem item) async {
    if (item.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report details unavailable for this item.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CitizenReportDetailsScreen(reportId: item.id),
      ),
    );
  }

  Widget _buildEmptyRecentReports() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'No reports available yet. Submit your first waste report from the Report tab.',
        style: TextStyle(
          color: Color(0xFF6D7B85),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return const Color(0xFF2FA658);
      case 'completed':
        return const Color(0xFF2F83D6);
      case 'assigned':
      case 'in progress':
        return const Color(0xFFE08E2C);
      case 'rejected':
        return const Color(0xFFCB3B3B);
      default:
        return const Color(0xFF75808A);
    }
  }
}

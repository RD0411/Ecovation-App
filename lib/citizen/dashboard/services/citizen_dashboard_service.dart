import 'package:citizen_impetus/Authentication/services/auth_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CitizenReportItem {
  const CitizenReportItem({
    required this.id,
    required this.title,
    required this.status,
    required this.address,
    required this.timestamp,
  });

  final String id;
  final String title;
  final String status;
  final String address;
  final String timestamp;
}

class CollectionSpotItem {
  const CollectionSpotItem({
    required this.name,
    required this.address,
    required this.area,
    required this.status,
    required this.location,
  });

  final String name;
  final String address;
  final String area;
  final String status;
  final LatLng location;
}

class CitizenDashboardData {
  const CitizenDashboardData({
    required this.citizenName,
    required this.greenPoints,
    required this.address,
    required this.location,
    required this.totalReports,
    required this.pendingReports,
    required this.completedReports,
    required this.verifiedReports,
    required this.availableMarketplaceItems,
    required this.myActiveListings,
    required this.upcomingEvents,
    required this.trainingCourses,
    required this.collectionSpots,
    required this.recentReports,
  });

  final String citizenName;
  final int greenPoints;
  final String address;
  final LatLng location;
  final int totalReports;
  final int pendingReports;
  final int completedReports;
  final int verifiedReports;
  final int availableMarketplaceItems;
  final int myActiveListings;
  final int upcomingEvents;
  final int trainingCourses;
  final List<CollectionSpotItem> collectionSpots;
  final List<CitizenReportItem> recentReports;
}

class CitizenReportDetails {
  const CitizenReportDetails({
    required this.id,
    required this.category,
    required this.status,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.imageBase64,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String category;
  final String status;
  final String description;
  final String address;
  final double latitude;
  final double longitude;
  final String imageBase64;
  final String createdAt;
  final String updatedAt;
}

class CitizenDashboardService {
  CitizenDashboardService()
      : _client = Supabase.instance.client;

  final SupabaseClient _client;
  CitizenDashboardData? _cachedDashboardData;
  DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(seconds: 45);

  // ---------- Citizen Dashboard ----------

  Future<CitizenDashboardData> getDashboardData({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedDashboardData != null && _cachedAt != null) {
      final Duration age = DateTime.now().difference(_cachedAt!);
      if (age <= _cacheTtl) {
        return _cachedDashboardData!;
      }
    }

    final String userId = _requireUserId();

    final Future<Map<String, dynamic>?> citizenFuture = _client
        .from('citizens')
        .select('full_name, address, latitude, longitude, green_coins')
        .eq('id', userId)
        .maybeSingle();

    final Future<List<dynamic>> reportRowsFuture = _client
        .from('waste_reports')
        .select('id, category, status, address, created_at')
        .eq('citizen_id', userId)
        .order('created_at', ascending: false)
        .limit(20);

    final Future<int> availableMarketplaceItemsFuture = _countByStatus(
      table: 'marketplace_items',
      statusColumn: 'status',
      statusValue: 'available',
    );

    final Future<int> myActiveListingsFuture = _countByStatus(
      table: 'marketplace_items',
      statusColumn: 'status',
      statusValue: 'available',
      eqColumn: 'seller_id',
      eqValue: userId,
    );

    final Future<int> upcomingEventsFuture = _countUpcomingEvents();
    final Future<int> trainingCoursesFuture = _countRows('training_courses');

    final Future<List<dynamic>> spotRowsFuture = _client
        .from('collection_spots')
        .select('name, address, area, status, latitude, longitude')
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(4);

    final List<dynamic> parallelResults = await Future.wait<dynamic>([
      citizenFuture,
      reportRowsFuture,
      availableMarketplaceItemsFuture,
      myActiveListingsFuture,
      upcomingEventsFuture,
      trainingCoursesFuture,
      spotRowsFuture,
    ]);

    final Map<String, dynamic>? citizen = parallelResults[0] as Map<String, dynamic>?;
    final List<dynamic> reportRows = parallelResults[1] as List<dynamic>;
    final int availableMarketplaceItems = parallelResults[2] as int;
    final int myActiveListings = parallelResults[3] as int;
    final int upcomingEvents = parallelResults[4] as int;
    final int trainingCourses = parallelResults[5] as int;
    final List<dynamic> spotRows = parallelResults[6] as List<dynamic>;

    final List<CitizenReportItem> reports = reportRows
        .map((row) {
          final Map<String, dynamic> data = row as Map<String, dynamic>;
          return CitizenReportItem(
            id: data['id']?.toString() ?? '',
            title: (data['category'] as String?)?.trim().isNotEmpty == true
                ? data['category'] as String
                : 'Waste Report',
            status: _prettyStatus(data['status']?.toString()),
            address: data['address']?.toString() ?? '',
            timestamp: _formatTimestamp(data['created_at']?.toString()),
          );
        })
        .toList();

    int pendingReports = 0;
    int completedReports = 0;
    int verifiedReports = 0;

    for (final CitizenReportItem report in reports) {
      final String status = report.status.toLowerCase();
      if (status == 'pending' || status == 'assigned' || status == 'in progress') {
        pendingReports++;
      }
      if (status == 'completed') {
        completedReports++;
      }
      if (status == 'verified') {
        verifiedReports++;
      }
    }

    final List<CollectionSpotItem> collectionSpots = spotRows
        .map((row) {
          final Map<String, dynamic> data = row as Map<String, dynamic>;
          return CollectionSpotItem(
            name: (data['name']?.toString().trim().isNotEmpty ?? false)
                ? data['name'].toString()
                : 'Collection Spot',
            address: data['address']?.toString() ?? '',
            area: data['area']?.toString() ?? '',
            status: data['status']?.toString() ?? 'active',
            location: LatLng(
              _toDouble(data['latitude']) ?? 18.5204,
              _toDouble(data['longitude']) ?? 73.8567,
            ),
          );
        })
        .toList();

    final double latitude = _toDouble(citizen?['latitude']) ?? 18.5204;
    final double longitude = _toDouble(citizen?['longitude']) ?? 73.8567;

    final CitizenDashboardData data = CitizenDashboardData(
      citizenName: citizen?['full_name']?.toString() ?? 'Citizen',
      greenPoints: (citizen?['green_coins'] as int?) ?? 0,
      address: citizen?['address']?.toString() ?? 'Address not available',
      location: LatLng(latitude, longitude),
      totalReports: reports.length,
      pendingReports: pendingReports,
      completedReports: completedReports,
      verifiedReports: verifiedReports,
      availableMarketplaceItems: availableMarketplaceItems,
      myActiveListings: myActiveListings,
      upcomingEvents: upcomingEvents,
      trainingCourses: trainingCourses,
      collectionSpots: collectionSpots,
      recentReports: reports.take(5).toList(),
    );

    _cachedDashboardData = data;
    _cachedAt = DateTime.now();
    return data;
  }

  Future<CitizenReportDetails> getReportDetails(String reportId) async {
    final String userId = _requireUserId();

    final Map<String, dynamic>? row = await _client
        .from('waste_reports')
        .select(
          'id, category, status, description, address, latitude, longitude, image_url, created_at, updated_at, citizen_id',
        )
        .eq('id', reportId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Report not found.');
    }

    if (row['citizen_id']?.toString() != userId) {
      throw Exception('You can only view your own reports.');
    }

    return CitizenReportDetails(
      id: row['id']?.toString() ?? '',
      category: row['category']?.toString() ?? 'Waste Report',
      status: _prettyStatus(row['status']?.toString()),
      description: row['description']?.toString() ?? '',
      address: row['address']?.toString() ?? 'Address unavailable',
      latitude: _toDouble(row['latitude']) ?? 0,
      longitude: _toDouble(row['longitude']) ?? 0,
      imageBase64: row['image_url']?.toString() ?? '',
      createdAt: _formatTimestamp(row['created_at']?.toString()),
      updatedAt: _formatTimestamp(row['updated_at']?.toString()),
    );
  }

  Future<int> _countByStatus({
    required String table,
    required String statusColumn,
    required String statusValue,
    String? eqColumn,
    String? eqValue,
  }) async {
    PostgrestFilterBuilder<PostgrestList> query = _client
        .from(table)
        .select('id')
        .eq(statusColumn, statusValue);

    if (eqColumn != null && eqValue != null) {
      query = query.eq(eqColumn, eqValue);
    }

    final List<dynamic> rows = await query;
    return rows.length;
  }

  Future<int> _countRows(String table) async {
    final List<dynamic> rows = await _client.from(table).select('id');
    return rows.length;
  }

  Future<int> _countUpcomingEvents() async {
    final DateTime now = DateTime.now().toUtc();
    final List<dynamic> rows = await _client
        .from('events')
        .select('id, status, start_date')
        .order('start_date', ascending: true);

    int count = 0;
    for (final dynamic row in rows) {
      final Map<String, dynamic> data = row as Map<String, dynamic>;
      final String status = (data['status']?.toString() ?? '').toLowerCase();
      final DateTime? start = DateTime.tryParse(data['start_date']?.toString() ?? '');
      if (status == 'upcoming' || (start != null && start.isAfter(now))) {
        count++;
      }
    }
    return count;
  }

  String _requireUserId() {
    final String? userId = AuthService.currentUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('User session not found. Please login again.');
    }
    return userId;
  }

  String _prettyStatus(String? raw) {
    switch (raw) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  String _formatTimestamp(String? iso) {
    if (iso == null) {
      return 'Unknown time';
    }

    final DateTime? parsed = DateTime.tryParse(iso)?.toLocal();
    if (parsed == null) {
      return 'Unknown time';
    }

    final List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final int hour12 = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final String minute = parsed.minute.toString().padLeft(2, '0');
    final String amPm = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${parsed.day} ${months[parsed.month - 1]}, $hour12:$minute $amPm';
  }

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}

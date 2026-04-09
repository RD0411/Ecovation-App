import '../../Authentication/services/auth_service.dart';
import '../models/green_champion_report.dart';
import 'green_champion_data_source.dart';
import 'green_champion_module_models.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GreenChampionRepository implements GreenChampionDataSource {
  GreenChampionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const double _coverageRadiusMeters = 2000;
  static const Duration _reportsCacheTtl = Duration(seconds: 45);
  static const Duration _profileCacheTtl = Duration(seconds: 60);
  static const Duration _coverageCacheTtl = Duration(seconds: 60);

  List<Map<String, dynamic>>? _cachedVisibleReportRows;
  DateTime? _cachedVisibleReportRowsAt;
  Future<List<Map<String, dynamic>>>? _visibleRowsInFlight;

  GreenChampionProfileData? _cachedProfile;
  DateTime? _cachedProfileAt;
  Future<GreenChampionProfileData>? _profileInFlight;

  ({double latitude, double longitude})? _cachedCoverageCenter;
  DateTime? _cachedCoverageCenterAt;

  @override
  Future<DashboardStats> getDashboardStats({bool forceRefresh = false}) async {
    final List<Map<String, dynamic>> reportRows =
        await _fetchVisibleWasteReportRows(forceRefresh: forceRefresh);

    int verified = 0;
    int pending = 0;

    for (final Map<String, dynamic> row in reportRows) {
      final String status =
          _readString(row, const ['status'])?.toLowerCase() ?? 'pending';
      if (status == 'verified') {
        verified += 1;
      } else if (status != 'rejected') {
        pending += 1;
      }
    }

    final GreenChampionProfileData profile =
        await getProfile(forceRefresh: forceRefresh);
    final int points = profile.points;

    return DashboardStats(
      verifiedCount: verified,
      pendingCount: pending,
      points: points,
    );
  }

  @override
  Future<ReportsBundle> getReports({bool forceRefresh = false}) async {
    final List<Map<String, dynamic>> rows =
      await _fetchVisibleWasteReportRows(forceRefresh: forceRefresh);

    final List<GreenChampionReport> pending = <GreenChampionReport>[];
    final List<GreenChampionReport> verified = <GreenChampionReport>[];

    for (final Map<String, dynamic> row in rows) {
      final GreenChampionReport report = GreenChampionReport.fromJson(row);
      if (report.isRejected) {
        continue;
      }
      if (report.isVerified) {
        verified.add(report);
      } else {
        pending.add(report);
      }
    }

    return ReportsBundle(pending: pending, verified: verified);
  }

  @override
  Future<void> verifyReport(GreenChampionReport report) {
    return _updateReportStatus(report: report, status: 'verified', awardPoints: true);
  }

  @override
  Future<void> rejectReport(GreenChampionReport report) {
    return _updateReportStatus(report: report, status: 'rejected', awardPoints: false);
  }

  @override
  Future<List<GreenChampionReport>> getMapReports({bool forceRefresh = false}) async {
    final List<Map<String, dynamic>> rows =
      await _fetchVisibleWasteReportRows(forceRefresh: forceRefresh);

    return rows.map(GreenChampionReport.fromJson).where((GreenChampionReport r) {
      return r.lat != null && r.lng != null;
    }).toList();
  }

  @override
  Future<GreenChampionProfileData> getProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedProfile != null && _cachedProfileAt != null) {
      final Duration age = DateTime.now().difference(_cachedProfileAt!);
      if (age <= _profileCacheTtl) {
        return _cachedProfile!;
      }
    }

    if (!forceRefresh && _profileInFlight != null) {
      return _profileInFlight!;
    }

    final Future<GreenChampionProfileData> inFlight = _loadProfileData();
    _profileInFlight = inFlight;
    try {
      final GreenChampionProfileData profile = await inFlight;
      _cachedProfile = profile;
      _cachedProfileAt = DateTime.now();
      return profile;
    } finally {
      _profileInFlight = null;
    }
  }

  Future<GreenChampionProfileData> _loadProfileData() async {
    final AppAuthUser? user = AuthService.currentUser;
    if (user == null) {
      return const GreenChampionProfileData(
        name: 'Green Champion',
        email: 'Not signed in',
        points: 0,
        ward: '-',
        badge: 'New Champion',
        missionsCompleted: 0,
        verificationAccuracy: 0,
        latitude: null,
        longitude: null,
      );
    }

    final List<Map<String, dynamic>> championRows =
      (await _client.from('green_champions').select().eq('id', user.id).limit(1)
                as List<dynamic>)
            .cast<Map<String, dynamic>>();

    final Map<String, dynamic>? row =
      championRows.isEmpty ? null : championRows.first;

    return GreenChampionProfileData(
      name: _readString(
            row,
            const ['full_name', 'name'],
          ) ?? user.fullName,
      email: _readString(row, const ['email']) ?? user.email,
      points: _readInt(row, const ['points']) ?? 0,
      ward: _readString(row, const ['zone']) ?? '-',
      badge: 'Community Guardian',
      missionsCompleted: 0,
      verificationAccuracy: 100,
      latitude: _readDouble(row, const ['latitude']),
      longitude: _readDouble(row, const ['longitude']),
    );
  }

  @override
  Future<List<GreenChampionReport>> getRecentReports({
    int limit = 3,
    bool forceRefresh = false,
  }) async {
    final List<Map<String, dynamic>> rows =
        await _fetchVisibleWasteReportRows(forceRefresh: forceRefresh);

    final List<GreenChampionReport> reports = rows
        .map(GreenChampionReport.fromJson)
        .where((GreenChampionReport report) => !report.isRejected)
        .take(limit)
        .toList(growable: false);

    return reports;
  }

  @override
  Future<void> setPermanentLocation({
    required double latitude,
    required double longitude,
  }) async {
    final String? userId = AuthService.currentUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('No logged in Green Champion');
    }

    try {
      await _client.from('green_champions').update(<String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
      }).eq('id', userId);

      _invalidateProfileCache();
      _invalidateVisibleRowsCache();
      _cachedCoverageCenter = (latitude: latitude, longitude: longitude);
      _cachedCoverageCenterAt = DateTime.now();
    } on PostgrestException catch (error) {
      if (_isMissingColumn(error, 'latitude') ||
          _isMissingColumn(error, 'longitude')) {
        throw Exception(
          'Database schema is missing latitude/longitude in green_champions. '
          'Run schema migration before saving permanent location.',
        );
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchVisibleWasteReportRows({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedVisibleReportRows != null &&
        _cachedVisibleReportRowsAt != null) {
      final Duration age = DateTime.now().difference(_cachedVisibleReportRowsAt!);
      if (age <= _reportsCacheTtl) {
        return _cachedVisibleReportRows!;
      }
    }

    if (!forceRefresh && _visibleRowsInFlight != null) {
      return _visibleRowsInFlight!;
    }

    final Future<List<Map<String, dynamic>>> inFlight =
        _buildVisibleWasteReportRows(forceRefresh: forceRefresh);
    _visibleRowsInFlight = inFlight;
    try {
      final List<Map<String, dynamic>> rows = await inFlight;
      _cachedVisibleReportRows = rows;
      _cachedVisibleReportRowsAt = DateTime.now();
      return rows;
    } finally {
      _visibleRowsInFlight = null;
    }
  }

  Future<List<Map<String, dynamic>>> _buildVisibleWasteReportRows({
    required bool forceRefresh,
  }) async {
    final List<Map<String, dynamic>> rows =
        (await _client
                    .from('waste_reports')
                    .select()
                    .order('created_at', ascending: false)
                as List<dynamic>)
            .cast<Map<String, dynamic>>();

    await _attachCitizenDetails(rows);

    final ({double latitude, double longitude})? coverageCenter =
      await _getCoverageCenter(forceRefresh: forceRefresh);
    if (coverageCenter == null) {
      return rows;
    }

    return rows.where((Map<String, dynamic> row) {
      final double? reportLatitude = _readDouble(row, const ['latitude', 'lat']);
      final double? reportLongitude =
          _readDouble(row, const ['longitude', 'lng']);
      if (reportLatitude == null || reportLongitude == null) {
        return false;
      }

      final double distanceMeters = Geolocator.distanceBetween(
        coverageCenter.latitude,
        coverageCenter.longitude,
        reportLatitude,
        reportLongitude,
      );

      return distanceMeters <= _coverageRadiusMeters;
    }).toList(growable: false);
  }

  Future<void> _attachCitizenDetails(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) {
      return;
    }

    final Set<String> citizenIds = rows
        .map((Map<String, dynamic> row) =>
            _readString(row, const ['citizen_id', 'userId', 'user_id']) ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();

    if (citizenIds.isEmpty) {
      return;
    }

    final List<Map<String, dynamic>> citizenRows =
        (await _client
                    .from('citizens')
                    .select('id,full_name,email,phone')
                    .inFilter('id', citizenIds.toList())
                as List<dynamic>)
            .cast<Map<String, dynamic>>();

    final Map<String, Map<String, dynamic>> citizenById =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> citizen in citizenRows) {
      final String? id = _readString(citizen, const ['id']);
      if (id == null || id.isEmpty) {
        continue;
      }
      citizenById[id] = citizen;
    }

    for (final Map<String, dynamic> row in rows) {
      final String? citizenId =
          _readString(row, const ['citizen_id', 'userId', 'user_id']);
      if (citizenId == null || citizenId.isEmpty) {
        continue;
      }
      final Map<String, dynamic>? citizen = citizenById[citizenId];
      if (citizen == null) {
        continue;
      }

      row['citizen_name'] = _readString(citizen, const ['full_name', 'name']);
      row['citizen_email'] = _readString(citizen, const ['email']);
      row['citizen_phone'] = _readString(citizen, const ['phone']);
    }
  }

  Future<({double latitude, double longitude})?> _getCoverageCenter({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedCoverageCenterAt != null) {
      final Duration age = DateTime.now().difference(_cachedCoverageCenterAt!);
      if (age <= _coverageCacheTtl) {
        return _cachedCoverageCenter;
      }
    }

    final String? userId = AuthService.currentUserId;
    if (userId != null && userId.isNotEmpty) {
      try {
        final List<Map<String, dynamic>> championRows =
            (await _client
                        .from('green_champions')
                        .select('latitude,longitude')
                        .eq('id', userId)
                        .limit(1)
                    as List<dynamic>)
                .cast<Map<String, dynamic>>();

        if (championRows.isNotEmpty) {
          final Map<String, dynamic> row = championRows.first;
          final double? latitude = _readDouble(row, const ['latitude']);
          final double? longitude = _readDouble(row, const ['longitude']);
          if (latitude != null && longitude != null) {
            _cachedCoverageCenter = (latitude: latitude, longitude: longitude);
            _cachedCoverageCenterAt = DateTime.now();
            return _cachedCoverageCenter;
          }
        }
      } on PostgrestException catch (error) {
        // If DB is not yet migrated with location columns, gracefully fall back
        // to device location so reports can still load.
        if (!_isMissingColumn(error, 'latitude') &&
            !_isMissingColumn(error, 'longitude')) {
          rethrow;
        }
      }
    }

    final Position? liveLocation = await _getChampionLiveLocation();
    if (liveLocation == null) {
      _cachedCoverageCenter = null;
      _cachedCoverageCenterAt = DateTime.now();
      return null;
    }

    _cachedCoverageCenter = (
      latitude: liveLocation.latitude,
      longitude: liveLocation.longitude,
    );
    _cachedCoverageCenterAt = DateTime.now();
    return _cachedCoverageCenter;
  }

  Future<Position?> _getChampionLiveLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
    );
    final Position position =
        await Geolocator.getCurrentPosition(locationSettings: settings);

    return position;
  }

  static bool _isMissingColumn(PostgrestException error, String column) {
    final String message = error.message.toLowerCase();
    final String details = '${error.details ?? ''}'.toLowerCase();
    return message.contains(column.toLowerCase()) ||
        details.contains(column.toLowerCase());
  }

  Future<void> _updateReportStatus({
    required GreenChampionReport report,
    required String status,
    required bool awardPoints,
  }) async {
    if (report.status.toLowerCase() == status.toLowerCase()) {
      return;
    }

    final String? verifierId = AuthService.currentUserId;
    final Map<String, dynamic> payload = <String, dynamic>{
      'status': status,
      'verified_by': verifierId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _client.from('waste_reports').update(payload).eq('id', report.id);
    _invalidateVisibleRowsCache();

    if (!awardPoints || report.userId.isEmpty) {
      return;
    }

    final List<Map<String, dynamic>> rows =
      (await _client.from('citizens').select().eq('id', report.userId).limit(1)
                as List<dynamic>)
            .cast<Map<String, dynamic>>();

    if (rows.isEmpty) {
      return;
    }

    final Map<String, dynamic> row = rows.first;
    final int current = _readInt(row, const ['green_coins']) ?? 0;
    final String? rowId = _readString(row, const ['id']);
    if (rowId == null || rowId.isEmpty) {
      return;
    }

    await _client.from('citizens').update(<String, dynamic>{
      'green_coins': current + 10,
    }).eq('id', rowId);

    _invalidateProfileCache();
  }

  void _invalidateVisibleRowsCache() {
    _cachedVisibleReportRows = null;
    _cachedVisibleReportRowsAt = null;
    _visibleRowsInFlight = null;
  }

  void _invalidateProfileCache() {
    _cachedProfile = null;
    _cachedProfileAt = null;
    _profileInFlight = null;
  }

  static String? _readString(Map<String, dynamic>? row, List<String> keys) {
    if (row == null) {
      return null;
    }

    for (final String key in keys) {
      final dynamic value = row[key];
      if (value == null) {
        continue;
      }

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      final String parsed = value.toString().trim();
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    return null;
  }

  static int? _readInt(Map<String, dynamic>? row, List<String> keys) {
    if (row == null) {
      return null;
    }

    for (final String key in keys) {
      final dynamic value = row[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final int? parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  static double? _readDouble(Map<String, dynamic>? row, List<String> keys) {
    if (row == null) {
      return null;
    }

    for (final String key in keys) {
      final dynamic value = row[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final double? parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }
}

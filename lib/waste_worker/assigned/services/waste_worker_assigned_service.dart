import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:citizen_impetus/Authentication/services/auth_service.dart';
import 'package:citizen_impetus/common/models/report.dart';

class WorkerAssignedRouteInfo {
  const WorkerAssignedRouteInfo({
    required this.assignmentId,
    required this.routeId,
    required this.routeName,
    required this.startLocation,
    required this.endLocation,
    required this.frequency,
    required this.scheduledTime,
    required this.status,
  });

  final String assignmentId;
  final String routeId;
  final String routeName;
  final String startLocation;
  final String endLocation;
  final String frequency;
  final String scheduledTime;
  final String status;
}

class WorkerAssignedData {
  const WorkerAssignedData({
    required this.routeInfo,
    required this.reports,
  });

  final WorkerAssignedRouteInfo? routeInfo;
  final List<Report> reports;
}

class WasteWorkerAssignedService {
  WasteWorkerAssignedService() : _supabase = Supabase.instance.client;

  final SupabaseClient _supabase;
  static const Duration _cacheTtl = Duration(seconds: 30);
  WorkerAssignedData? _cachedData;
  DateTime? _cachedAt;
  Future<WorkerAssignedData>? _inFlight;

  Future<WorkerAssignedData> getAssignedData({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedData != null && _cachedAt != null) {
      if (DateTime.now().difference(_cachedAt!) <= _cacheTtl) {
        return _cachedData!;
      }
    }

    if (!forceRefresh && _inFlight != null) {
      return _inFlight!;
    }

    final Future<WorkerAssignedData> inFlight = _loadAssignedData();
    _inFlight = inFlight;
    try {
      final WorkerAssignedData data = await inFlight;
      _cachedData = data;
      _cachedAt = DateTime.now();
      return data;
    } finally {
      _inFlight = null;
    }
  }

  Future<WorkerAssignedData> _loadAssignedData() async {
    final String userId = _requireUserId();

    final Map<String, dynamic>? assignment = await _supabase
        .from('route_assignments')
        .select('id, route_id, status, assigned_at')
        .eq('worker_id', userId)
        .inFilter('status', ['assigned', 'active'])
        .order('assigned_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (assignment == null) {
      return const WorkerAssignedData(routeInfo: null, reports: <Report>[]);
    }

    final String routeId = assignment['route_id']?.toString() ?? '';
    final String assignmentId = assignment['id']?.toString() ?? '';

    if (routeId.isEmpty || assignmentId.isEmpty) {
      return const WorkerAssignedData(routeInfo: null, reports: <Report>[]);
    }

    final List<dynamic> routeAndMapped = await Future.wait<dynamic>([
      _supabase
        .from('routes')
        .select('route_name, start_location, end_location, frequency, scheduled_time, status')
        .eq('id', routeId)
        .maybeSingle(),
      _supabase
        .from('route_reports')
        .select('report_id, waste_reports(*)')
        .eq('route_id', routeId),
    ]);

    final Map<String, dynamic>? route = routeAndMapped[0] as Map<String, dynamic>?;
    final List<dynamic> mapped = routeAndMapped[1] as List<dynamic>;

    final List<Report> reports = <Report>[];
    for (final dynamic row in mapped) {
      final dynamic reportJson = (row as Map<String, dynamic>)['waste_reports'];
      if (reportJson == null) {
        continue;
      }

      final String status = (reportJson['status']?.toString() ?? '').toLowerCase();
      if (status == 'rejected' || status == 'verified') {
        continue;
      }
      reports.add(Report.fromJson(reportJson as Map<String, dynamic>));
    }

    reports.sort((a, b) {
      final int aPriority = _statusPriority(a.status);
      final int bPriority = _statusPriority(b.status);
      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }
      final DateTime aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    final WorkerAssignedRouteInfo info = WorkerAssignedRouteInfo(
      assignmentId: assignmentId,
      routeId: routeId,
      routeName: route?['route_name']?.toString() ?? 'Assigned Route',
      startLocation: route?['start_location']?.toString() ?? '-',
      endLocation: route?['end_location']?.toString() ?? '-',
      frequency: route?['frequency']?.toString() ?? '-',
      scheduledTime: route?['scheduled_time']?.toString() ?? '-',
      status: assignment['status']?.toString() ?? 'assigned',
    );

    return WorkerAssignedData(routeInfo: info, reports: reports);
  }

  Future<List<Report>> getAssignedReports() async {
    final WorkerAssignedData data = await getAssignedData();
    return data.reports;
  }

  Future<void> markReportInProgress(String reportId, String assignmentId) async {
    await _supabase.from('waste_reports').update({
      'status': 'in_progress',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', reportId);

    await _supabase.from('route_assignments').update({
      'status': 'active',
    }).eq('id', assignmentId);

    _invalidateCache();
  }

  Future<void> markReportCompleted({
    required String reportId,
    required String assignmentId,
    required String qrToken,
  }) async {
    if (reportId != qrToken.trim()) {
      throw Exception('QR validation failed. Please scan correct report QR.');
    }

    await _supabase.from('waste_reports').update({
      'status': 'completed',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', reportId);

    final Map<String, dynamic>? assignment = await _supabase
        .from('route_assignments')
        .select('route_id')
        .eq('id', assignmentId)
        .maybeSingle();

    final String routeId = assignment?['route_id']?.toString() ?? '';
    if (routeId.isEmpty) {
      return;
    }

    final List<dynamic> mapped = await _supabase
        .from('route_reports')
        .select('waste_reports(status)')
        .eq('route_id', routeId);

    bool allDone = true;
    for (final dynamic row in mapped) {
      final dynamic waste = (row as Map<String, dynamic>)['waste_reports'];
      final String status = (waste?['status']?.toString() ?? '').toLowerCase();
      if (status != 'completed' && status != 'verified' && status != 'rejected') {
        allDone = false;
        break;
      }
    }

    if (allDone) {
      await _supabase.from('route_assignments').update({
        'status': 'completed',
      }).eq('id', assignmentId);
    }

    _invalidateCache();
  }

  void _invalidateCache() {
    _cachedData = null;
    _cachedAt = null;
    _inFlight = null;
  }

  int _statusPriority(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'assigned':
        return 0;
      case 'in_progress':
        return 1;
      case 'completed':
        return 2;
      default:
        return 3;
    }
  }

  String _requireUserId() {
    final String? userId = AuthService.currentUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('User session not found. Please login again.');
    }
    return userId;
  }
}


import '../models/green_champion_report.dart';
import 'green_champion_data_source.dart';
import 'green_champion_module_models.dart';

class GreenChampionDemoRepository implements GreenChampionDataSource {
  GreenChampionDemoRepository();

  static int _championPoints = 20;
  static double _championLatitude = 19.2187;
  static double _championLongitude = 72.9782;

  static final List<GreenChampionReport> _reports = <GreenChampionReport>[
    const GreenChampionReport(
      id: 'r_101',
      category: 'plastic',
      status: 'pending',
      userId: 'PePkORdTM2hmcpi5PAzwCuBPaN53',
      notes: 'Plastic waste near bus stand, urgent cleanup needed.',
      photoUrl: 'https://picsum.photos/seed/gc101/320/240',
      lat: 19.2187,
      lng: 72.9782,
    ),
    const GreenChampionReport(
      id: 'r_102',
      category: 'Plastic Wrapper',
      status: 'pending',
      userId: 'PePkORdTM2hmcpi5PAzwCuBPaN53',
      notes: 'Lane-side wrapper pile next to tea stall.',
      photoUrl: 'https://picsum.photos/seed/gc102/320/240',
      lat: 19.2169,
      lng: 72.9821,
    ),
    const GreenChampionReport(
      id: 'r_103',
      category: 'Bags',
      status: 'verified',
      userId: 'A1df5RTM2hmcpi5PAzwCuBPaN57',
      notes: 'Garbage bags cleared after citizen complaint.',
      photoUrl: 'https://picsum.photos/seed/gc103/320/240',
      lat: 19.2144,
      lng: 72.9864,
    ),
    const GreenChampionReport(
      id: 'r_104',
      category: 'Metal Scrap',
      status: 'rejected',
      userId: 'Ux07R1TM2hmcpi5PAzwCuBPaN98',
      notes: 'Duplicate report, already verified in another ticket.',
      photoUrl: 'https://picsum.photos/seed/gc104/320/240',
      lat: 19.2128,
      lng: 72.9803,
    ),
  ];

  @override
  Future<DashboardStats> getDashboardStats({bool forceRefresh = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));

    int verified = 0;
    int pending = 0;

    for (final GreenChampionReport report in _reports) {
      if (report.isVerified) {
        verified += 1;
      } else if (!report.isRejected) {
        pending += 1;
      }
    }

    return DashboardStats(
      verifiedCount: verified,
      pendingCount: pending,
      points: _championPoints,
    );
  }

  @override
  Future<ReportsBundle> getReports({bool forceRefresh = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final List<GreenChampionReport> pending = _reports
        .where((GreenChampionReport r) => r.isPending)
        .toList(growable: false);
    final List<GreenChampionReport> verified = _reports
        .where((GreenChampionReport r) => r.isVerified)
        .toList(growable: false);

    return ReportsBundle(pending: pending, verified: verified);
  }

  @override
  Future<void> verifyReport(GreenChampionReport report) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final String previous = _replaceReportWithStatus(report.id, 'verified');
    if (previous != 'verified') {
      _championPoints += 10;
    }
  }

  @override
  Future<void> rejectReport(GreenChampionReport report) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _replaceReportWithStatus(report.id, 'rejected');
  }

  @override
  Future<List<GreenChampionReport>> getMapReports({bool forceRefresh = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    return _reports.where((GreenChampionReport report) {
      return !report.isRejected && report.lat != null && report.lng != null;
    }).toList(growable: false);
  }

  @override
  Future<GreenChampionProfileData> getProfile({bool forceRefresh = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));

    return GreenChampionProfileData(
      name: 'Vivek J Patil',
      email: 'vivekjpatil@gmail.com',
      points: _championPoints,
      ward: 'Ward 12 - Mulund East',
      badge: 'Community Guardian',
      missionsCompleted: 16,
      verificationAccuracy: 94,
      latitude: _championLatitude,
      longitude: _championLongitude,
    );
  }

  @override
  Future<List<GreenChampionReport>> getRecentReports({
    int limit = 3,
    bool forceRefresh = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final List<GreenChampionReport> active = _reports
        .where((GreenChampionReport report) => !report.isRejected)
        .toList(growable: false);

    return active.take(limit).toList(growable: false);
  }

  @override
  Future<void> setPermanentLocation({
    required double latitude,
    required double longitude,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _championLatitude = latitude;
    _championLongitude = longitude;
  }

  String _replaceReportWithStatus(String reportId, String nextStatus) {
    final int index = _reports.indexWhere((GreenChampionReport r) => r.id == reportId);
    if (index < 0) {
      return '';
    }

    final GreenChampionReport current = _reports[index];
    final String oldStatus = current.status;
    _reports[index] = GreenChampionReport(
      id: current.id,
      category: current.category,
      status: nextStatus,
      userId: current.userId,
      notes: current.notes,
      photoBase64: current.photoBase64,
      photoUrl: current.photoUrl,
      lat: current.lat,
      lng: current.lng,
    );

    return oldStatus;
  }
}

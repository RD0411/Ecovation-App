import '../models/green_champion_report.dart';
import 'green_champion_module_models.dart';

abstract class GreenChampionDataSource {
  Future<DashboardStats> getDashboardStats({bool forceRefresh = false});

  Future<ReportsBundle> getReports({bool forceRefresh = false});

  Future<void> verifyReport(GreenChampionReport report);

  Future<void> rejectReport(GreenChampionReport report);

  Future<List<GreenChampionReport>> getMapReports({bool forceRefresh = false});

  Future<GreenChampionProfileData> getProfile({bool forceRefresh = false});

  Future<List<GreenChampionReport>> getRecentReports({
    int limit = 3,
    bool forceRefresh = false,
  });

  Future<void> setPermanentLocation({
    required double latitude,
    required double longitude,
  });
}

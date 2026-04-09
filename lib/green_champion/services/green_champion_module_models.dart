import '../models/green_champion_report.dart';

class DashboardStats {
  const DashboardStats({
    required this.verifiedCount,
    required this.pendingCount,
    required this.points,
  });

  final int verifiedCount;
  final int pendingCount;
  final int points;
}

class ReportsBundle {
  const ReportsBundle({
    required this.pending,
    required this.verified,
  });

  final List<GreenChampionReport> pending;
  final List<GreenChampionReport> verified;
}

class GreenChampionProfileData {
  const GreenChampionProfileData({
    required this.name,
    required this.email,
    required this.points,
    required this.ward,
    required this.badge,
    required this.missionsCompleted,
    required this.verificationAccuracy,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String email;
  final int points;
  final String ward;
  final String badge;
  final int missionsCompleted;
  final int verificationAccuracy;
  final double? latitude;
  final double? longitude;
}

import 'dart:math' as math;

import '../../models/green_champion_report.dart';
import '../../services/green_champion_data_source.dart';
import '../../services/green_champion_module_models.dart';
import '../../services/green_champion_module_provider.dart';
import '../../widgets/green_champion_ui.dart';
import 'package:flutter/material.dart';

class GreenChampionHomeScreen extends StatefulWidget {
  const GreenChampionHomeScreen({super.key});

  @override
  State<GreenChampionHomeScreen> createState() => _GreenChampionHomeScreenState();
}

class _GreenChampionHomeScreenState extends State<GreenChampionHomeScreen> {
  final GreenChampionDataSource _repository = GreenChampionModuleProvider.instance;

  late Future<_HomeData> _homeFuture;

  @override
  void initState() {
    super.initState();
    _homeFuture = _loadHomeData();
  }

  Future<_HomeData> _loadHomeData({bool forceRefresh = false}) async {
    final List<dynamic> results = await Future.wait<dynamic>([
      _repository.getDashboardStats(forceRefresh: forceRefresh),
      _repository.getReports(forceRefresh: forceRefresh),
      _repository.getRecentReports(limit: 3, forceRefresh: forceRefresh),
    ]);

    final DashboardStats stats = results[0] as DashboardStats;
    final ReportsBundle bundle = results[1] as ReportsBundle;
    final List<GreenChampionReport> recentReports =
        results[2] as List<GreenChampionReport>;

    final List<GreenChampionReport> allReports = <GreenChampionReport>[
      ...bundle.pending,
      ...bundle.verified,
    ];

    return _HomeData(
      stats: stats,
      allReports: allReports,
      recentReports: recentReports,
    );
  }

  Future<void> _refresh() async {
    final Future<_HomeData> next = _loadHomeData(forceRefresh: true);
    setState(() {
      _homeFuture = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_HomeData>(
        future: _homeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                Text(
                  'Failed to load dashboard: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            );
          }

          final _HomeData home = snapshot.data ??
              const _HomeData(
                stats: DashboardStats(
                  verifiedCount: 0,
                  pendingCount: 0,
                  points: 0,
                ),
                allReports: <GreenChampionReport>[],
                recentReports: <GreenChampionReport>[],
              );

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _buildHero(home),
              const SizedBox(height: 16),
              GreenChampionUi.sectionTitle(
                'Analytics Snapshot',
                subtitle: 'Live KPIs from visible moderation workload',
              ),
              const SizedBox(height: 12),
              _buildKpiGrid(home),
              const SizedBox(height: 14),
              _buildPerformanceCard(home),
              const SizedBox(height: 14),
              _buildCategoryAnalyticsCard(home),
              const SizedBox(height: 10),
              GreenChampionUi.sectionTitle(
                'Recent Reports',
                subtitle: 'Latest activity requiring attention',
              ),
              const SizedBox(height: 10),
              if (home.recentReports.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No recent reports found.'),
                  ),
                ),
              for (final GreenChampionReport report in home.recentReports)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: report.isVerified
                          ? GreenChampionUi.verified.withValues(alpha: 0.14)
                          : GreenChampionUi.pending.withValues(alpha: 0.14),
                      child: Icon(
                        report.isVerified ? Icons.verified : Icons.pending_actions,
                        color: report.isVerified
                            ? GreenChampionUi.verified
                            : GreenChampionUi.pending,
                      ),
                    ),
                    title: Text(report.category),
                    subtitle: Text(
                      report.notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      report.status.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: report.isVerified
                            ? GreenChampionUi.verified
                            : GreenChampionUi.pending,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              GreenChampionUi.sectionTitle(
                'Operational Insights',
                subtitle: 'Recommended focus based on current analytics',
              ),
              const SizedBox(height: 10),
              _buildInsightsCard(home),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHero(_HomeData home) {
    return Container(
      decoration: GreenChampionUi.heroDecoration,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Green Champion Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Verification Rate: ${home.verificationRateLabel}  •  Throughput Index: ${home.throughputIndex}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _heroMetric('Queue', '${home.stats.pendingCount}'),
              const SizedBox(width: 8),
              _heroMetric('Reviewed', '${home.stats.verifiedCount}'),
              const SizedBox(width: 8),
              _heroMetric('Points', '${home.stats.points}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid(_HomeData home) {
    final List<_KpiItem> items = [
      _KpiItem(
        title: 'Pending Reviews',
        value: '${home.stats.pendingCount}',
        icon: Icons.pending_actions_rounded,
        color: GreenChampionUi.pending,
      ),
      _KpiItem(
        title: 'Verified Reports',
        value: '${home.stats.verifiedCount}',
        icon: Icons.verified_rounded,
        color: GreenChampionUi.verified,
      ),
      _KpiItem(
        title: 'Total Active',
        value: '${home.totalActiveReports}',
        icon: Icons.analytics_outlined,
        color: const Color(0xFF246BFD),
      ),
      _KpiItem(
        title: 'Points / Verify',
        value: home.pointsPerVerifiedLabel,
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFF7355D4),
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map(_kpiCard).toList(growable: false),
    );
  }

  Widget _kpiCard(_KpiItem item) {
    final double width = (MediaQuery.of(context).size.width - 42) / 2;
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE4DD)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  style: const TextStyle(
                    color: Color(0xFF26353F),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Color(0xFF73808B),
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
  }

  Widget _buildPerformanceCard(_HomeData home) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verification Performance',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF2A3A45),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: home.verificationRate,
              minHeight: 8,
              borderRadius: BorderRadius.circular(12),
              backgroundColor: const Color(0xFFE4EAE5),
              color: GreenChampionUi.verified,
            ),
            const SizedBox(height: 8),
            Text(
              'Verified ${home.stats.verifiedCount} of ${home.totalActiveReports} active reports',
              style: const TextStyle(
                color: Color(0xFF6F7D88),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryAnalyticsCard(_HomeData home) {
    if (home.categoryBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final int maxCount = home.categoryBreakdown.values.fold<int>(0, math.max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category Distribution',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF2A3A45),
              ),
            ),
            const SizedBox(height: 10),
            ...home.categoryBreakdown.entries.map((entry) {
              final double ratio = maxCount == 0 ? 0 : entry.value / maxCount;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              color: Color(0xFF2F3E49),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: const TextStyle(
                            color: Color(0xFF697781),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(10),
                      color: GreenChampionUi.primary,
                      backgroundColor: const Color(0xFFE8EDE8),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsCard(_HomeData home) {
    final List<String> dynamicInsights = [
      if (home.stats.pendingCount > home.stats.verifiedCount)
        'Pending queue is higher than verified throughput. Prioritize fast validations.',
      if (home.topCategory != null)
        'Highest activity category is ${home.topCategory}. Focus moderation checks there first.',
      if (home.verificationRate < 0.5)
        'Verification rate is below 50%. Consider clearing low-risk pending reports in batches.',
      if (home.stats.pendingCount <= home.stats.verifiedCount)
        'Great pace maintained. Keep queue healthy by validating newly added reports quickly.',
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: dynamicInsights.map((text) => _ChecklistItem(text)).toList(),
        ),
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.stats,
    required this.allReports,
    required this.recentReports,
  });

  final DashboardStats stats;
  final List<GreenChampionReport> allReports;
  final List<GreenChampionReport> recentReports;

  int get totalActiveReports => stats.pendingCount + stats.verifiedCount;

  double get verificationRate {
    final int total = totalActiveReports;
    if (total == 0) {
      return 0;
    }
    return stats.verifiedCount / total;
  }

  String get verificationRateLabel => '${(verificationRate * 100).toStringAsFixed(0)}%';

  num get throughputIndex =>
      (stats.verifiedCount * 3) + math.max(stats.points ~/ 5, 0) - stats.pendingCount;

  String get pointsPerVerifiedLabel {
    if (stats.verifiedCount <= 0) {
      return '0';
    }
    return (stats.points / stats.verifiedCount).toStringAsFixed(1);
  }

  Map<String, int> get categoryBreakdown {
    final Map<String, int> map = <String, int>{};
    for (final GreenChampionReport report in allReports) {
      final String key = report.category.trim().isEmpty ? 'Unknown' : report.category.trim();
      map[key] = (map[key] ?? 0) + 1;
    }

    final List<MapEntry<String, int>> sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map<String, int>.fromEntries(sorted.take(4));
  }

  String? get topCategory => categoryBreakdown.isEmpty ? null : categoryBreakdown.keys.first;
}

class _KpiItem {
  const _KpiItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF2E7D32),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                height: 1.3,
                color: Color(0xFF2B3B2D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

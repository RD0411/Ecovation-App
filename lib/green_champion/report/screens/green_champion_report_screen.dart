import 'dart:convert';
import 'dart:typed_data';

import '../../models/green_champion_report.dart';
import '../../services/green_champion_data_source.dart';
import '../../services/green_champion_module_models.dart';
import '../../services/green_champion_module_provider.dart';
import '../../widgets/green_champion_ui.dart';
import 'green_champion_report_details_screen.dart';
import 'package:flutter/material.dart';

class GreenChampionReportScreen extends StatefulWidget {
  const GreenChampionReportScreen({super.key});

  @override
  State<GreenChampionReportScreen> createState() => _GreenChampionReportScreenState();
}

class _GreenChampionReportScreenState extends State<GreenChampionReportScreen> {
  final GreenChampionDataSource _repository = GreenChampionModuleProvider.instance;

  late Future<ReportsBundle> _reportsFuture;
  final TextEditingController _searchController = TextEditingController();
  bool _showPending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _reportsFuture = _repository.getReports();
  }

  Future<void> _refresh() async {
    final Future<ReportsBundle> next = _repository.getReports(forceRefresh: true);
    setState(() {
      _reportsFuture = next;
    });
    await next;
  }

  Future<void> _updateStatus(
    GreenChampionReport report,
    bool verify,
  ) async {
    try {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(verify ? 'Verify Report?' : 'Reject Report?'),
          content: Text(
            verify
                ? 'This report will move to verified list and points will be awarded.'
                : 'This report will be marked rejected and removed from pending list.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: verify
                    ? GreenChampionUi.verified
                    : const Color(0xFFC62828),
              ),
              child: Text(verify ? 'Verify' : 'Reject'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }

      if (verify) {
        await _repository.verifyReport(report);
      } else {
        await _repository.rejectReport(report);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verify
                ? 'Report verified and points awarded.'
                : 'Report rejected successfully.',
          ),
        ),
      );

      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $error')),
      );
    }
  }

  Future<void> _openReportDetails(
    GreenChampionReport report,
    bool canModerate,
  ) async {
    final String? action = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => GreenChampionReportDetailsScreen(
          report: report,
          canModerate: canModerate,
        ),
      ),
    );

    if (action == 'verify') {
      await _updateStatus(report, true);
      return;
    }

    if (action == 'reject') {
      await _updateStatus(report, false);
    }
  }

  Widget _reportImage(
    GreenChampionReport report, {
    double height = 84,
  }) {
    final Uint8List? bytes = _extractImageBytes(report);
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _placeholderImage(height);
          },
        ),
      );
    }

    if (report.photoUrl != null && report.photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          report.photoUrl!,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _placeholderImage(height),
        ),
      );
    }

    return _placeholderImage(height);
  }

  Uint8List? _extractImageBytes(GreenChampionReport report) {
    final String? explicitBase64 = report.photoBase64?.trim();
    if (explicitBase64 != null && explicitBase64.isNotEmpty) {
      final Uint8List? decoded = _tryDecodeBase64(explicitBase64);
      if (decoded != null) {
        return decoded;
      }
    }

    final String? imageUrl = report.photoUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    if (imageUrl.startsWith('data:image')) {
      final int commaIndex = imageUrl.indexOf(',');
      if (commaIndex > -1 && commaIndex < imageUrl.length - 1) {
        return _tryDecodeBase64(imageUrl.substring(commaIndex + 1));
      }
      return null;
    }

    final bool isNetworkUrl = imageUrl.startsWith('http://') ||
        imageUrl.startsWith('https://');
    if (isNetworkUrl) {
      return null;
    }

    final bool looksLikeBase64 =
        RegExp(r'^[A-Za-z0-9+/=\r\n]+$').hasMatch(imageUrl) &&
        imageUrl.length >= 80;
    if (!looksLikeBase64) {
      return null;
    }

    return _tryDecodeBase64(imageUrl);
  }

  Uint8List? _tryDecodeBase64(String raw) {
    try {
      final String normalized = base64.normalize(raw.replaceAll('\n', '').replaceAll('\r', ''));
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  Widget _placeholderImage(double height) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(38),
          ),
          onPressed: onTap,
          child: Text(label),
        ),
      ),
    );
  }

  Widget _reportCard(
    GreenChampionReport report, {
    required bool showActions,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: _reportImage(report),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.category,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.status.toUpperCase(),
                        style: TextStyle(
                          color: report.isVerified
                              ? GreenChampionUi.verified
                              : GreenChampionUi.pending,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'User: ${_reporterName(report)}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _actionButton(
                  label: 'View',
                  color: const Color(0xFF1E66D0),
                  onTap: () => _openReportDetails(report, showActions),
                ),
                if (showActions)
                  _actionButton(
                    label: 'Verify',
                    color: GreenChampionUi.verified,
                    onTap: () => _updateStatus(report, true),
                  ),
                if (showActions)
                  _actionButton(
                    label: 'Reject',
                    color: const Color(0xFFC62828),
                    onTap: () => _updateStatus(report, false),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ReportsBundle>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Failed to load reports: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            );
          }

          final ReportsBundle bundle = snapshot.data ??
              const ReportsBundle(
                pending: <GreenChampionReport>[],
                verified: <GreenChampionReport>[],
              );

            final List<GreenChampionReport> baseList =
              _showPending ? bundle.pending : bundle.verified;
            final String query = _searchController.text.trim().toLowerCase();
            final List<GreenChampionReport> activeList = query.isEmpty
              ? baseList
              : baseList.where((GreenChampionReport report) {
                return report.category.toLowerCase().contains(query) ||
                  report.notes.toLowerCase().contains(query) ||
                  _reporterName(report).toLowerCase().contains(query);
              }).toList(growable: false);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: <Widget>[
              // Container(
              //   decoration: GreenChampionUi.heroDecoration,
              //   padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: <Widget>[
              //       const Text(
              //         'Reports Moderation',
              //         style: TextStyle(
              //           color: Colors.white,
              //           fontSize: 24,
              //           fontWeight: FontWeight.w800,
              //         ),
              //       ),
              //       const SizedBox(height: 8),
              //       Text(
              //         'Pending: ${bundle.pending.length}   •   Verified: ${bundle.verified.length}',
              //         style: const TextStyle(color: Colors.white, fontSize: 14),
              //       ),
              //     ],
              //   ),
              // ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ChoiceChip(
                      label: Text('Pending (${bundle.pending.length})'),
                      selected: _showPending,
                      onSelected: (_) => setState(() => _showPending = true),
                      selectedColor: const Color(0xFFF8E5B8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Text('Verified (${bundle.verified.length})'),
                      selected: !_showPending,
                      onSelected: (_) => setState(() => _showPending = false),
                      selectedColor: const Color(0xFFCEEED1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by category, notes, or user name',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GreenChampionUi.sectionTitle(
                _showPending ? 'Pending Reports' : 'Verified Reports',
                subtitle: _showPending
                    ? 'Review and take action'
                    : 'Successfully approved reports',
              ),
              const SizedBox(height: 8),
              if (activeList.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('No reports available in this section.'),
                  ),
                ),
              for (final GreenChampionReport report in activeList)
                _reportCard(report, showActions: _showPending),
            ],
          );
        },
      ),
    );
  }

  String _reporterName(GreenChampionReport report) {
    final String name = (report.userName ?? '').trim();
    if (name.isNotEmpty) {
      return name;
    }
    return 'Unknown Citizen';
  }
}

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:citizen_impetus/common/models/report.dart';
import 'package:citizen_impetus/waste_worker/assigned/services/waste_worker_assigned_service.dart';

class WasteWorkerAssignedScreen extends StatefulWidget {
  const WasteWorkerAssignedScreen({
    super.key,
    this.onViewAssignedRoute,
  });

  final VoidCallback? onViewAssignedRoute;

  @override
  State<WasteWorkerAssignedScreen> createState() =>
      _WasteWorkerAssignedScreenState();
}

class _WasteWorkerAssignedScreenState extends State<WasteWorkerAssignedScreen> {
  final WasteWorkerAssignedService _service = WasteWorkerAssignedService();

  List<Report> _reports = <Report>[];
  WorkerAssignedRouteInfo? _routeInfo;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isRefreshingLocation = false;
  String _activeFilter = 'all';
  String _searchQuery = '';
  final Set<String> _busyReports = <String>{};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final WorkerAssignedData data =
          await _service.getAssignedData(forceRefresh: forceRefresh);
      _reports = data.reports;
      _routeInfo = data.routeInfo;
      _getCurrentLocation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading reports: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_isRefreshingLocation) return;

    setState(() {
      _isRefreshingLocation = true;
    });

    try {
      final PermissionStatus status = await Permission.location.request();
      if (!status.isGranted) {
        return;
      }

      final Position position = await Geolocator.getCurrentPosition();
      if (!mounted) {
        return;
      }
      setState(() {
        _currentPosition = position;
      });
    } catch (_) {
      // Ignore location failure and allow manual completion.
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingLocation = false;
        });
      }
    }
  }

  double? _distanceInMeters(Report report) {
    if (_currentPosition == null || report.lat == null || report.lng == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      report.lat!,
      report.lng!,
    );
  }

  bool _isWithinRange(Report report) {
    final double? distance = _distanceInMeters(report);
    if (distance == null) {
      return true;
    }
    return distance <= 150;
  }

  Future<void> _startReport(Report report) async {
    if (_routeInfo == null) {
      return;
    }
    if (_busyReports.contains(report.id)) {
      return;
    }

    setState(() {
      _busyReports.add(report.id);
    });

    try {
      await _service.markReportInProgress(report.id, _routeInfo!.assignmentId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report started. Status moved to in progress.')),
      );
      await _loadData(forceRefresh: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start report: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyReports.remove(report.id);
        });
      }
    }
  }

  Future<void> _completeWithQr(Report report) async {
    if (_routeInfo == null) {
      return;
    }
    if (_busyReports.contains(report.id)) {
      return;
    }
    if (!_isWithinRange(report)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Move closer to report location to complete.')),
      );
      return;
    }

    final String? qrToken = await _showQrValidationDialog(report);
    if (qrToken == null || qrToken.trim().isEmpty) {
      return;
    }

    setState(() {
      _busyReports.add(report.id);
    });

    try {
      await _service.markReportCompleted(
        reportId: report.id,
        assignmentId: _routeInfo!.assignmentId,
        qrToken: qrToken,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report marked completed successfully.')),
      );
      await _loadData(forceRefresh: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to complete report: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyReports.remove(report.id);
        });
      }
    }
  }

  Future<String?> _showQrValidationDialog(Report report) async {
    final TextEditingController controller = TextEditingController();

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('QR Validation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan and enter token to complete this report.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Center(
                child: QrImageView(
                  data: report.id,
                  version: QrVersions.auto,
                  size: 160,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Scanned token',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                controller.text = report.id;
              },
              child: const Text('Simulate'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  List<Report> get _filteredReports {
    final String query = _searchQuery.trim().toLowerCase();

    return _reports.where((Report report) {
      if (_activeFilter != 'all' && report.status.toLowerCase() != _activeFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final String text = '${report.category} ${report.notes ?? ''} ${report.address ?? ''}'
          .toLowerCase();
      return text.contains(query);
    }).toList();
  }

  int _countByStatus(String status) {
    return _reports.where((Report report) => report.status.toLowerCase() == status).length;
  }

  String _formatWhen(DateTime? time) {
    if (time == null) {
      return 'Unknown time';
    }
    final DateTime local = time.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'assigned':
        return const Color(0xFFE67E22);
      case 'in_progress':
        return const Color(0xFF2D9CDB);
      case 'completed':
        return const Color(0xFF27AE60);
      default:
        return const Color(0xFF7F8C8D);
    }
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool selected = _activeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _activeFilter = value;
          });
        },
      ),
    );
  }

  Widget _buildRouteSummaryCard() {
    if (_routeInfo == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'No active route assignment found. Pull to refresh after assignment.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E8C62), Color(0xFF20A174)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _routeInfo!.routeName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start: ${_routeInfo!.startLocation}',
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            'End: ${_routeInfo!.endLocation}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Frequency: ${_routeInfo!.frequency}  |  Time: ${_routeInfo!.scheduledTime}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onViewAssignedRoute,
              icon: const Icon(Icons.visibility),
              label: const Text('View On Dashboard'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Report report) {
    final String status = report.status.toLowerCase();
    final bool canStart = status == 'assigned' || status == 'pending';
    final bool canComplete = status == 'in_progress';
    final bool isBusy = _busyReports.contains(report.id);
    final double? distance = _distanceInMeters(report);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.category,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(report.notes ?? 'No description available.'),
            const SizedBox(height: 8),
            Text(
              report.address ?? 'Location address not available.',
              style: const TextStyle(color: Color(0xFF5D6D7E), fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              'Created: ${_formatWhen(report.createdAt)}',
              style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 12),
            ),
            if (distance != null) ...[
              const SizedBox(height: 6),
              Text(
                'Distance: ${distance.toStringAsFixed(0)} m',
                style: TextStyle(
                  fontSize: 12,
                  color: _isWithinRange(report)
                      ? const Color(0xFF1E8449)
                      : const Color(0xFFC0392B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (canStart)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isBusy ? null : () => _startReport(report),
                      icon: isBusy
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: const Text('Start Job'),
                    ),
                  ),
                if (canStart && canComplete) const SizedBox(width: 10),
                if (canComplete)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isBusy ? null : () => _completeWithQr(report),
                      icon: isBusy
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.qr_code_scanner),
                      label: const Text('Complete'),
                    ),
                  ),
                if (!canStart && !canComplete)
                  const Expanded(
                    child: Text(
                      'Completed',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: Color(0xFF1E8449),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (canComplete && !_isWithinRange(report) && distance != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Get within 150 meters of location to complete this report.',
                  style: TextStyle(color: Color(0xFFC0392B), fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Report> visibleReports = _filteredReports;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Reports'),
        actions: [
          IconButton(
            icon: _isRefreshingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            onPressed: _isRefreshingLocation ? null : _getCurrentLocation,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadData(forceRefresh: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadData(forceRefresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                children: [
                  _buildRouteSummaryCard(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildKpiCard('Assigned', _reports.length.toString(), const Color(0xFF0E8C62)),
                      const SizedBox(width: 8),
                      _buildKpiCard('In Progress', _countByStatus('in_progress').toString(), const Color(0xFF2D9CDB)),
                      const SizedBox(width: 8),
                      _buildKpiCard('Done', _countByStatus('completed').toString(), const Color(0xFF27AE60)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by category, notes, or address',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (String value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all'),
                        _buildFilterChip('Assigned', 'assigned'),
                        _buildFilterChip('Pending', 'pending'),
                        _buildFilterChip('In Progress', 'in_progress'),
                        _buildFilterChip('Completed', 'completed'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (visibleReports.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('No reports found for current filter.'),
                    )
                  else
                    ...visibleReports.map(_buildReportCard),
                ],
              ),
            ),
    );
  }
}

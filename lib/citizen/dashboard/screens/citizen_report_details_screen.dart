import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_impetus/citizen/dashboard/services/citizen_dashboard_service.dart';
import 'package:flutter/material.dart';

class CitizenReportDetailsScreen extends StatefulWidget {
  const CitizenReportDetailsScreen({
    required this.reportId,
    super.key,
  });

  final String reportId;

  @override
  State<CitizenReportDetailsScreen> createState() => _CitizenReportDetailsScreenState();
}

class _CitizenReportDetailsScreenState extends State<CitizenReportDetailsScreen> {
  final CitizenDashboardService _service = CitizenDashboardService();

  CitizenReportDetails? _details;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
    });

    try {
      final CitizenReportDetails details = await _service.getReportDetails(widget.reportId);
      if (!mounted) {
        return;
      }
      setState(() {
        _details = details;
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final CitizenReportDetails? details = _details;
    if (details == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Report Details'),
          backgroundColor: const Color(0xFF2E9B45),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Unable to load report details.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        backgroundColor: const Color(0xFF2E9B45),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetails,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          children: [
            _buildHeader(details),
            const SizedBox(height: 12),
            _buildEvidenceCard(details),
            const SizedBox(height: 12),
            _buildInfoCard(details),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CitizenReportDetails details) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    details.category,
                    style: const TextStyle(
                      color: Color(0xFF263440),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                _statusChip(details.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Report ID: ${details.id}',
              style: const TextStyle(
                color: Color(0xFF72808A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceCard(CitizenReportDetails details) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Evidence Photo',
              style: TextStyle(
                color: Color(0xFF2C3945),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 210,
                width: double.infinity,
                child: _evidenceView(details.imageBase64),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _evidenceView(String imageBase64) {
    if (imageBase64.trim().isEmpty) {
      return Container(
        color: const Color(0xFFE8EDF0),
        alignment: Alignment.center,
        child: const Text(
          'No evidence image available',
          style: TextStyle(color: Color(0xFF6E7B86), fontWeight: FontWeight.w700),
        ),
      );
    }

    try {
      final Uint8List bytes = base64Decode(imageBase64);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } catch (_) {
      return Container(
        color: const Color(0xFFE8EDF0),
        alignment: Alignment.center,
        child: const Text(
          'Image preview unavailable',
          style: TextStyle(color: Color(0xFF6E7B86), fontWeight: FontWeight.w700),
        ),
      );
    }
  }

  Widget _buildInfoCard(CitizenReportDetails details) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Description', details.description.isEmpty ? '-' : details.description),
            const SizedBox(height: 10),
            _infoRow('Address', details.address),
            const SizedBox(height: 10),
            _infoRow(
              'Coordinates',
              '${details.latitude.toStringAsFixed(6)}, ${details.longitude.toStringAsFixed(6)}',
            ),
            const SizedBox(height: 10),
            _infoRow('Created At', details.createdAt),
            const SizedBox(height: 10),
            _infoRow('Updated At', details.updatedAt),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6F7D88),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF27333D),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'verified':
        color = const Color(0xFF2FA658);
        break;
      case 'rejected':
        color = const Color(0xFFCB3B3B);
        break;
      case 'completed':
        color = const Color(0xFF2F83D6);
        break;
      case 'assigned':
      case 'in progress':
        color = const Color(0xFFE08E2C);
        break;
      default:
        color = const Color(0xFF75808A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

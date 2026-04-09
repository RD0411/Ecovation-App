import 'dart:convert';
import 'dart:typed_data';

import '../../models/green_champion_report.dart';
import '../../widgets/green_champion_ui.dart';
import 'package:flutter/material.dart';

class GreenChampionReportDetailsScreen extends StatelessWidget {
  const GreenChampionReportDetailsScreen({
    required this.report,
    required this.canModerate,
    super.key,
  });

  final GreenChampionReport report;
  final bool canModerate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        backgroundColor: const Color(0xFF2E9B45),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 12),
          _buildEvidenceCard(),
          const SizedBox(height: 12),
          _buildReporterCard(),
          const SizedBox(height: 12),
          _buildLocationCard(),
          const SizedBox(height: 12),
          _buildNotesCard(),
        ],
      ),
      bottomNavigationBar: canModerate
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFC62828)),
                        foregroundColor: const Color(0xFFC62828),
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: () => Navigator.of(context).pop('reject'),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: GreenChampionUi.verified,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: () => Navigator.of(context).pop('verify'),
                      child: const Text('Verify'),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildHeaderCard() {
    final Color statusColor = report.isVerified
        ? GreenChampionUi.verified
        : report.isRejected
            ? const Color(0xFFC62828)
            : GreenChampionUi.pending;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Color(0xFF263541),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    report.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Report ID: ${report.id}',
              style: const TextStyle(
                color: Color(0xFF6E7C87),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Evidence Photo',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF2C3944),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: double.infinity,
                height: 210,
                child: _reportImage(height: 210),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReporterCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reported By',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF2C3944),
              ),
            ),
            const SizedBox(height: 8),
            _infoRow('Name', _reporterName()),
            if ((report.userEmail ?? '').trim().isNotEmpty)
              _infoRow('Email', report.userEmail!.trim()),
            if ((report.userPhone ?? '').trim().isNotEmpty)
              _infoRow('Phone', report.userPhone!.trim()),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final String locationText = report.lat != null && report.lng != null
        ? '${report.lat!.toStringAsFixed(6)}, ${report.lng!.toStringAsFixed(6)}'
        : 'Location not available';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF2C3944),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              locationText,
              style: const TextStyle(
                color: Color(0xFF5F6D78),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notes',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF2C3944),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              report.notes,
              style: const TextStyle(
                color: Color(0xFF5F6D78),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportImage({double height = 84}) {
    final Uint8List? bytes = _extractImageBytes();
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _placeholderImage(height);
        },
      );
    }

    if (report.photoUrl != null && report.photoUrl!.isNotEmpty) {
      return Image.network(
        report.photoUrl!,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholderImage(height),
      );
    }

    return _placeholderImage(height);
  }

  Uint8List? _extractImageBytes() {
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

    final bool isNetworkUrl = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    if (isNetworkUrl) {
      return null;
    }

    final bool looksLikeBase64 =
        RegExp(r'^[A-Za-z0-9+/=\r\n]+$').hasMatch(imageUrl) && imageUrl.length >= 80;
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

  String _reporterName() {
    final String name = (report.userName ?? '').trim();
    if (name.isNotEmpty) {
      return name;
    }
    return 'Unknown Citizen';
  }

  Widget _infoRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              key,
              style: const TextStyle(
                color: Color(0xFF6E7C87),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Text(':  '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF2B3A45),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

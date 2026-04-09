import 'dart:convert';

import 'package:citizen_impetus/Authentication/services/auth_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CitizenReportHistoryItem {
  const CitizenReportHistoryItem({
    required this.id,
    required this.category,
    required this.description,
    required this.status,
    required this.address,
    required this.createdLabel,
    required this.imageUrl,
    required this.location,
  });

  final String id;
  final String category;
  final String description;
  final String status;
  final String address;
  final String createdLabel;
  final String imageUrl;
  final LatLng location;
}

class CitizenReportBootstrap {
  const CitizenReportBootstrap({
    required this.defaultAddress,
    required this.defaultLocation,
    required this.categories,
    required this.recentReports,
  });

  final String defaultAddress;
  final LatLng defaultLocation;
  final List<String> categories;
  final List<CitizenReportHistoryItem> recentReports;
}

class CitizenReportPayload {
  const CitizenReportPayload({
    required this.category,
    required this.note,
    required this.location,
    required this.address,
    required this.imageBase64,
  });

  final String category;
  final String note;
  final LatLng location;
  final String address;
  final String imageBase64;
}

class CitizenReportService {
  CitizenReportService() : _client = Supabase.instance.client;

  final SupabaseClient _client;
  CitizenReportBootstrap? _cachedBootstrap;
  DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(seconds: 30);

  static const List<String> _defaultCategories = <String>[
    'Plastic Waste',
    'Wet Waste',
    'Dry Waste',
    'E-Waste',
    'Hazardous Waste',
    'Mixed Waste',
  ];

  // ---------- Report Form ----------

  Future<CitizenReportBootstrap> getReportBootstrap({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedBootstrap != null && _cachedAt != null) {
      final Duration age = DateTime.now().difference(_cachedAt!);
      if (age <= _cacheTtl) {
        return _cachedBootstrap!;
      }
    }

    final String userId = _requireUserId();

    final Future<Map<String, dynamic>?> citizenFuture = _client
        .from('citizens')
        .select('address, latitude, longitude')
        .eq('id', userId)
        .maybeSingle();

    final Future<List<CitizenReportHistoryItem>> reportsFuture = _fetchRecentReports(userId);

    final List<dynamic> parallelResults = await Future.wait<dynamic>([
      citizenFuture,
      reportsFuture,
    ]);

    final Map<String, dynamic>? citizen = parallelResults[0] as Map<String, dynamic>?;
    final List<CitizenReportHistoryItem> reports =
        parallelResults[1] as List<CitizenReportHistoryItem>;

    final double latitude = _toDouble(citizen?['latitude']) ?? 18.5204;
    final double longitude = _toDouble(citizen?['longitude']) ?? 73.8567;

    final CitizenReportBootstrap bootstrap = CitizenReportBootstrap(
      defaultAddress: citizen?['address']?.toString() ?? '',
      defaultLocation: LatLng(latitude, longitude),
      categories: _defaultCategories,
      recentReports: reports,
    );

    _cachedBootstrap = bootstrap;
    _cachedAt = DateTime.now();
    return bootstrap;
  }

  // ---------- Report Submission ----------

  Future<void> submitReport(CitizenReportPayload payload) async {
    final String userId = _requireUserId();

    if (payload.category.trim().isEmpty) {
      throw Exception('Please select a waste category.');
    }
    if (payload.imageBase64.trim().isEmpty) {
      throw Exception('Please add a report photo.');
    }

    // Validate base64 to avoid inserting malformed image values.
    try {
      base64Decode(payload.imageBase64);
    } catch (_) {
      throw Exception('Invalid image data. Please capture/select photo again.');
    }

    await _client.from('waste_reports').insert({
      'citizen_id': userId,
      'category': payload.category.trim(),
      'description': payload.note.trim(),
      'image_url': payload.imageBase64,
      'latitude': payload.location.latitude,
      'longitude': payload.location.longitude,
      'address': payload.address.trim(),
      'status': 'pending',
    });
  }

  Future<List<CitizenReportHistoryItem>> _fetchRecentReports(String userId) async {
    final List<dynamic> rows = await _client
        .from('waste_reports')
        .select('id, category, description, status, address, image_url, latitude, longitude, created_at')
        .eq('citizen_id', userId)
        .order('created_at', ascending: false)
        .limit(10);

    return rows.map((row) {
      final Map<String, dynamic> data = row as Map<String, dynamic>;
      return CitizenReportHistoryItem(
        id: data['id']?.toString() ?? '',
        category: data['category']?.toString() ?? 'Waste Report',
        description: data['description']?.toString() ?? '',
        status: _prettyStatus(data['status']?.toString()),
        address: data['address']?.toString() ?? '',
        createdLabel: _formatTimestamp(data['created_at']?.toString()),
        imageUrl: data['image_url']?.toString() ?? '',
        location: LatLng(
          _toDouble(data['latitude']) ?? 0,
          _toDouble(data['longitude']) ?? 0,
        ),
      );
    }).toList();
  }

  String _prettyStatus(String? raw) {
    switch (raw) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  String _formatTimestamp(String? iso) {
    if (iso == null) {
      return 'Unknown time';
    }

    final DateTime? parsed = DateTime.tryParse(iso)?.toLocal();
    if (parsed == null) {
      return 'Unknown time';
    }

    final List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final int hour12 = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final String minute = parsed.minute.toString().padLeft(2, '0');
    final String amPm = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${parsed.day} ${months[parsed.month - 1]}, $hour12:$minute $amPm';
  }

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  String _requireUserId() {
    final String? userId = AuthService.currentUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('User session not found. Please login again.');
    }
    return userId;
  }
}

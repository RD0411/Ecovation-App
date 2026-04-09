import 'package:citizen_impetus/Authentication/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WasteWorkerProfileData {
  const WasteWorkerProfileData({
    required this.name,
    required this.email,
    required this.phone,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.status,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.assignedRoutes,
    required this.activeRoutes,
    required this.completedRoutes,
    required this.trainingModules,
    required this.safetyScore,
  });

  final String name;
  final String email;
  final String phone;
  final String vehicleNumber;
  final String vehicleType;
  final String status;
  final String address;
  final double? latitude;
  final double? longitude;
  final int assignedRoutes;
  final int activeRoutes;
  final int completedRoutes;
  final int trainingModules;
  final int safetyScore;
}

class WasteWorkerProfileUpdatePayload {
  const WasteWorkerProfileUpdatePayload({
    required this.phone,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.status,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String phone;
  final String vehicleNumber;
  final String vehicleType;
  final String status;
  final String address;
  final double? latitude;
  final double? longitude;
}

class WasteWorkerProfileService {
  WasteWorkerProfileService() : _client = Supabase.instance.client;

  final SupabaseClient _client;
  static const Duration _cacheTtl = Duration(seconds: 45);
  WasteWorkerProfileData? _cachedData;
  DateTime? _cachedAt;
  Future<WasteWorkerProfileData>? _inFlight;

  Future<WasteWorkerProfileData> getProfileData({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedData != null && _cachedAt != null) {
      if (DateTime.now().difference(_cachedAt!) <= _cacheTtl) {
        return _cachedData!;
      }
    }

    if (!forceRefresh && _inFlight != null) {
      return _inFlight!;
    }

    final Future<WasteWorkerProfileData> inFlight = _loadProfileData();
    _inFlight = inFlight;
    try {
      final WasteWorkerProfileData data = await inFlight;
      _cachedData = data;
      _cachedAt = DateTime.now();
      return data;
    } finally {
      _inFlight = null;
    }
  }

  Future<WasteWorkerProfileData> _loadProfileData() async {
    final String userId = _requireUserId();

    final List<dynamic> results = await Future.wait<dynamic>([
      _client
          .from('workers')
          .select(
            'full_name, email, phone, vehicle_number, vehicle_type, status, address, latitude, longitude',
          )
          .eq('id', userId)
          .maybeSingle(),
      _client.from('route_assignments').select('status').eq('worker_id', userId),
      _client.from('training_courses').select('id').limit(200),
    ]);

    final Map<String, dynamic>? worker = results[0] as Map<String, dynamic>?;

    if (worker == null) {
      throw Exception('Worker profile not found.');
    }

    final List<dynamic> assignments = results[1] as List<dynamic>;

    int assignedRoutes = 0;
    int activeRoutes = 0;
    int completedRoutes = 0;

    for (final dynamic row in assignments) {
      final Map<String, dynamic> data = row as Map<String, dynamic>;
      final String status = (data['status']?.toString() ?? '').toLowerCase();
      if (status == 'assigned') {
        assignedRoutes++;
      } else if (status == 'active') {
        activeRoutes++;
      } else if (status == 'completed') {
        completedRoutes++;
      }
    }

    final List<dynamic> trainings = results[2] as List<dynamic>;

    final int safetyScore = _calculateSafetyScore(
      assignedRoutes: assignedRoutes,
      activeRoutes: activeRoutes,
      completedRoutes: completedRoutes,
    );

    return WasteWorkerProfileData(
      name: worker['full_name']?.toString() ?? 'Waste Worker',
      email: worker['email']?.toString() ?? '',
      phone: worker['phone']?.toString() ?? '',
      vehicleNumber: worker['vehicle_number']?.toString() ?? '',
      vehicleType: worker['vehicle_type']?.toString() ?? '',
      status: worker['status']?.toString() ?? 'available',
      address: worker['address']?.toString() ?? '',
      latitude: _toDouble(worker['latitude']),
      longitude: _toDouble(worker['longitude']),
      assignedRoutes: assignedRoutes,
      activeRoutes: activeRoutes,
      completedRoutes: completedRoutes,
      trainingModules: trainings.length,
      safetyScore: safetyScore,
    );
  }

  Future<void> saveProfile(WasteWorkerProfileUpdatePayload payload) async {
    final String userId = _requireUserId();
    if (payload.status != 'available' &&
        payload.status != 'busy' &&
        payload.status != 'offline') {
      throw Exception('Invalid availability status.');
    }

    await _client.from('workers').update({
      'phone': payload.phone.trim(),
      'vehicle_number': payload.vehicleNumber.trim(),
      'vehicle_type': payload.vehicleType.trim(),
      'status': payload.status,
      'address': payload.address.trim(),
      'latitude': payload.latitude,
      'longitude': payload.longitude,
    }).eq('id', userId);

    _cachedData = null;
    _cachedAt = null;
    _inFlight = null;
  }

  int _calculateSafetyScore({
    required int assignedRoutes,
    required int activeRoutes,
    required int completedRoutes,
  }) {
    int score = 78;
    score += (completedRoutes * 3);
    score += (assignedRoutes * 1);
    score -= (activeRoutes * 2);
    if (score < 45) {
      return 45;
    }
    if (score > 99) {
      return 99;
    }
    return score;
  }

  String _requireUserId() {
    final String? userId = AuthService.currentUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('User session not found. Please login again.');
    }
    return userId;
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
}

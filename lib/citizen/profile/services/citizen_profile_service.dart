import 'package:citizen_impetus/Authentication/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CitizenProfileTask {
  const CitizenProfileTask({
    required this.title,
    required this.done,
  });

  final String title;
  final bool done;
}

class CitizenProfileData {
  const CitizenProfileData({
    required this.name,
    required this.email,
    required this.points,
    required this.phone,
    required this.address,
    required this.age,
    required this.gender,
    required this.tasks,
  });

  final String name;
  final String email;
  final int points;
  final String phone;
  final String address;
  final String age;
  final String gender;
  final List<CitizenProfileTask> tasks;
}

class CitizenProfileUpdatePayload {
  const CitizenProfileUpdatePayload({
    required this.phone,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.age,
    required this.gender,
  });

  final String phone;
  final String address;
  final double? latitude;
  final double? longitude;
  final String age;
  final String gender;
}

class CitizenProfileService {
  CitizenProfileService()
      : _client = Supabase.instance.client;

  final SupabaseClient _client;
  CitizenProfileData? _cachedData;
  DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(seconds: 45);

  // ---------- Profile ----------

  Future<CitizenProfileData> getProfileData({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedData != null && _cachedAt != null) {
      final Duration age = DateTime.now().difference(_cachedAt!);
      if (age <= _cacheTtl) {
        return _cachedData!;
      }
    }

    final String userId = _requireUserId();

    final Future<Map<String, dynamic>?> citizenFuture = _client
        .from('citizens')
        .select('full_name, email, phone, address, age, gender, green_coins')
        .eq('id', userId)
        .maybeSingle();

    final Future<List<dynamic>> trainingRowsFuture =
        _client.from('training_courses').select('id').limit(1);
    final Future<List<dynamic>> distributionRowsFuture =
        _client.from('inventory_items').select('id').limit(1);
    final Future<List<dynamic>> eventRowsFuture = _client
        .from('events')
        .select('id')
        .inFilter('status', <String>['upcoming', 'ongoing'])
        .limit(1);

    final List<dynamic> parallelResults = await Future.wait<dynamic>([
      citizenFuture,
      trainingRowsFuture,
      distributionRowsFuture,
      eventRowsFuture,
    ]);

    final Map<String, dynamic>? citizen = parallelResults[0] as Map<String, dynamic>?;
    final List<dynamic> trainingRows = parallelResults[1] as List<dynamic>;
    final List<dynamic> distributionRows = parallelResults[2] as List<dynamic>;
    final List<dynamic> eventRows = parallelResults[3] as List<dynamic>;

    final CitizenProfileData data = CitizenProfileData(
      name: citizen?['full_name']?.toString() ?? 'Citizen User',
      email: citizen?['email']?.toString() ?? (AuthService.currentUser?.email ?? ''),
      points: (citizen?['green_coins'] as int?) ?? 0,
      phone: citizen?['phone']?.toString() ?? '',
      address: citizen?['address']?.toString() ?? '',
      age: citizen?['age']?.toString() ?? '',
      gender: citizen?['gender']?.toString() ?? '',
      tasks: <CitizenProfileTask>[
        CitizenProfileTask(title: 'Training', done: trainingRows.isNotEmpty),
        CitizenProfileTask(title: 'Distribution', done: distributionRows.isNotEmpty),
        CitizenProfileTask(title: 'Community Events', done: eventRows.isNotEmpty),
      ],
    );

    _cachedData = data;
    _cachedAt = DateTime.now();
    return data;
  }

  // ---------- Save Profile ----------

  Future<void> saveProfile(CitizenProfileUpdatePayload payload) async {
    final String userId = _requireUserId();

    if (payload.phone.trim().isEmpty) {
      throw Exception('Phone number is required.');
    }

    await _client.from('citizens').update({
      'phone': payload.phone.trim(),
      'address': payload.address.trim(),
      'latitude': payload.latitude,
      'longitude': payload.longitude,
      'age': int.tryParse(payload.age.trim()),
      'gender': payload.gender.trim(),
    }).eq('id', userId);

    _cachedData = null;
    _cachedAt = null;
  }

  String _requireUserId() {
    final String? userId = AuthService.currentUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('User session not found. Please login again.');
    }
    return userId;
  }
}

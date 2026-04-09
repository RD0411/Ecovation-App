import 'package:citizen_impetus/Authentication/models/app_role.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AppAuthUser {
  const AppAuthUser({
    required this.id,
    required this.role,
    required this.email,
    required this.fullName,
  });

  final String id;
  final AppRole role;
  final String email;
  final String fullName;
}

class AuthService {
  AuthService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const Uuid _uuid = Uuid();

  static const String _roleKey = 'app_role';
  static const String _idKey = 'app_user_id';
  static const String _emailKey = 'app_email';
  static const String _nameKey = 'app_full_name';

  static AppAuthUser? _currentUser;

  static AppAuthUser? get currentUser => _currentUser;

  static String? get currentUserId => _currentUser?.id;

  static AppRole? get currentRole => _currentUser?.role;

  static String _tableForRole(AppRole role) {
    switch (role) {
      case AppRole.citizen:
        return 'citizens';
      case AppRole.wasteWorker:
        return 'workers';
      case AppRole.greenChampion:
        return 'green_champions';
    }
  }

  static Future<AppAuthUser?> restoreSession() async {
    if (_currentUser != null) {
      return _currentUser;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? roleValue = prefs.getString(_roleKey);
    final String? id = prefs.getString(_idKey);
    final String? email = prefs.getString(_emailKey);
    final String? fullName = prefs.getString(_nameKey);

    final AppRole? role = AppRoleX.fromValue(roleValue);
    if (role == null || id == null || email == null || fullName == null) {
      return null;
    }

    _currentUser = AppAuthUser(
      id: id,
      role: role,
      email: email,
      fullName: fullName,
    );

    return _currentUser;
  }

  static Future<AppAuthUser> signIn({
    required String email,
    required String password,
    required AppRole role,
  }) async {
    final String table = _tableForRole(role);

    final List<Map<String, dynamic>> rows = (await _client
            .from(table)
            .select('id, full_name, email, password')
            .eq('email', email)
            .eq('password', password)
            .limit(1) as List<dynamic>)
        .cast<Map<String, dynamic>>();

    if (rows.isEmpty) {
      throw Exception('Invalid credentials for selected role');
    }

    final Map<String, dynamic> row = rows.first;
    final String id = row['id']?.toString() ?? '';
    final String resolvedEmail = row['email']?.toString() ?? email;
    final String fullName = row['full_name']?.toString() ?? 'User';

    if (id.isEmpty) {
      throw Exception('User record is missing id');
    }

    final AppAuthUser user = AppAuthUser(
      id: id,
      role: role,
      email: resolvedEmail,
      fullName: fullName,
    );

    await _storeUser(user);
    return user;
  }

  static Future<AppAuthUser> signUp({
    required String fullName,
    required String email,
    required String password,
    required AppRole role,
  }) async {
    final String table = _tableForRole(role);
    final String generatedId = _uuid.v4();

    final List<Map<String, dynamic>> existing = (await _client
            .from(table)
            .select('id')
            .eq('email', email)
            .limit(1) as List<dynamic>)
        .cast<Map<String, dynamic>>();

    if (existing.isNotEmpty) {
      throw Exception('Email already registered for selected role');
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'id': generatedId,
      'full_name': fullName,
      'email': email,
      'password': password,
    };

    switch (role) {
      case AppRole.citizen:
        payload['green_coins'] = 0;
        break;
      case AppRole.wasteWorker:
        payload['status'] = 'available';
        break;
      case AppRole.greenChampion:
        payload['points'] = 0;
        break;
    }

    final List<Map<String, dynamic>> inserted = (await _client
            .from(table)
            .insert(payload)
            .select('id, full_name, email') as List<dynamic>)
        .cast<Map<String, dynamic>>();

    if (inserted.isEmpty) {
      throw Exception('Failed to create account');
    }

    final Map<String, dynamic> row = inserted.first;
    final String id = row['id']?.toString() ?? '';
    if (id.isEmpty) {
      throw Exception('Created user has no id');
    }

    final AppAuthUser user = AppAuthUser(
      id: id,
      role: role,
      email: row['email']?.toString() ?? email,
      fullName: row['full_name']?.toString() ?? fullName,
    );

    await _storeUser(user);
    return user;
  }

  static Future<void> signOut() async {
    _currentUser = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_idKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_nameKey);
  }

  static Future<void> _storeUser(AppAuthUser user) async {
    _currentUser = user;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, user.role.value);
    await prefs.setString(_idKey, user.id);
    await prefs.setString(_emailKey, user.email);
    await prefs.setString(_nameKey, user.fullName);
  }
}

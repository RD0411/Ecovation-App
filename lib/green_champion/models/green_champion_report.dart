class GreenChampionReport {
  const GreenChampionReport({
    required this.id,
    required this.category,
    required this.status,
    required this.userId,
    required this.notes,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.photoBase64,
    this.photoUrl,
    this.lat,
    this.lng,
  });

  final String id;
  final String category;
  final String status;
  final String userId;
  final String notes;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? photoBase64;
  final String? photoUrl;
  final double? lat;
  final double? lng;

  bool get isRejected => status.toLowerCase() == 'rejected';

  bool get isVerified => status.toLowerCase() == 'verified';

  bool get isPending => !isRejected && !isVerified;

  static GreenChampionReport fromJson(Map<String, dynamic> json) {
    return GreenChampionReport(
      id: _readString(json, ['id']) ?? '',
      category: _readString(json, ['category']) ?? 'Unknown',
      status: _readString(json, ['status']) ?? 'pending',
      userId: _readString(json, ['citizen_id', 'userId', 'user_id']) ?? '',
      notes: _readString(json, ['notes', 'description']) ?? 'No notes',
      userName: _readString(json, ['citizen_name', 'user_name', 'full_name', 'name']),
      userEmail: _readString(json, ['citizen_email', 'user_email', 'email']),
      userPhone: _readString(json, ['citizen_phone', 'user_phone', 'phone']),
      photoBase64: _readString(json, ['photoBase64', 'photo_base64']),
      photoUrl: _readString(json, ['image_url', 'photoUrl', 'photo_url']),
      lat: _readDouble(json, ['latitude', 'lat']),
      lng: _readDouble(json, ['longitude', 'lng', 'lon', 'long']),
    );
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value != null && value is! String) {
        final String parsed = value.toString().trim();
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
    }
    return null;
  }

  static double? _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final double? parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}

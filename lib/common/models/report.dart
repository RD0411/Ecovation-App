class Report {
  final String id;
  final String category;
  final String? notes;
  final String? address;
  final double? lat;
  final double? lng;
  final String status;
  final DateTime? createdAt;

  Report({
    required this.id,
    required this.category,
    this.notes,
    this.address,
    this.lat,
    this.lng,
    required this.status,
    this.createdAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Report',
      notes: json['description']?.toString(), // Map Supabase description -> notes
      address: json['address']?.toString(),
      lat: _parseDouble(json['latitude']),
      lng: _parseDouble(json['longitude']),
      status: json['status']?.toString() ?? 'pending',
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value.toString());
  }
}

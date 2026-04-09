import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CitizenDistributionItem {
  const CitizenDistributionItem({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.stock,
    required this.showReceiveButton,
    this.received = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final int stock;
  final bool showReceiveButton;
  final bool received;
  final DateTime? createdAt;

  bool get isAvailable => stock > 0;

  CitizenDistributionItem copyWith({bool? received}) {
    return CitizenDistributionItem(
      id: id,
      title: title,
      description: description,
      imageUrl: imageUrl,
      stock: stock,
      showReceiveButton: showReceiveButton,
      received: received ?? this.received,
      createdAt: createdAt,
    );
  }
}

class CitizenDistributionData {
  const CitizenDistributionData({
    required this.items,
  });

  final List<CitizenDistributionItem> items;
}

class CitizenDistributionService {
  CitizenDistributionService()
      : _client = Supabase.instance.client;

  static const String _receivedDistributionKey =
      'citizen_distribution_received_ids';

  final SupabaseClient _client;

  // ---------- Distribution ----------

  Future<CitizenDistributionData> getDistributionData() async {
    final Set<String> receivedIds = await _getReceivedIds();

    final List<dynamic> rows = await _client
        .from('inventory_items')
        .select('id, title, description, image_url, stock, created_at')
        .order('created_at', ascending: false);

    final List<CitizenDistributionItem> items = rows.map((row) {
      final Map<String, dynamic> data = row as Map<String, dynamic>;
      final String id = data['id']?.toString() ?? '';
      final int stock = _parseInt(data['stock']) ?? 0;
      return CitizenDistributionItem(
        id: id,
        title: data['title']?.toString() ?? 'Distribution Item',
        description: data['description']?.toString() ?? '',
        imageUrl: data['image_url']?.toString() ?? '',
        stock: stock,
        showReceiveButton: stock > 0,
        received: receivedIds.contains(id),
        createdAt: _parseDate(data['created_at']),
      );
    }).toList();

    return CitizenDistributionData(items: items);
  }

  Future<void> setItemReceived({
    required String itemId,
    required bool received,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Set<String> ids = await _getReceivedIds();

    if (received) {
      ids.add(itemId);
    } else {
      ids.remove(itemId);
    }

    await prefs.setStringList(_receivedDistributionKey, ids.toList(growable: false));
  }

  Future<Set<String>> _getReceivedIds() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_receivedDistributionKey) ?? <String>[]).toSet();
  }

  int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value.toString());
  }
}

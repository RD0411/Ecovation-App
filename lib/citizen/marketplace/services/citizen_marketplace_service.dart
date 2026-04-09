import 'dart:convert';

import 'package:citizen_impetus/Authentication/services/auth_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketplaceItem {
  const MarketplaceItem({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    required this.quantity,
    required this.description,
    required this.status,
    required this.createdLabel,
    required this.imageUrl,
    required this.sellerName,
    required this.isMine,
    required this.location,
  });

  final String id;
  final String title;
  final String category;
  final double price;
  final int quantity;
  final String description;
  final String status;
  final String createdLabel;
  final String imageUrl;
  final String sellerName;
  final bool isMine;
  final LatLng location;
}

class CitizenMarketplaceData {
  const CitizenMarketplaceData({
    required this.availableItems,
    required this.myItems,
    required this.categories,
    required this.totalListings,
    required this.activeListings,
    required this.soldListings,
  });

  final List<MarketplaceItem> availableItems;
  final List<MarketplaceItem> myItems;
  final List<String> categories;
  final int totalListings;
  final int activeListings;
  final int soldListings;
}

class CreateMarketplaceItemPayload {
  const CreateMarketplaceItemPayload({
    required this.title,
    required this.category,
    required this.price,
    required this.quantity,
    required this.description,
    this.imageBase64,
    required this.location,
  });

  final String title;
  final String category;
  final double price;
  final int quantity;
  final String description;
  final String? imageBase64;
  final LatLng location;
}

class CitizenMarketplaceService {
  CitizenMarketplaceService() : _client = Supabase.instance.client;

  final SupabaseClient _client;
  CitizenMarketplaceData? _cachedData;
  DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(seconds: 30);
  static const List<String> _defaultCategories = <String>[
    'General',
    'Recyclables',
    'Compost',
    'E-Waste',
    'Home Utility',
    'Others',
  ];

  // ---------- Marketplace ----------

  Future<CitizenMarketplaceData> getMarketplaceData({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedData != null && _cachedAt != null) {
      final Duration age = DateTime.now().difference(_cachedAt!);
      if (age <= _cacheTtl) {
        return _cachedData!;
      }
    }

    final String userId = _requireUserId();

    final List<dynamic> rows = await _client
        .from('marketplace_items')
        .select(
          'id, seller_id, title, description, category, price, quantity, image_url, status, latitude, longitude, created_at, citizens(full_name)',
        )
        .order('created_at', ascending: false);

    final List<MarketplaceItem> allItems = rows.map((row) {
      final Map<String, dynamic> data = row as Map<String, dynamic>;
      final Map<String, dynamic>? seller = data['citizens'] is Map<String, dynamic>
          ? data['citizens'] as Map<String, dynamic>
          : null;

      return MarketplaceItem(
        id: data['id']?.toString() ?? '',
        title: data['title']?.toString() ?? 'Untitled Item',
        category: data['category']?.toString() ?? 'General',
        price: _toDouble(data['price']),
        quantity: _toInt(data['quantity']),
        description: data['description']?.toString() ?? '',
        status: _prettyStatus(data['status']?.toString()),
        createdLabel: _formatTimestamp(data['created_at']?.toString()),
        imageUrl: data['image_url']?.toString() ?? '',
        sellerName: seller?['full_name']?.toString() ?? 'Citizen Seller',
        isMine: data['seller_id']?.toString() == userId,
        location: LatLng(
          _toDouble(data['latitude']),
          _toDouble(data['longitude']),
        ),
      );
    }).toList();

    final List<MarketplaceItem> availableItems = allItems
        .where((item) => item.status.toLowerCase() == 'available')
        .toList();

    final List<MarketplaceItem> myItems = allItems.where((item) => item.isMine).toList();

    final Set<String> categories = <String>{..._defaultCategories};
    for (final MarketplaceItem item in allItems) {
      if (item.category.trim().isNotEmpty) {
        categories.add(item.category);
      }
    }

    final int soldCount = myItems.where((item) => item.status.toLowerCase() == 'sold').length;
    final int activeCount =
        myItems.where((item) => item.status.toLowerCase() == 'available').length;

    final CitizenMarketplaceData data = CitizenMarketplaceData(
      availableItems: availableItems,
      myItems: myItems,
      categories: categories.toList(),
      totalListings: myItems.length,
      activeListings: activeCount,
      soldListings: soldCount,
    );

    _cachedData = data;
    _cachedAt = DateTime.now();
    return data;
  }

  Future<void> createMarketplaceItem(CreateMarketplaceItemPayload payload) async {
    final String userId = _requireUserId();
    if (payload.title.trim().isEmpty) {
      throw Exception('Please enter item title.');
    }
    if (payload.category.trim().isEmpty) {
      throw Exception('Please select item category.');
    }
    if (payload.price <= 0) {
      throw Exception('Price should be greater than zero.');
    }
    if (payload.quantity <= 0) {
      throw Exception('Quantity should be at least 1.');
    }

    if (payload.imageBase64 != null && payload.imageBase64!.trim().isNotEmpty) {
      try {
        base64Decode(payload.imageBase64!);
      } catch (_) {
        throw Exception('Invalid image data. Please pick image again.');
      }
    }

    await _client.from('marketplace_items').insert({
      'seller_id': userId,
      'title': payload.title.trim(),
      'description': payload.description.trim(),
      'category': payload.category.trim(),
      'price': payload.price,
      'quantity': payload.quantity,
      'image_url': payload.imageBase64?.trim(),
      'status': 'available',
      'latitude': payload.location.latitude,
      'longitude': payload.location.longitude,
    });
  }

  Future<void> updateListingStatus({
    required String itemId,
    required String nextStatus,
  }) async {
    final String userId = _requireUserId();
    final String normalized = nextStatus.trim().toLowerCase();
    if (normalized != 'available' && normalized != 'sold' && normalized != 'inactive') {
      throw Exception('Unsupported status update.');
    }

    await _client
        .from('marketplace_items')
        .update({'status': normalized})
        .eq('id', itemId)
        .eq('seller_id', userId);
  }

  String _requireUserId() {
    final String? userId = AuthService.currentUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('User session not found. Please login again.');
    }
    return userId;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '1') ?? 1;
  }

  String _prettyStatus(String? raw) {
    switch (raw) {
      case 'sold':
        return 'Sold';
      case 'inactive':
        return 'Inactive';
      case 'available':
      default:
        return 'Available';
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

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }
}

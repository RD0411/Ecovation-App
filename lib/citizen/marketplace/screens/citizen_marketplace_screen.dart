import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_impetus/citizen/marketplace/screens/create_marketplace_listing_screen.dart';
import 'package:citizen_impetus/citizen/marketplace/services/citizen_marketplace_service.dart';
import 'package:flutter/material.dart';

class CitizenMarketplaceScreen extends StatefulWidget {
  const CitizenMarketplaceScreen({super.key});

  @override
  State<CitizenMarketplaceScreen> createState() => _CitizenMarketplaceScreenState();
}

class _CitizenMarketplaceScreenState extends State<CitizenMarketplaceScreen> {
  final CitizenMarketplaceService _service = CitizenMarketplaceService();
  final TextEditingController _searchController = TextEditingController();

  List<MarketplaceItem> _availableItems = <MarketplaceItem>[];
  List<MarketplaceItem> _myItems = <MarketplaceItem>[];
  List<String> _categories = <String>['All'];

  String _activeCategory = 'All';
  bool _showMyListings = false;
  int _totalListings = 0;
  int _activeListings = 0;
  int _soldListings = 0;

  bool _loading = true;
  bool _updatingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadMarketplace();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMarketplace({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
    });

    try {
      final CitizenMarketplaceData data =
          await _service.getMarketplaceData(forceRefresh: forceRefresh);
      if (!mounted) {
        return;
      }

      setState(() {
        _availableItems = List<MarketplaceItem>.from(data.availableItems);
        _myItems = List<MarketplaceItem>.from(data.myItems);
        _categories = <String>['All', ...data.categories.where((c) => c.trim().isNotEmpty)];
        if (!_categories.contains(_activeCategory)) {
          _activeCategory = 'All';
        }
        _totalListings = data.totalListings;
        _activeListings = data.activeListings;
        _soldListings = data.soldListings;
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

  Future<void> _openCreateListingScreen() async {
    final bool? didAdd = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateMarketplaceListingScreen(categories: _categories),
      ),
    );

    if (!mounted || didAdd != true) {
      return;
    }

    await _loadMarketplace(forceRefresh: true);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Listing created successfully.')),
    );
  }

  Future<void> _updateListingStatus({
    required MarketplaceItem item,
    required String nextStatus,
  }) async {
    setState(() {
      _updatingStatus = true;
    });

    try {
      await _service.updateListingStatus(itemId: item.id, nextStatus: nextStatus);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Listing updated to ${nextStatus.toUpperCase()}.')),
      );
      await _loadMarketplace(forceRefresh: true);
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
          _updatingStatus = false;
        });
      }
    }
  }

  List<MarketplaceItem> _filteredItems() {
    final String query = _searchController.text.trim().toLowerCase();
    final List<MarketplaceItem> source = _showMyListings ? _myItems : _availableItems;

    return source.where((item) {
      final bool categoryMatch =
          _activeCategory == 'All' || item.category.toLowerCase() == _activeCategory.toLowerCase();
      final bool queryMatch = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
      return categoryMatch && queryMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<MarketplaceItem> filteredItems = _filteredItems();

    return RefreshIndicator(
      onRefresh: () => _loadMarketplace(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 12),
          _buildSearchRow(),
          const SizedBox(height: 10),
          _buildCategoryFilters(),
          const SizedBox(height: 12),
          ...filteredItems.map((item) => _buildItemCard(item, isMyItem: item.isMine)),
          if (filteredItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE5DE)),
              ),
              child: Text(
                _showMyListings
                    ? 'No listings found. Create your first item.'
                    : 'No items match your search/filter.',
                style: const TextStyle(
                  color: Color(0xFF66747A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E9B45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _openCreateListingScreen,
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Create New Listing'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D9A44), Color(0xFF1F7D35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final Widget segment = SegmentedButton<bool>(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.24),
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? const Color(0xFF1A6A2F)
                        : Colors.white,
                  ),
                ),
                selected: <bool>{_showMyListings},
                segments: const [
                  ButtonSegment<bool>(value: false, label: Text('Browse')),
                  ButtonSegment<bool>(value: true, label: Text('Mine')),
                ],
                onSelectionChanged: (selection) {
                  setState(() {
                    _showMyListings = selection.first;
                  });
                },
              );

              if (constraints.maxWidth < 430) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Citizen Marketplace',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    segment,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      'Citizen Marketplace',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  segment,
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statPill('Total', _totalListings.toString()),
              _statPill('Active', _activeListings.toString()),
              _statPill('Sold', _soldListings.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, String value) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE5F2E8),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return TextField(
      controller: _searchController,
      onChanged: (_) {
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: 'Search item title or description...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final String category = _categories[index];
          final bool selected = category == _activeCategory;
          return ChoiceChip(
            selected: selected,
            label: Text(category),
            onSelected: (_) {
              setState(() {
                _activeCategory = category;
              });
            },
            selectedColor: const Color(0xFF2E9B45),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF2B3946),
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          );
        },
        separatorBuilder: (_, index) => const SizedBox(width: 6),
        itemCount: _categories.length,
      ),
    );
  }

  Widget _buildItemCard(MarketplaceItem item, {required bool isMyItem}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildItemImage(item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF222B34),
                              ),
                        ),
                      ),
                      _statusChip(item.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.category,
                    style: const TextStyle(
                      color: Color(0xFF61717F),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${item.price.toStringAsFixed(item.price % 1 == 0 ? 0 : 2)}',
                    style: const TextStyle(
                      color: Color(0xFF338A2B),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Qty: ${item.quantity}  •  ${item.createdLabel}',
                    style: const TextStyle(
                      color: Color(0xFF7A868F),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: const TextStyle(
                      color: Color(0xFF838C95),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Seller: ${item.sellerName}',
                    style: const TextStyle(
                      color: Color(0xFF687580),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (isMyItem) ...[
                    const SizedBox(height: 8),
                    _buildMyActions(item),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemImage(MarketplaceItem item) {
    Widget child;
    if (item.imageUrl.trim().isEmpty) {
      child = const Icon(Icons.image_outlined, size: 30, color: Color(0xFF8B97A1));
    } else {
      try {
        final Uint8List bytes = base64Decode(item.imageUrl);
        child = Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        child = const Icon(Icons.broken_image_outlined, size: 30, color: Color(0xFF8B97A1));
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 78,
        height: 78,
        color: const Color(0xFFE2E8E3),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _statusChip(String status) {
    final String normalized = status.toLowerCase();
    Color color;
    if (normalized == 'sold') {
      color = const Color(0xFF2C84D5);
    } else if (normalized == 'inactive') {
      color = const Color(0xFF7B8793);
    } else {
      color = const Color(0xFF2E9B45);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        status,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  Widget _buildMyActions(MarketplaceItem item) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        OutlinedButton.icon(
          onPressed: _updatingStatus || item.status.toLowerCase() == 'sold'
              ? null
              : () => _updateListingStatus(item: item, nextStatus: 'sold'),
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: const Text('Mark Sold'),
        ),
        OutlinedButton.icon(
          onPressed: _updatingStatus || item.status.toLowerCase() == 'available'
              ? null
              : () => _updateListingStatus(item: item, nextStatus: 'available'),
          icon: const Icon(Icons.refresh_outlined, size: 16),
          label: const Text('Reactivate'),
        ),
        OutlinedButton.icon(
          onPressed: _updatingStatus || item.status.toLowerCase() == 'inactive'
              ? null
              : () => _updateListingStatus(item: item, nextStatus: 'inactive'),
          icon: const Icon(Icons.visibility_off_outlined, size: 16),
          label: const Text('Archive'),
        ),
      ],
    );
  }
}

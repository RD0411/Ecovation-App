import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_impetus/citizen/profile/services/citizen_distribution_service.dart';
import 'package:flutter/material.dart';

class CitizenDistributionScreen extends StatefulWidget {
  const CitizenDistributionScreen({super.key});

  @override
  State<CitizenDistributionScreen> createState() => _CitizenDistributionScreenState();
}

class _CitizenDistributionScreenState extends State<CitizenDistributionScreen> {
  final CitizenDistributionService _service = CitizenDistributionService();

  List<CitizenDistributionItem> _items = <CitizenDistributionItem>[];
  bool _loading = true;
  String _query = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadDistributions();
  }

  Future<void> _loadDistributions() async {
    setState(() {
      _loading = true;
    });

    try {
      final CitizenDistributionData data = await _service.getDistributionData();
      if (!mounted) {
        return;
      }

      setState(() {
        _items = List<CitizenDistributionItem>.from(data.items);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _markReceived(int index) async {
    final CitizenDistributionItem item = _items[index];
    if (!item.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.title} is currently out of stock.')),
      );
      return;
    }

    setState(() {
      _items[index] = _items[index].copyWith(received: true);
    });

    await _service.setItemReceived(itemId: item.id, received: true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_items[index].title} marked as received.')),
    );
  }

  List<CitizenDistributionItem> get _filteredItems {
    final String query = _query.trim().toLowerCase();
    return _items.where((CitizenDistributionItem item) {
      if (_filter == 'available' && !item.isAvailable) {
        return false;
      }
      if (_filter == 'received' && !item.received) {
        return false;
      }
      if (_filter == 'out_of_stock' && item.isAvailable) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final String text = '${item.title} ${item.description}'.toLowerCase();
      return text.contains(query);
    }).toList(growable: false);
  }

  Widget _buildSummaryCard() {
    final int available = _items.where((CitizenDistributionItem i) => i.isAvailable).length;
    final int received = _items.where((CitizenDistributionItem i) => i.received).length;
    final int outOfStock = _items.where((CitizenDistributionItem i) => !i.isAvailable).length;

    Widget tile(String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F8E57), Color(0xFF157347)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribution Availability',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              tile('Available', '$available'),
              const SizedBox(width: 8),
              tile('Received', '$received'),
              const SizedBox(width: 8),
              tile('Out of Stock', '$outOfStock'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E9B45),
        foregroundColor: Colors.white,
        title: const Text('Available Distributions'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDistributions,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildSummaryCard(),
            TextField(
              onChanged: (String value) {
                setState(() {
                  _query = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search distributions',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filter == 'all',
                    onSelected: (_) => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Available'),
                    selected: _filter == 'available',
                    onSelected: (_) => setState(() => _filter = 'available'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Received'),
                    selected: _filter == 'received',
                    onSelected: (_) => setState(() => _filter = 'received'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Out of Stock'),
                    selected: _filter == 'out_of_stock',
                    onSelected: (_) => setState(() => _filter = 'out_of_stock'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_filteredItems.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No distribution items found for this filter.'),
                ),
              )
            else
              ..._filteredItems
                  .asMap()
                  .entries
                  .map((entry) => _buildDistributionCard(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionCard(int index, CitizenDistributionItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE9EDF0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD5DBE0)),
              ),
              child: _buildDistributionImage(item, index),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 30 / 2,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                item.description,
                style: const TextStyle(
                  color: Color(0xFF656F79),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isAvailable
                        ? const Color(0xFF1E8449).withValues(alpha: 0.12)
                        : const Color(0xFFC0392B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.isAvailable ? 'IN STOCK' : 'OUT OF STOCK',
                    style: TextStyle(
                      color: item.isAvailable
                          ? const Color(0xFF1E8449)
                          : const Color(0xFFC0392B),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Stock: ${item.stock}',
                  style: const TextStyle(
                    color: Color(0xFF687480),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (item.showReceiveButton) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: item.received
                        ? const Color(0xFF6FA832)
                        : !item.isAvailable
                            ? const Color(0xFF95A5A6)
                        : const Color(0xFF6AA20A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: (item.received || !item.isAvailable)
                      ? null
                      : () => _markReceived(index),
                  child: Text(item.received ? 'Received' : 'Mark Received'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionImage(CitizenDistributionItem item, int index) {
    final Uint8List? imageBytes = _decodeBase64Image(item.imageUrl);
    if (imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }

    if (_looksLikeNetworkUrl(item.imageUrl)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          item.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return CustomPaint(painter: _DistributionImagePainter(isCompost: index == 0));
          },
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _DistributionImagePainter(isCompost: index == 0)),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Sample Image',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Uint8List? _decodeBase64Image(String raw) {
    final String input = raw.trim();
    if (input.isEmpty) {
      return null;
    }

    String payload = input;
    final int commaIndex = payload.indexOf(',');
    if (payload.startsWith('data:image') && commaIndex != -1) {
      payload = payload.substring(commaIndex + 1);
    }

    // Remove line breaks/spaces sometimes introduced during storage or copy.
    payload = payload.replaceAll(RegExp(r'\s+'), '');

    try {
      return base64Decode(base64.normalize(payload));
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeNetworkUrl(String value) {
    final String text = value.trim().toLowerCase();
    return text.startsWith('http://') || text.startsWith('https://');
  }
}

class _DistributionImagePainter extends CustomPainter {
  const _DistributionImagePainter({required this.isCompost});

  final bool isCompost;

  @override
  void paint(Canvas canvas, Size size) {
    if (isCompost) {
      final Paint drumPaint = Paint()..color = const Color(0xFF1F2528);
      final Paint lidPaint = Paint()..color = const Color(0xFFB58A2B);

      final Rect leftDrum = Rect.fromLTWH(size.width * 0.18, size.height * 0.34, 70, 70);
      final Rect rightDrum = Rect.fromLTWH(size.width * 0.52, size.height * 0.34, 70, 70);

      canvas.drawRRect(
        RRect.fromRectAndRadius(leftDrum, const Radius.circular(10)),
        drumPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rightDrum, const Radius.circular(10)),
        drumPaint,
      );
      canvas.drawOval(
        Rect.fromLTWH(size.width * 0.17, size.height * 0.28, 76, 16),
        lidPaint,
      );
      canvas.drawOval(
        Rect.fromLTWH(size.width * 0.51, size.height * 0.28, 76, 16),
        Paint()..color = const Color(0xFFECECEC),
      );
    } else {
      final List<Color> colors = <Color>[
        const Color(0xFFE1BF2B),
        const Color(0xFF2D3034),
        const Color(0xFFD83535),
      ];
      for (int i = 0; i < colors.length; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * (0.18 + (i * 0.2)), size.height * 0.35, 56, 62),
            const Radius.circular(6),
          ),
          Paint()..color = colors[i],
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DistributionImagePainter oldDelegate) {
    return oldDelegate.isCompost != isCompost;
  }
}

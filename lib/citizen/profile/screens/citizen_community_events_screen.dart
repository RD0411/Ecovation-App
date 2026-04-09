import 'package:citizen_impetus/citizen/profile/services/citizen_community_events_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CitizenCommunityEventsScreen extends StatefulWidget {
  const CitizenCommunityEventsScreen({super.key});

  @override
  State<CitizenCommunityEventsScreen> createState() =>
      _CitizenCommunityEventsScreenState();
}

class _CitizenCommunityEventsScreenState
    extends State<CitizenCommunityEventsScreen> {
  final CitizenCommunityEventsService _service = CitizenCommunityEventsService();

  List<CitizenCommunityEvent> _events = <CitizenCommunityEvent>[];
  bool _loading = true;
  String _query = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
    });

    try {
      final CitizenCommunityEventsData data = await _service.getCommunityEvents();
      if (!mounted) {
        return;
      }

      setState(() {
        _events = List<CitizenCommunityEvent>.from(data.events);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _joinEvent(int index) async {
    setState(() {
      _events[index] = _events[index].copyWith(joined: true);
    });

    await _service.setEventJoined(eventId: _events[index].id, joined: true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Joined ${_events[index].title}')),
    );
  }

  Future<void> _openLocation(String location) async {
    final String query = location.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available for this event.')),
      );
      return;
    }

    final Uri mapUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    final bool launched = await launchUrl(mapUri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open map location.')),
      );
    }
  }

  List<CitizenCommunityEvent> get _filteredEvents {
    final String query = _query.trim().toLowerCase();
    return _events.where((CitizenCommunityEvent event) {
      if (_filter == 'joined' && !event.joined) {
        return false;
      }
      if (_filter == 'upcoming' && event.status != 'upcoming') {
        return false;
      }
      if (_filter == 'ongoing' && event.status != 'ongoing') {
        return false;
      }
      if (_filter == 'completed' && event.status != 'completed') {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final String text = '${event.title} ${event.description} ${event.location}'.toLowerCase();
      return text.contains(query);
    }).toList(growable: false);
  }

  Widget _buildSummaryCard() {
    final int joined = _events.where((CitizenCommunityEvent e) => e.joined).length;
    final int upcoming = _events.where((CitizenCommunityEvent e) => e.status == 'upcoming').length;
    final int ongoing = _events.where((CitizenCommunityEvent e) => e.status == 'ongoing').length;

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
            'Community Participation',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              tile('Joined', '$joined'),
              const SizedBox(width: 8),
              tile('Upcoming', '$upcoming'),
              const SizedBox(width: 8),
              tile('Ongoing', '$ongoing'),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ongoing':
        return const Color(0xFF2D9CDB);
      case 'completed':
        return const Color(0xFF7F8C8D);
      case 'upcoming':
      default:
        return const Color(0xFFE67E22);
    }
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
        title: const Text('Community Events'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
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
                hintText: 'Search events by title, description, or location',
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
                    label: const Text('Upcoming'),
                    selected: _filter == 'upcoming',
                    onSelected: (_) => setState(() => _filter = 'upcoming'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Ongoing'),
                    selected: _filter == 'ongoing',
                    onSelected: (_) => setState(() => _filter = 'ongoing'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Completed'),
                    selected: _filter == 'completed',
                    onSelected: (_) => setState(() => _filter = 'completed'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Joined'),
                    selected: _filter == 'joined',
                    onSelected: (_) => setState(() => _filter = 'joined'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_filteredEvents.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No events found for this filter.'),
                ),
              )
            else
              ..._filteredEvents
                .asMap()
                .entries
                .map((entry) => _buildEventCard(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(int index, CitizenCommunityEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF303A45),
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              event.description,
              style: const TextStyle(
                color: Color(0xFF6A7480),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: Color(0xFF7A848D)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    event.dateLabel,
                    style: const TextStyle(
                      color: Color(0xFF7A848D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: Color(0xFF7A848D)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    event.location,
                    style: const TextStyle(
                      color: Color(0xFF7A848D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(event.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    event.status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(event.status),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (event.joined) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.verified, color: Color(0xFF1E8449), size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'Joined',
                    style: TextStyle(
                      color: Color(0xFF1E8449),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () => _openLocation(event.location),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open Location'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: event.joined
                      ? const Color(0xFF6FA832)
                      : const Color(0xFF32973E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: event.joined ? null : () => _joinEvent(index),
                child: Text(event.joined ? 'Joined' : 'Join Event'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

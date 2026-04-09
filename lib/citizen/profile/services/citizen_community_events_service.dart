import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CitizenCommunityEvent {
  const CitizenCommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.dateLabel,
    required this.location,
    required this.status,
    this.startDate,
    this.endDate,
    this.joined = false,
  });

  final String id;
  final String title;
  final String description;
  final String dateLabel;
  final String location;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool joined;

  CitizenCommunityEvent copyWith({bool? joined}) {
    return CitizenCommunityEvent(
      id: id,
      title: title,
      description: description,
      dateLabel: dateLabel,
      location: location,
      status: status,
      startDate: startDate,
      endDate: endDate,
      joined: joined ?? this.joined,
    );
  }
}

class CitizenCommunityEventsData {
  const CitizenCommunityEventsData({
    required this.events,
  });

  final List<CitizenCommunityEvent> events;
}

class CitizenCommunityEventsService {
  CitizenCommunityEventsService()
      : _client = Supabase.instance.client;

  static const String _joinedEventsKey = 'citizen_joined_event_ids';

  final SupabaseClient _client;

  // ---------- Community Events ----------

  Future<CitizenCommunityEventsData> getCommunityEvents() async {
    final Set<String> joinedIds = await _getJoinedIds();

    final List<dynamic> rows = await _client
        .from('events')
        .select('id, title, description, location, start_date, end_date, status')
        .neq('status', 'cancelled')
        .order('start_date', ascending: true);

    final List<CitizenCommunityEvent> events = rows.map((row) {
      final Map<String, dynamic> data = row as Map<String, dynamic>;
      final String id = data['id']?.toString() ?? '';
      final DateTime? startDate = _parseDate(data['start_date']);
      final DateTime? endDate = _parseDate(data['end_date']);
      final String status = (data['status']?.toString() ?? 'upcoming').toLowerCase();
      return CitizenCommunityEvent(
        id: id,
        title: data['title']?.toString() ?? 'Community Event',
        description: data['description']?.toString() ?? '',
        location: data['location']?.toString() ?? '',
        dateLabel: _formatDateRange(startDate, endDate),
        status: status,
        startDate: startDate,
        endDate: endDate,
        joined: joinedIds.contains(id),
      );
    }).toList();

    return CitizenCommunityEventsData(events: events);
  }

  Future<void> setEventJoined({
    required String eventId,
    required bool joined,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Set<String> ids = await _getJoinedIds();

    if (joined) {
      ids.add(eventId);
    } else {
      ids.remove(eventId);
    }

    await prefs.setStringList(_joinedEventsKey, ids.toList(growable: false));
  }

  Future<Set<String>> _getJoinedIds() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_joinedEventsKey) ?? <String>[]).toSet();
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is DateTime) {
      return raw;
    }
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null) {
      return 'Schedule to be announced';
    }

    final List<String> weekDays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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

    String pointLabel(DateTime d) {
      final int hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final String minute = d.minute.toString().padLeft(2, '0');
      final String amPm = d.hour >= 12 ? 'PM' : 'AM';
      return '${weekDays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year} - $hour12:$minute $amPm';
    }

    if (end == null) {
      return pointLabel(start);
    }
    return '${pointLabel(start)} to ${pointLabel(end)}';
  }
}

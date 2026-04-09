import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CitizenTrainingModule {
  const CitizenTrainingModule({
    required this.id,
    required this.title,
    required this.description,
    required this.videoLabel,
    required this.videoUrl,
    required this.completed,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String videoLabel;
  final String videoUrl;
  final bool completed;
  final DateTime? createdAt;

  CitizenTrainingModule copyWith({bool? completed, DateTime? createdAt}) {
    return CitizenTrainingModule(
      id: id,
      title: title,
      description: description,
      videoLabel: videoLabel,
      videoUrl: videoUrl,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class CitizenTrainingData {
  const CitizenTrainingData({
    required this.modules,
  });

  final List<CitizenTrainingModule> modules;
}

class CitizenTrainingService {
  CitizenTrainingService()
      : _client = Supabase.instance.client;

  static const String _completedCoursesKey = 'citizen_training_completed_ids';

  final SupabaseClient _client;

  // ---------- Training ----------

  Future<CitizenTrainingData> getTrainingData() async {
    final Set<String> completedIds = await _getCompletedIds();

    final List<dynamic> rows = await _client
        .from('training_courses')
        .select('id, title, description, video_url, created_at')
        .order('created_at', ascending: false);

    final List<CitizenTrainingModule> modules = rows.map((row) {
      final Map<String, dynamic> data = row as Map<String, dynamic>;
      final String id = data['id']?.toString() ?? '';
      return CitizenTrainingModule(
        id: id,
        title: data['title']?.toString() ?? 'Untitled Module',
        description: data['description']?.toString() ?? '',
        videoLabel: 'Watch Video',
        videoUrl: data['video_url']?.toString() ?? '',
        completed: completedIds.contains(id),
        createdAt: _parseDate(data['created_at']),
      );
    }).toList();

    return CitizenTrainingData(modules: modules);
  }

  Future<void> setModuleCompleted({
    required String moduleId,
    required bool completed,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Set<String> ids = await _getCompletedIds();

    if (completed) {
      ids.add(moduleId);
    } else {
      ids.remove(moduleId);
    }

    await prefs.setStringList(_completedCoursesKey, ids.toList(growable: false));
  }

  Future<Set<String>> _getCompletedIds() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_completedCoursesKey) ?? <String>[]).toSet();
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

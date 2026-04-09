import 'package:flutter/services.dart';
import 'package:citizen_impetus/citizen/profile/services/citizen_training_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CitizenTrainingScreen extends StatefulWidget {
  const CitizenTrainingScreen({super.key});

  @override
  State<CitizenTrainingScreen> createState() => _CitizenTrainingScreenState();
}

class _CitizenTrainingScreenState extends State<CitizenTrainingScreen> {
  final CitizenTrainingService _service = CitizenTrainingService();

  List<CitizenTrainingModule> _modules = <CitizenTrainingModule>[];
  bool _loading = true;
  String _query = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTraining();
  }

  Future<void> _loadTraining() async {
    setState(() {
      _loading = true;
    });

    try {
      final CitizenTrainingData data = await _service.getTrainingData();
      if (!mounted) {
        return;
      }

      setState(() {
        _modules = List<CitizenTrainingModule>.from(data.modules);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _watchVideo(CitizenTrainingModule module) async {
    final String url = module.videoUrl.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video URL not configured for ${module.title}.')),
      );
      return;
    }

    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid video URL for ${module.title}.')),
      );
      return;
    }

    final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: module.videoUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open URL. Link copied to clipboard.')),
      );
    }
  }

  Future<void> _markCompleted(int index) async {
    setState(() {
      _modules[index] = _modules[index].copyWith(completed: true);
    });

    await _service.setModuleCompleted(moduleId: _modules[index].id, completed: true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_modules[index].title} marked completed.')),
    );
  }

  List<CitizenTrainingModule> get _filteredModules {
    final String query = _query.trim().toLowerCase();
    return _modules.where((CitizenTrainingModule module) {
      if (_filter == 'completed' && !module.completed) {
        return false;
      }
      if (_filter == 'pending' && module.completed) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final String haystack = '${module.title} ${module.description}'.toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  Widget _buildSummaryCard() {
    final int total = _modules.length;
    final int done = _modules.where((CitizenTrainingModule m) => m.completed).length;
    final int pending = total - done;
    final double progress = total == 0 ? 0 : done / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F8E57), Color(0xFF157347)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Training Progress',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '$done completed  •  $pending pending  •  $total total',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              color: Colors.white,
              backgroundColor: Colors.white30,
            ),
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
        title: const Text('Training Modules'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTraining,
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
                hintText: 'Search by title or description',
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
                    label: const Text('Pending'),
                    selected: _filter == 'pending',
                    onSelected: (_) => setState(() => _filter = 'pending'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Completed'),
                    selected: _filter == 'completed',
                    onSelected: (_) => setState(() => _filter = 'completed'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: Color(0xFF4D5A66)),
                const SizedBox(width: 8),
                Text(
                  'Training Modules',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF3F4A55),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_filteredModules.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No training modules found for this filter.'),
                ),
              )
            else
              ..._filteredModules.asMap().entries.map(
              (entry) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.value.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF303A45),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.value.description,
                        style: const TextStyle(
                          color: Color(0xFF6A7480),
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFEB4A3A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          onPressed: () => _watchVideo(entry.value),
                          child: Text('▶  ${entry.value.videoLabel}'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF22B05B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          onPressed: entry.value.completed
                              ? null
                              : () => _markCompleted(entry.key),
                          child: Text(
                            entry.value.completed
                                ? 'Completed'
                                : 'Mark Completed',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

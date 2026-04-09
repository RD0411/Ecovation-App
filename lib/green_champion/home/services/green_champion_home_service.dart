import 'package:citizen_impetus/common/models/module_data.dart';

class GreenChampionHomeService {
  Future<ModuleData> getHomeData() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    return const ModuleData(
      title: 'Champion Home',
      description: 'Community engagement overview and verification queue.',
      kpi: {
        'Pending Reviews': '11',
        'Resolved This Week': '27',
        'Engagement Score': '88%',
      },
      items: [
        'Ward 2 has increased reports near school boundary.',
        'Two neighborhood drives requested champion approval.',
        'Top volunteer team this week: River Guardians.',
      ],
    );
  }
}

import 'package:citizen_impetus/common/models/module_data.dart';

class GreenChampionProfileService {
  Future<ModuleData> getProfileData() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));

    return const ModuleData(
      title: 'Champion Profile',
      description: 'Manage verification privileges and community goals.',
      kpi: {
        'Verification Accuracy': '94%',
        'Campaigns Led': '6',
        'Followers': '312',
      },
      items: [
        'Monthly campaign target: reduce hotspot count by 12%.',
        'Mentorship enabled for 4 new local volunteers.',
        'Public profile badge upgraded to Community Leader.',
      ],
    );
  }
}

import 'package:citizen_impetus/common/models/module_data.dart';

class GreenChampionMapService {
  Future<ModuleData> getMapData() async {
    await Future<void>.delayed(const Duration(milliseconds: 270));

    return const ModuleData(
      title: 'Champion Map',
      description: 'Monitor hotspots and route cleanup planning.',
      kpi: {
        'Hotspots': '8',
        'Critical Zones': '3',
        'Patrol Routes': '5',
      },
      items: [
        'New hotspot detected near East Bus Terminal.',
        'Critical zone downgraded in Riverside after clearance.',
        'Suggested patrol route B minimizes overlap with workers.',
      ],
    );
  }
}

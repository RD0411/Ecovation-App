import 'green_champion_data_source.dart';
import 'green_champion_demo_repository.dart';
import 'green_champion_repository.dart';

class GreenChampionModuleProvider {
  GreenChampionModuleProvider._();

  static const bool useDemoData = bool.fromEnvironment(
    'GC_USE_DEMO_DATA',
    defaultValue: false,
  );

  static final GreenChampionDataSource instance = useDemoData
      ? GreenChampionDemoRepository()
      : GreenChampionRepository();
}

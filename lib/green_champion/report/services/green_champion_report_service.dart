import 'package:citizen_impetus/common/models/module_data.dart';

class GreenChampionReportService {
  Future<ModuleData> getReportData() async {
    await Future<void>.delayed(const Duration(milliseconds: 260));

    return const ModuleData(
      title: 'Champion Reports',
      description: 'Verify reports and provide moderation updates.',
      kpi: {
        'Awaiting Verification': '11',
        'Approved': '72',
        'Flagged': '6',
      },
      items: [
        'Photo mismatch in report #CI-404 requires secondary review.',
        'Bulk waste complaint in sector 9 approved for collection.',
        'Duplicate report cluster detected around Central Bridge.',
      ],
    );
  }
}

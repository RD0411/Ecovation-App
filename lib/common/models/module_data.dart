class ModuleData {
  const ModuleData({
    required this.title,
    required this.description,
    required this.kpi,
    required this.items,
  });

  final String title;
  final String description;
  final Map<String, String> kpi;
  final List<String> items;
}

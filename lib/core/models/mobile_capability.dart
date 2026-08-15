class MobileCapability {
  const MobileCapability({
    required this.id,
    required this.key,
    required this.title,
    required this.type,
    required this.config,
    this.description,
    this.icon,
  });
  final int id;
  final String key, title, type;
  final String? description, icon;
  final Map<String, dynamic> config;
  factory MobileCapability.fromJson(Map<String, dynamic> j) => MobileCapability(
    id: (j['id'] as num).toInt(),
    key: j['key'],
    title: j['title'],
    type: j['type'],
    description: j['description'],
    icon: j['icon'],
    config: Map<String, dynamic>.from((j['config'] as Map?) ?? {}),
  );
}

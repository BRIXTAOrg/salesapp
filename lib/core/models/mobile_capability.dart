class MobileCapability {
  const MobileCapability({
    required this.id,
    required this.key,
    required this.title,
    required this.type,
    required this.config,
    required this.definition,
    this.description,
    this.icon,
  });

  final int id;
  final String key, title, type;
  final String? description, icon;

  /// Raw compatibility config. New Platform Core responses expose the
  /// normalized definition separately; older cached sessions may only have
  /// config, so both are retained while the app migrates.
  final Map<String, dynamic> config;

  /// Canonical Responsibility definition returned by /api/salesApp/bootstrap.
  final Map<String, dynamic> definition;

  Map<String, dynamic> get inputDefinition {
    final raw = definition['input'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Map<String, dynamic> get appDefinition {
    final direct = definition['app'];
    if (direct is Map) return Map<String, dynamic>.from(direct);

    final rawDefinition = definition['raw'];
    if (rawDefinition is Map) {
      final rawApp = rawDefinition['app'];
      if (rawApp is Map) return Map<String, dynamic>.from(rawApp);
    }

    final configApp = config['app'];
    if (configApp is Map) return Map<String, dynamic>.from(configApp);

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> get fields {
    final input = inputDefinition;
    final rawFields = input['fields'];

    if (rawFields is List) {
      return rawFields
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    // Old cached capability shape.
    final legacy = config['fields'];
    if (legacy is List) {
      return legacy
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return const [];
  }

  bool get hasGeneratedApp {
    final app = appDefinition;
    final actions = app['actions'];
    return app.isNotEmpty || actions is List;
  }

  factory MobileCapability.fromJson(Map<String, dynamic> j) {
    final rawDefinition = j['definition'];
    final definition = rawDefinition is Map
        ? Map<String, dynamic>.from(rawDefinition)
        : <String, dynamic>{};

    final rawConfig = j['config'];
    Map<String, dynamic> config;

    if (rawConfig is Map) {
      config = Map<String, dynamic>.from(rawConfig);
    } else {
      final normalizedRaw = definition['raw'];
      config = normalizedRaw is Map
          ? Map<String, dynamic>.from(normalizedRaw)
          : Map<String, dynamic>.from(definition);
    }

    return MobileCapability(
      id: (j['id'] as num).toInt(),
      key: j['key'].toString(),
      title: j['title'].toString(),
      type: (j['type'] ?? 'record').toString(),
      description: j['description']?.toString(),
      icon: j['icon']?.toString(),
      config: config,
      definition: definition,
    );
  }
}

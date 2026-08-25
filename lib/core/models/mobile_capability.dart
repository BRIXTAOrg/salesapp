class MobileCapability {
  const MobileCapability({
    required this.id,
    required this.key,
    required this.title,
    required this.type,
    required this.config,
    required this.definition,
    this.runtimeManifest = const {},
    this.description,
    this.icon,
  });

  final int id;
  final String key, title, type;
  final String? description, icon;

  /// Compatibility definition used by pre-Kernel screens.
  final Map<String, dynamic> config;
  final Map<String, dynamic> definition;

  /// Latest published CMS contract. This is authoritative when
  /// kernelAvailable is true.
  final Map<String, dynamic> runtimeManifest;

  bool get kernelAvailable => runtimeManifest['kernelAvailable'] == true;
  int get manifestVersion =>
      int.tryParse(runtimeManifest['version']?.toString() ?? '') ?? 0;
  String get manifestHash => runtimeManifest['hash']?.toString() ?? '';
  String get manifestSource => runtimeManifest['source']?.toString() ?? '';

  Map<String, dynamic> get publishedManifest {
    final raw = runtimeManifest['manifest'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Map<String, dynamic> get kernelDefinition =>
      _extractKernel(publishedManifest) ?? const <String, dynamic>{};

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
    if (kernelAvailable) return true;
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

    final rawRuntimeManifest = j['runtimeManifest'];

    return MobileCapability(
      id: (j['id'] as num).toInt(),
      key: j['key'].toString(),
      title: j['title'].toString(),
      type: (j['type'] ?? 'record').toString(),
      description: j['description']?.toString(),
      icon: j['icon']?.toString(),
      config: config,
      definition: definition,
      runtimeManifest: rawRuntimeManifest is Map
          ? Map<String, dynamic>.from(rawRuntimeManifest)
          : <String, dynamic>{},
    );
  }

  static Map<String, dynamic>? _extractKernel(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);

    final version = int.tryParse(map['kernelVersion']?.toString() ?? '') ?? 0;
    if (version >= 3 && map['runtimeWorld'] is Map && map['possibilities'] is List) {
      return map;
    }

    final candidates = <dynamic>[
      map['responsibilityKernel'],
      map['kernel'],
      if (map['metadata'] is Map) (map['metadata'] as Map)['responsibilityKernel'],
      if (map['extension'] is Map) (map['extension'] as Map)['responsibilityKernel'],
      if (map['extension'] is Map && (map['extension'] as Map)['metadata'] is Map)
        ((map['extension'] as Map)['metadata'] as Map)['responsibilityKernel'],
      if (map['runtime'] is Map) (map['runtime'] as Map)['kernel'],
      if (map['app'] is Map && (map['app'] as Map)['config'] is Map)
        ((map['app'] as Map)['config'] as Map)['responsibilityKernel'],
    ];

    for (final candidate in candidates) {
      final found = _extractKernel(candidate);
      if (found != null) return found;
    }

    return null;
  }
}

library;

const int brixtaRuntimeContractVersion = 1;

const Map<String, String> _runtimeAliases = <String, String>{
  'string': 'text',
  'text': 'text',
  'short_text': 'text',
  'textarea': 'long_text',
  'longtext': 'long_text',
  'long_text': 'long_text',
  'int': 'integer',
  'integer': 'integer',
  'whole_number': 'integer',
  'number': 'decimal',
  'numeric': 'decimal',
  'float': 'decimal',
  'double': 'decimal',
  'decimal': 'decimal',
  'bool': 'boolean',
  'boolean': 'boolean',
  'date': 'date',
  'datetime': 'datetime',
  'date_time': 'datetime',
  'timestamp': 'datetime',
  'time_stamp': 'datetime',
  'select': 'single_select',
  'dropdown': 'single_select',
  'choice': 'single_select',
  'single_select': 'single_select',
  'singleselect': 'single_select',
  'multiselect': 'multi_select',
  'multi_select': 'multi_select',
  'multi_choice': 'multi_select',
  'ref': 'reference',
  'reference': 'reference',
  'entity': 'reference',
  'entity_reference': 'reference',
  'reference_picker': 'reference',
  'image': 'photo',
  'camera': 'photo',
  'camera_capture': 'photo',
  'selfie': 'photo',
  'photo': 'photo',
  'attachment': 'file',
  'document': 'file',
  'upload': 'file',
  'file': 'file',
  'gps': 'location',
  'geo': 'location',
  'geo_point': 'location',
  'geopoint': 'location',
  'geolocation': 'location',
  'coordinates': 'location',
  'location': 'location',
  'sign': 'signature',
  'signature': 'signature',
};

String _runtimeKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[\\s-]+'), '_');
String normalizeRuntimeFieldKind(String value) =>
    _runtimeAliases[_runtimeKey(value)] ?? _runtimeKey(value);

bool _looksFieldLike(Map<dynamic, dynamic> obj) =>
    obj.containsKey('fieldType') ||
    obj.containsKey('field_type') ||
    obj.containsKey('captureType') ||
    obj.containsKey('capture_type') ||
    obj.containsKey('required') ||
    obj.containsKey('label') ||
    obj.containsKey('options') ||
    obj.containsKey('placeholder') ||
    obj.containsKey('validation');

dynamic normalizeRuntimeContractJson(dynamic input) {
  dynamic visit(dynamic value) {
    if (value is List) return value.map<dynamic>(visit).toList(growable: false);
    if (value is! Map) return value;
    final src = Map<dynamic, dynamic>.from(value);
    final fieldLike = _looksFieldLike(src);
    final out = <dynamic, dynamic>{};
    src.forEach((dynamic rawKey, dynamic rawValue) {
      final key = rawKey.toString();
      var next = visit(rawValue);
      final explicit =
          key == 'fieldType' ||
          key == 'field_type' ||
          key == 'captureType' ||
          key == 'capture_type';
      final ambiguous = fieldLike && (key == 'type' || key == 'kind');
      if ((explicit || ambiguous) && next is String) {
        next = normalizeRuntimeFieldKind(next);
      }
      out[rawKey] = next;
    });
    return out;
  }

  return visit(input);
}

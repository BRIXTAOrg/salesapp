import 'package:flutter_test/flutter_test.dart';
import 'package:salesapp/core/models/mobile_capability.dart';

MobileCapability _capability({
  Map<String, dynamic> config = const {},
  Map<String, dynamic> definition = const {},
  Map<String, dynamic> runtimeManifest = const {},
}) {
  return MobileCapability.fromJson({
    'id': 101,
    'key': 'qa_contract_test',
    'title': 'QA Contract Test',
    'type': 'record',
    'description': 'Synthetic Responsibility used by automated QA.',
    'config': config,
    'definition': definition,
    'runtimeManifest': runtimeManifest,
  });
}

void main() {
  group('BRIXTA CMS → Flutter Responsibility contract', () {
    test('published CMS application overrides compatibility renderer '
        'without losing compatibility configuration', () {
      final capability = _capability(
        config: {
          'app': {
            'renderer': 'action_form_v1',
            'config': {
              'legacySetting': 'preserve-me',
              'sharedSetting': 'legacy',
            },
          },
        },

        runtimeManifest: {
          'kernelAvailable': true,
          'version': 12,
          'hash': 'qa-manifest-hash',
          'source': 'cms',

          'manifest': {
            'runtime': {
              'compiledDefinition': {
                'app': {
                  'renderer': 'brixta_ui_v1',

                  'config': {
                    'publishedSetting': 'cms-wins',

                    'sharedSetting': 'published',
                  },
                },
              },
            },
          },
        },
      );

      expect(capability.kernelAvailable, isTrue);

      expect(capability.manifestVersion, 12);

      expect(capability.manifestHash, 'qa-manifest-hash');

      expect(capability.manifestSource, 'cms');

      final app = capability.appDefinition;

      expect(app['renderer'], 'brixta_ui_v1');

      final config = Map<String, dynamic>.from(app['config'] as Map);

      // Compatibility data must survive.
      expect(config['legacySetting'], 'preserve-me');

      // Published CMS data must be present.
      expect(config['publishedSetting'], 'cms-wins');

      // Published CMS contract wins conflicts.
      expect(config['sharedSetting'], 'published');
    });

    test('Kernel uiDocument becomes brixta_ui_v1 '
        'when no explicit compiled app is published', () {
      final capability = _capability(
        config: {
          'app': {
            'config': {'compatibilitySetting': 'keep-this'},
          },
        },

        runtimeManifest: {
          'kernelAvailable': true,
          'version': 3,

          'manifest': {
            'kernel': {
              'kernelVersion': 3,

              'runtimeWorld': {},

              'possibilities': [],

              'metadata': {
                'ui': {
                  'uiDocument': {
                    'version': 1,
                    'engine': 'brixta_stac_v1',

                    'rootIds': ['title'],

                    'blocks': {
                      'title': {
                        'id': 'title',
                        'type': 'display.text',

                        'props': {'text': 'Hello from CMS'},
                      },
                    },
                  },
                },
              },
            },
          },
        },
      );

      final app = capability.appDefinition;

      expect(app['renderer'], 'brixta_ui_v1');

      final config = Map<String, dynamic>.from(app['config'] as Map);

      // Existing compatibility configuration remains.
      expect(config['compatibilitySetting'], 'keep-this');

      final document = Map<String, dynamic>.from(config['uiDocument'] as Map);

      expect(document['version'], 1);

      expect(document['engine'], 'brixta_stac_v1');

      expect(document['rootIds'], contains('title'));

      final presentation = Map<String, dynamic>.from(
        config['presentationContract'] as Map,
      );

      expect(presentation['id'], 'brixta-presentation-v2');

      expect(presentation['requiredRuntimeVersion'], 2);
    });

    test('invalid Kernel visual document is NOT promoted '
        'into brixta_ui_v1', () {
      final capability = _capability(
        config: {
          'app': {
            'renderer': 'action_form_v1',

            'config': {'safeFallback': true},
          },
        },

        runtimeManifest: {
          'kernelAvailable': true,

          'manifest': {
            'kernel': {
              'kernelVersion': 3,

              'runtimeWorld': {},

              'possibilities': [],

              'metadata': {
                'ui': {
                  'uiDocument': {'version': 999, 'engine': 'not_brixta'},
                },
              },
            },
          },
        },
      );

      final app = capability.appDefinition;

      // Invalid visual JSON cannot silently replace
      // the compatibility renderer.
      expect(app['renderer'], 'action_form_v1');

      final config = Map<String, dynamic>.from(app['config'] as Map);

      expect(config['safeFallback'], isTrue);

      expect(config.containsKey('uiDocument'), isFalse);
    });

    test('legacy Responsibility still renders '
        'without a Kernel manifest', () {
      final capability = _capability(
        config: {
          'app': {
            'renderer': 'action_form_v1',

            'config': {'submitLabel': 'Submit visit'},
          },

          'fields': [
            {'key': 'customer', 'label': 'Customer', 'type': 'text'},
          ],
        },
      );

      expect(capability.kernelAvailable, isFalse);

      expect(capability.hasGeneratedApp, isTrue);

      expect(capability.appDefinition['renderer'], 'action_form_v1');

      expect(capability.fields, hasLength(1));
    });

    test('incoming CMS field aliases are normalized '
        'before Flutter consumes them', () {
      final capability = _capability(
        definition: {
          'input': {
            'fields': [
              {
                'key': 'estimated_amount',

                'label': 'Estimated amount',

                // CMS/API aliases "number".
                // Runtime must normalize this.
                'fieldType': 'number',
              },

              {
                'key': 'customer_photo',

                'label': 'Customer photo',

                'fieldType': 'image',
              },

              {
                'key': 'site_location',

                'label': 'Site location',

                'fieldType': 'gps',
              },
            ],
          },
        },
      );

      expect(capability.fields, hasLength(3));

      expect(capability.fields[0]['fieldType'], 'decimal');

      expect(capability.fields[1]['fieldType'], 'photo');

      expect(capability.fields[2]['fieldType'], 'location');
    });
  });
}

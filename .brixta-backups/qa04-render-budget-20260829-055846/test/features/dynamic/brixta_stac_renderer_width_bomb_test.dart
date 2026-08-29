import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stac/stac.dart';

import '../../../lib/features/dynamic/presentation/brixta_stac_ui.dart';

Map<String, dynamic> _distinctWidthDocument(int count) {
  return {
    'version': 1,
    'engine': 'brixta_stac_v1',

    'rootIds': ['root'],

    'blocks': [
      {
        'id': 'root',
        'type': 'layout.column',
        'config': {'gap': 0},
        'children': [for (var i = 0; i < count; i++) 'leaf_$i'],
      },

      for (var i = 0; i < count; i++)
        {
          'id': 'leaf_$i',
          'type': 'display.text',
          'config': {'text': 'WIDTH_$i', 'size': 'small'},
        },
    ],
  };
}

Map<String, dynamic> _amplificationDocument(int references) {
  return {
    'version': 1,
    'engine': 'brixta_stac_v1',

    'rootIds': ['root'],

    // Only TWO blocks.
    //
    // The root references the same leaf thousands
    // of times.
    'blocks': [
      {
        'id': 'root',
        'type': 'layout.column',
        'config': {'gap': 0},
        'children': [for (var i = 0; i < references; i++) 'shared_leaf'],
      },
      {
        'id': 'shared_leaf',
        'type': 'display.text',
        'config': {'text': 'AMPLIFIED_LEAF', 'size': 'small'},
      },
    ],
  };
}

Future<Duration> _pumpDocument(
  WidgetTester tester,
  Map<String, dynamic> document,
) async {
  final stopwatch = Stopwatch()..start();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BrixtaStacUi(
          document: document,

          record: null,

          stateId: null,

          actions: const [],

          submittingActionKey: null,

          onRunAction: (_) async {},
        ),
      ),
    ),
  );

  await tester.pump();

  stopwatch.stop();

  final exception = tester.takeException();

  if (exception != null) {
    throw exception;
  }

  return stopwatch.elapsed;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    await Stac.initialize(parsers: const [BrixtaScreenParser()]);
  });

  testWidgets('QA04-A width baseline — 256 unique siblings', (tester) async {
    const count = 256;

    final elapsed = await _pumpDocument(tester, _distinctWidthDocument(count));

    debugPrint(
      'QA04_METRIC '
      'case=unique '
      'requested=$count '
      'elapsed_ms=${elapsed.inMilliseconds}',
    );

    expect(find.text('WIDTH_255'), findsOneWidget);
  });

  testWidgets('QA04-B width stress — 2048 unique siblings', (tester) async {
    const count = 2048;

    final elapsed = await _pumpDocument(tester, _distinctWidthDocument(count));

    debugPrint(
      'QA04_METRIC '
      'case=unique '
      'requested=$count '
      'elapsed_ms=${elapsed.inMilliseconds}',
    );

    expect(find.text('WIDTH_2047'), findsOneWidget);
  });

  testWidgets(
    'QA04-C adversarial repeated-reference amplification must be bounded',
    (tester) async {
      const requested = 10000;

      final document = _amplificationDocument(requested);

      // Prove the serialized graph is tiny.
      final blocks = document['blocks'] as List;

      expect(blocks.length, 2);

      final elapsed = await _pumpDocument(tester, document);

      final rendered = find.text('AMPLIFIED_LEAF').evaluate().length;

      debugPrint(
        'QA04_METRIC '
        'case=amplification '
        'serialized_blocks=${blocks.length} '
        'requested=$requested '
        'rendered=$rendered '
        'elapsed_ms=${elapsed.inMilliseconds}',
      );

      // IMPORTANT:
      //
      // We WANT this assertion.
      //
      // Rendering all 10,000 means there is no
      // total render-node / fan-out resource guard.
      expect(
        rendered,
        lessThan(requested),
        reason:
            'RESOURCE GUARD FAILURE: '
            'a 2-block CMS graph expanded into all '
            '$requested Flutter widgets. '
            'Depth protection alone does not stop '
            'breadth/fan-out amplification.',
      );
    },
  );
}

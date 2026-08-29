import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stac/stac.dart';

import 'package:salesapp/features/dynamic/presentation/brixta_stac_ui.dart';

const uxTargetMs = 1000;

Map<String, dynamic> _uniqueBomb(int count) {
  return {
    'version': 1,
    'engine': 'brixta_stac_v1',
    'rootIds': ['root'],
    'blocks': [
      {
        'id': 'root',
        'type': 'display.text',
        'config': {'text': 'SHOULD_NOT_RENDER'},
      },
      for (var i = 1; i < count; i++)
        {
          'id': 'unused_$i',
          'type': 'display.text',
          'config': {'text': 'UNUSED_$i'},
        },
    ],
  };
}

Map<String, dynamic> _twoMillionEntryBomb() {
  final root = <String, dynamic>{
    'id': 'root',
    'type': 'display.text',
    'config': {'text': 'SHOULD_NOT_RENDER'},
  };

  final garbage = <String, dynamic>{
    'id': 'garbage',
    'type': 'display.text',
    'config': {'text': 'GARBAGE'},
  };

  /*
   * Two million serialized LIST ENTRIES.
   *
   * We intentionally share one backing Map here.
   *
   * Reason:
   *
   * We want to measure whether the renderer WALKS the list,
   * not benchmark Dart allocating two million independent Maps.
   *
   * The network layer separately prevents a real two-million-
   * object JSON document from ever being decoded.
   */
  final blocks = List<Map<String, dynamic>>.filled(
    2000000,
    garbage,
    growable: false,
  );

  blocks[0] = root;

  return {
    'version': 1,
    'engine': 'brixta_stac_v1',
    'rootIds': ['root'],
    'blocks': blocks,
  };
}

Future<int> _render(WidgetTester tester, Map<String, dynamic> document) async {
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

  final error = tester.takeException();

  if (error != null) {
    throw error;
  }

  expect(
    find.text('This Responsibility cannot be displayed safely.'),
    findsOneWidget,
  );

  expect(find.text('SHOULD_NOT_RENDER'), findsNothing);

  return stopwatch.elapsedMilliseconds;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Stac.initialize(parsers: const [BrixtaScreenParser()]);
  });

  testWidgets('10001 real unique blocks reject within UX target', (
    tester,
  ) async {
    final document = _uniqueBomb(10001);

    final elapsed = await _render(tester, document);

    debugPrint(
      'PRE_STAC_GUARD_METRIC '
      'case=boundary '
      'size=10001 '
      'render_ms=$elapsed',
    );

    expect(
      elapsed,
      lessThan(uxTargetMs),
      reason:
          'Oversized CMS rejection itself must '
          'remain below the UX latency budget.',
    );
  });

  testWidgets('2000000 list entries reject in O(1) renderer time', (
    tester,
  ) async {
    final document = _twoMillionEntryBomb();

    final elapsed = await _render(tester, document);

    debugPrint(
      'PRE_STAC_GUARD_METRIC '
      'case=two_million '
      'size=2000000 '
      'render_ms=$elapsed',
    );

    expect(
      elapsed,
      lessThan(uxTargetMs),
      reason:
          'The renderer must not iterate a '
          'two-million-entry serialized block list.',
    );
  });
}

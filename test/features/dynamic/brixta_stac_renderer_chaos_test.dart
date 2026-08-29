import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stac/stac.dart';

import 'package:salesapp/features/dynamic/presentation/brixta_stac_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Stac.initialize(parsers: const [BrixtaScreenParser()]);
  });

  Future<void> pumpDocument(
    WidgetTester tester,
    Map<String, dynamic> document,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrixtaStacUi(
            document: document,
            record: const {'payload': <String, dynamic>{}},
            stateId: 'qa',
            actions: const [],
            submittingActionKey: null,
            onRunAction: (_) async {},
          ),
        ),
      ),
    );

    await tester.pump();

    final exception = tester.takeException();

    expect(
      exception,
      isNull,
      reason: 'CMS-authored UI must never crash the employee renderer.',
    );
  }

  Map<String, dynamic> depthDocument(int layoutDepth) {
    final blocks = <Map<String, dynamic>>[];

    for (var index = 0; index < layoutDepth; index++) {
      blocks.add({
        'id': 'node-$index',
        'type': 'layout.column',
        'children': [
          index == layoutDepth - 1 ? 'terminal' : 'node-${index + 1}',
        ],
        'config': {'gap': 0},
      });
    }

    blocks.add({
      'id': 'terminal',
      'type': 'display.text',
      'config': {'text': 'SURVIVED DEEP GRAPH'},
    });

    return {
      'version': 1,
      'engine': 'brixta_stac_v1',
      'rootIds': ['node-0'],
      'blocks': blocks,
    };
  }

  testWidgets('QA03 control — normal CMS document renders', (tester) async {
    await pumpDocument(tester, {
      'version': 1,
      'engine': 'brixta_stac_v1',
      'rootIds': ['root'],
      'blocks': [
        {
          'id': 'root',
          'type': 'layout.column',
          'children': ['hello'],
          'config': {'gap': 12},
        },
        {
          'id': 'hello',
          'type': 'display.text',
          'config': {'text': 'BRIXTA QA CONTROL'},
        },
      ],
    });

    expect(find.text('BRIXTA QA CONTROL'), findsOneWidget);
  });

  testWidgets('QA03 malformed — missing child reference does not crash', (
    tester,
  ) async {
    await pumpDocument(tester, {
      'version': 1,
      'engine': 'brixta_stac_v1',
      'rootIds': ['root'],
      'blocks': [
        {
          'id': 'root',
          'type': 'layout.column',
          'children': ['does-not-exist', 'valid'],
        },
        {
          'id': 'valid',
          'type': 'display.text',
          'config': {'text': 'SURVIVED MISSING CHILD'},
        },
      ],
    });

    expect(find.text('SURVIVED MISSING CHILD'), findsOneWidget);
  });

  testWidgets('QA03 malformed — unknown block type does not crash', (
    tester,
  ) async {
    await pumpDocument(tester, {
      'version': 1,
      'engine': 'brixta_stac_v1',
      'rootIds': ['root'],
      'blocks': [
        {
          'id': 'root',
          'type': 'evil.this_block_does_not_exist',
          'config': {'whatever': true},
        },
      ],
    });
  });

  testWidgets('QA03 hostile — self-referencing layout terminates safely', (
    tester,
  ) async {
    await pumpDocument(tester, {
      'version': 1,
      'engine': 'brixta_stac_v1',
      'rootIds': ['loop'],
      'blocks': [
        {
          'id': 'loop',
          'type': 'layout.column',
          'children': ['loop'],
        },
      ],
    });
  });

  testWidgets('QA03 hostile — two-node cycle terminates safely', (
    tester,
  ) async {
    await pumpDocument(tester, {
      'version': 1,
      'engine': 'brixta_stac_v1',
      'rootIds': ['A'],
      'blocks': [
        {
          'id': 'A',
          'type': 'layout.column',
          'children': ['B'],
        },
        {
          'id': 'B',
          'type': 'layout.stack',
          'children': ['A'],
        },
      ],
    });
  });

  /*
   * IMPORTANT BOUNDARY CONTRACT
   *
   * Renderer budget:
   *
   *     _maxRenderDepth = 64
   *
   * Root is depth 0.
   *
   * 63 layout nodes:
   *
   *     node-0       depth 0
   *     ...
   *     node-62      depth 62
   *     terminal     depth 63
   *
   * This is valid.
   */
  testWidgets('QA03 boundary — depth 63 renders normally', (tester) async {
    await pumpDocument(tester, depthDocument(63));

    expect(find.text('SURVIVED DEEP GRAPH'), findsOneWidget);

    expect(
      find.text('This Responsibility cannot be displayed safely.'),
      findsNothing,
    );
  });

  /*
   * 64 layout nodes put terminal at depth 64.
   *
   * That crosses the declared device safety budget.
   *
   * The CORRECT behavior is therefore NOT:
   *
   *     "render it anyway"
   *
   * The correct behavior is:
   *
   *     fail closed
   *     no Flutter exception
   *     no recursive stack explosion
   *     show explicit safety UI
   */
  testWidgets('QA03 boundary — depth 64 fails closed safely', (tester) async {
    await pumpDocument(tester, depthDocument(64));

    expect(find.text('SURVIVED DEEP GRAPH'), findsNothing);

    expect(
      find.text('This Responsibility cannot be displayed safely.'),
      findsOneWidget,
    );

    expect(
      find.text(
        'Its published interface exceeds the device render safety limit.',
      ),
      findsOneWidget,
    );
  });

  /*
   * This replaces the OLD contradictory QA contract.
   *
   * The old test demanded that depth 250 actually render.
   *
   * That contradicted _maxRenderDepth = 64.
   *
   * Depth 250 remains a valuable hostile-input test,
   * but its success criterion is now SAFE REJECTION.
   */
  testWidgets('QA03 hostile — depth 250 is rejected without crashing', (
    tester,
  ) async {
    final stopwatch = Stopwatch()..start();

    await pumpDocument(tester, depthDocument(250));

    stopwatch.stop();

    debugPrint(
      'QA03_METRIC '
      'case=depth_rejection '
      'requested_depth=250 '
      'elapsed_ms=${stopwatch.elapsedMilliseconds}',
    );

    expect(find.text('SURVIVED DEEP GRAPH'), findsNothing);

    expect(
      find.text('This Responsibility cannot be displayed safely.'),
      findsOneWidget,
    );
  });
}

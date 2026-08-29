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

  testWidgets('QA03 hostile — self-referencing layout does not crash', (
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

  testWidgets('QA03 hostile — two-node cycle does not crash', (tester) async {
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

  testWidgets('QA03 stress — deeply nested CMS layout does not crash', (
    tester,
  ) async {
    const depth = 250;

    final blocks = <Map<String, dynamic>>[];

    for (var index = 0; index < depth; index++) {
      blocks.add({
        'id': 'node-$index',
        'type': 'layout.column',
        'children': [index == depth - 1 ? 'terminal' : 'node-${index + 1}'],
        'config': {'gap': 0},
      });
    }

    blocks.add({
      'id': 'terminal',
      'type': 'display.text',
      'config': {'text': 'SURVIVED DEEP GRAPH'},
    });

    await pumpDocument(tester, {
      'version': 1,
      'engine': 'brixta_stac_v1',
      'rootIds': ['node-0'],
      'blocks': blocks,
    });

    expect(find.text('SURVIVED DEEP GRAPH'), findsOneWidget);
  });
}

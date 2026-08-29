import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stac/stac.dart';

import 'package:salesapp/features/dynamic/presentation/brixta_stac_ui.dart';

Map<String, dynamic> _document(int totalBlocks) {
  assert(totalBlocks >= 1);

  return {
    'version': 1,
    'engine': 'brixta_stac_v1',
    'rootIds': ['root'],
    'blocks': [
      {
        'id': 'root',
        'type': 'display.text',
        'config': {'text': 'SERIALIZED_ENVELOPE_ROOT'},
      },
      for (var i = 1; i < totalBlocks; i++)
        {
          'id': 'unused_$i',
          'type': 'display.text',
          'config': {'text': 'UNUSED_$i'},
        },
    ],
  };
}

Future<void> _pump(WidgetTester tester, Map<String, dynamic> document) async {
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

  final error = tester.takeException();

  if (error != null) {
    throw error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Stac.initialize(parsers: const [BrixtaScreenParser()]);
  });

  testWidgets('serialized envelope accepts exactly 10000 blocks', (
    tester,
  ) async {
    await _pump(tester, _document(10000));

    expect(find.text('SERIALIZED_ENVELOPE_ROOT'), findsOneWidget);

    expect(
      find.text('This Responsibility cannot be displayed safely.'),
      findsNothing,
    );
  });

  testWidgets('serialized envelope rejects 10001 before rendering', (
    tester,
  ) async {
    await _pump(tester, _document(10001));

    expect(find.text('SERIALIZED_ENVELOPE_ROOT'), findsNothing);

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
}

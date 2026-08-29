import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stac/stac.dart';

import 'package:salesapp/features/dynamic/presentation/brixta_stac_ui.dart';

Map<String, dynamic> animatedDocument(int count) {
  return {
    'version': 1,
    'engine': 'brixta_stac_v1',
    'rootIds': ['root'],
    'blocks': [
      {
        'id': 'root',
        'type': 'layout.column',
        'children': [for (var i = 0; i < count; i++) 'leaf_$i'],
        'config': {'gap': 0},
      },
      for (var i = 0; i < count; i++)
        {
          'id': 'leaf_$i',
          'type': 'display.text',
          'config': {'text': 'ANIMATED_$i'},
          'animation': {'preset': 'fade', 'durationMs': 350},
        },
    ],
  };
}

Map<String, dynamic> rawDocument(Map<String, dynamic> raw) {
  return {
    'version': 1,
    'engine': 'brixta_stac_v1',
    'rootIds': ['raw'],
    'blocks': [
      {
        'id': 'raw',
        'type': 'stac.raw',
        'config': {'json': raw},
      },
    ],
  };
}

Widget harness(Map<String, dynamic> document) {
  return MaterialApp(
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
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Stac.initialize(parsers: const [BrixtaScreenParser()]);
  });

  testWidgets('513 animations render statically', (tester) async {
    await tester.pumpWidget(harness(animatedDocument(513)));

    await tester.pump();

    expect(find.text('ANIMATED_0'), findsOneWidget);

    expect(find.byType(Animate), findsNothing);

    expect(
      find.text('This Responsibility cannot be displayed safely.'),
      findsNothing,
    );
  });

  testWidgets('1025 animations reject safely', (tester) async {
    await tester.pumpWidget(harness(animatedDocument(1025)));

    await tester.pump();

    expect(
      find.text('This Responsibility cannot be displayed safely.'),
      findsOneWidget,
    );

    expect(find.text('ANIMATED_0'), findsNothing);
  });

  testWidgets('raw STAC fanout 257 rejects', (tester) async {
    final raw = <String, dynamic>{
      'type': 'Column',
      'children': [
        for (var i = 0; i < 257; i++) {'type': 'Text', 'data': 'RAW_$i'},
      ],
    };

    await tester.pumpWidget(harness(rawDocument(raw)));

    await tester.pump();

    expect(
      find.text('This Responsibility cannot be displayed safely.'),
      findsOneWidget,
    );
  });

  testWidgets('raw STAC excessive depth rejects', (tester) async {
    Map<String, dynamic> raw = {'type': 'Text', 'data': 'DEEP'};

    for (var i = 0; i < 40; i++) {
      raw = {'type': 'Container', 'child': raw};
    }

    await tester.pumpWidget(harness(rawDocument(raw)));

    await tester.pump();

    expect(
      find.text('This Responsibility cannot be displayed safely.'),
      findsOneWidget,
    );
  });

  testWidgets('raw STAC giant string rejects', (tester) async {
    final raw = <String, dynamic>{'type': 'Text', 'data': 'X' * (600 * 1024)};

    await tester.pumpWidget(harness(rawDocument(raw)));

    await tester.pump();

    expect(
      find.text('This Responsibility cannot be displayed safely.'),
      findsOneWidget,
    );
  });
}

// BRIXTA_ROUND2_RESOURCE_ESCAPE_V1

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stac/stac.dart';

import 'package:salesapp/features/dynamic/presentation/brixta_stac_ui.dart';

const stressCase = String.fromEnvironment(
  'BRIXTA_STRESS_CASE',
  defaultValue: 'raw_width',
);

const stressSize = int.fromEnvironment('BRIXTA_STRESS_SIZE', defaultValue: 256);

Map<String, dynamic> _wrapRaw(Map<String, dynamic> raw) {
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

Map<String, dynamic> _rawWidthDocument(int count) {
  return _wrapRaw({
    'type': 'column',
    'mainAxisSize': 'min',
    'children': [
      for (var i = 0; i < count; i++)
        {'type': 'text', 'data': i == count - 1 ? 'RAW_LAST_$i' : 'RAW_$i'},
    ],
  });
}

Map<String, dynamic> _rawDepthDocument(int depth) {
  Map<String, dynamic> current = {'type': 'text', 'data': 'RAW_DEPTH_TERMINAL'};

  for (var i = 0; i < depth; i++) {
    current = {
      'type': 'column',
      'mainAxisSize': 'min',
      'children': [current],
    };
  }

  return _wrapRaw(current);
}

Map<String, dynamic> _animatedDocument(int count) {
  return {
    'version': 1,
    'engine': 'brixta_stac_v1',
    'rootIds': ['root'],
    'blocks': [
      {
        'id': 'root',
        'type': 'layout.column',
        'config': {'gap': 0},
        'children': [for (var i = 0; i < count; i++) 'animated_$i'],
      },
      for (var i = 0; i < count; i++)
        {
          'id': 'animated_$i',
          'type': 'display.text',
          'config': {
            'text': i == count - 1 ? 'ANIMATED_LAST_$i' : 'ANIMATED_$i',
            'size': 'small',
          },
          'animation': {'preset': 'fade_scale', 'durationMs': 1000},
        },
    ],
  };
}

Map<String, dynamic> _serializedBombDocument(int unreachable) {
  final padding = 'X' * 128;

  return {
    'version': 1,
    'engine': 'brixta_stac_v1',
    'rootIds': ['root'],
    'blocks': [
      {
        'id': 'root',
        'type': 'display.text',
        'config': {'text': 'SERIALIZED_ROOT_SURVIVED'},
      },
      for (var i = 0; i < unreachable; i++)
        {
          'id': 'unreachable_$i',
          'type': 'display.text',
          'config': {'text': 'UNREACHABLE_$i-$padding'},
        },
    ],
  };
}

Future<Duration> _pump(
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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Stac.initialize(parsers: const [BrixtaScreenParser()]);
  });

  switch (stressCase) {
    case 'raw_width':
      testWidgets('ROUND2 raw STAC width $stressSize', (tester) async {
        final elapsed = await _pump(tester, _rawWidthDocument(stressSize));

        expect(find.text('RAW_LAST_${stressSize - 1}'), findsOneWidget);

        debugPrint(
          'ROUND2_METRIC '
          'case=raw_width '
          'size=$stressSize '
          'elapsed_ms=${elapsed.inMilliseconds}',
        );
      });
      break;

    case 'raw_depth':
      testWidgets('ROUND2 raw STAC depth $stressSize', (tester) async {
        final elapsed = await _pump(tester, _rawDepthDocument(stressSize));

        expect(find.text('RAW_DEPTH_TERMINAL'), findsOneWidget);

        debugPrint(
          'ROUND2_METRIC '
          'case=raw_depth '
          'size=$stressSize '
          'elapsed_ms=${elapsed.inMilliseconds}',
        );
      });
      break;

    case 'animated_width':
      testWidgets('ROUND2 animated BRIXTA width $stressSize', (tester) async {
        final stopwatch = Stopwatch()..start();

        await _pump(tester, _animatedDocument(stressSize));

        // Drive ~0.5 seconds worth of animation frames.
        //
        // Flutter widget tests do not measure GPU raster cost,
        // but this DOES hammer ticker/update/build processing.
        for (var frame = 0; frame < 30; frame++) {
          await tester.pump(const Duration(milliseconds: 16));

          final exception = tester.takeException();

          if (exception != null) {
            throw exception;
          }
        }

        stopwatch.stop();

        expect(find.text('ANIMATED_LAST_${stressSize - 1}'), findsOneWidget);

        debugPrint(
          'ROUND2_METRIC '
          'case=animated_width '
          'size=$stressSize '
          'elapsed_ms=${stopwatch.elapsedMilliseconds}',
        );
      });
      break;

    case 'serialized':
      testWidgets('ROUND2 serialized CMS bomb $stressSize', (tester) async {
        final elapsed = await _pump(
          tester,
          _serializedBombDocument(stressSize),
        );

        expect(find.text('SERIALIZED_ROOT_SURVIVED'), findsOneWidget);

        debugPrint(
          'ROUND2_METRIC '
          'case=serialized '
          'size=$stressSize '
          'elapsed_ms=${elapsed.inMilliseconds}',
        );
      });
      break;

    default:
      test('unknown BRIXTA stress case', () {
        fail('Unknown BRIXTA_STRESS_CASE=$stressCase');
      });
  }
}

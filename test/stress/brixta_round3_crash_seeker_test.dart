// BRIXTA_ROUND3_CRASH_SEEKER_V1

import 'dart:isolate';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stac/stac.dart';

import 'package:salesapp/features/dynamic/presentation/brixta_stac_ui.dart';

const stressCase = String.fromEnvironment(
  'BRIXTA_STRESS_CASE',
  defaultValue: 'raw_width',
);

const stressSize = int.fromEnvironment('BRIXTA_STRESS_SIZE', defaultValue: 256);

Map<String, dynamic> wrapRaw(Map<String, dynamic> raw) {
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

Map<String, dynamic> rawWidth(int count) {
  return wrapRaw({
    'type': 'column',
    'mainAxisSize': 'min',
    'children': [
      for (var i = 0; i < count; i++)
        {'type': 'text', 'data': i == count - 1 ? 'RAW_TERMINAL_$i' : 'RAW_$i'},
    ],
  });
}

Map<String, dynamic> rawDepth(int depth) {
  Map<String, dynamic> node = {'type': 'text', 'data': 'DEPTH_TERMINAL'};

  for (var i = 0; i < depth; i++) {
    node = {
      'type': 'column',
      'mainAxisSize': 'min',
      'children': [node],
    };
  }

  return wrapRaw(node);
}

Map<String, dynamic> animationStorm(int count) {
  return {
    'version': 1,
    'engine': 'brixta_stac_v1',
    'rootIds': ['root'],
    'blocks': [
      {
        'id': 'root',
        'type': 'layout.column',
        'config': {'gap': 0},
        'children': [for (var i = 0; i < count; i++) 'animation_$i'],
      },
      for (var i = 0; i < count; i++)
        {
          'id': 'animation_$i',
          'type': 'display.text',
          'config': {
            'text': i == count - 1 ? 'ANIMATION_TERMINAL_$i' : 'A_$i',
            'size': 'small',
          },
          'animation': {'preset': 'fade_scale', 'durationMs': 10000},
        },
    ],
  };
}

Map<String, dynamic> serializedBomb(int count) {
  final payload = 'Z' * 256;

  return {
    'version': 1,
    'engine': 'brixta_stac_v1',
    'rootIds': ['root'],
    'blocks': [
      {
        'id': 'root',
        'type': 'display.text',
        'config': {'text': 'SERIALIZED_SURVIVED'},
      },
      for (var i = 0; i < count; i++)
        {
          'id': 'garbage_$i',
          'type': 'display.text',
          'config': {'text': '$i-$payload'},
        },
    ],
  };
}

Future<Duration> pumpDocument(
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

  final error = tester.takeException();

  if (error != null) {
    throw error;
  }

  return stopwatch.elapsed;
}

int burnCpu(int milliseconds) {
  final end = DateTime.now().microsecondsSinceEpoch + milliseconds * 1000;

  var x = 0x12345678;

  while (DateTime.now().microsecondsSinceEpoch < end) {
    x ^= (x << 13);
    x ^= (x >> 17);
    x ^= (x << 5);

    x = x & 0x7fffffff;

    for (var i = 0; i < 2000; i++) {
      x = ((x * 1103515245) + 12345) & 0x7fffffff;
    }
  }

  return x;
}

Future<int> cpuSaturation(int seconds) async {
  final workers = Platform.numberOfProcessors;

  final stopwatch = Stopwatch()..start();

  final results = await Future.wait([
    for (var i = 0; i < workers; i++)
      Isolate.run(() => burnCpu(seconds * 1000)),
  ]);

  stopwatch.stop();

  var checksum = 0;

  for (final result in results) {
    checksum ^= result;
  }

  debugPrint(
    'ROUND3_METRIC '
    'case=cpu '
    'workers=$workers '
    'seconds=$seconds '
    'elapsed_ms=${stopwatch.elapsedMilliseconds} '
    'checksum=$checksum',
  );

  return checksum;
}

List<Uint8List> allocateRealRam(int megabytes) {
  const chunkMb = 8;
  const bytesPerMb = 1024 * 1024;

  final held = <Uint8List>[];

  var remaining = megabytes;
  var pattern = 1;

  while (remaining > 0) {
    final thisChunkMb = remaining >= chunkMb ? chunkMb : remaining;

    final block = Uint8List(thisChunkMb * bytesPerMb);

    /*
     * Touch every 4 KiB page.
     *
     * Without this, the OS may lazily reserve virtual
     * memory without committing physical RAM.
     */
    for (var offset = 0; offset < block.length; offset += 4096) {
      block[offset] = pattern;
      pattern = (pattern + 17) & 0xff;
    }

    held.add(block);

    remaining -= thisChunkMb;
  }

  return held;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Stac.initialize(parsers: const [BrixtaScreenParser()]);
  });

  switch (stressCase) {
    case 'raw_width':
      testWidgets('ROUND3 raw STAC width $stressSize', (tester) async {
        final elapsed = await pumpDocument(tester, rawWidth(stressSize));

        expect(find.text('RAW_TERMINAL_${stressSize - 1}'), findsOneWidget);

        debugPrint(
          'ROUND3_METRIC '
          'case=raw_width '
          'size=$stressSize '
          'elapsed_ms=${elapsed.inMilliseconds}',
        );
      });
      break;

    case 'raw_depth':
      testWidgets('ROUND3 raw STAC depth $stressSize', (tester) async {
        final elapsed = await pumpDocument(tester, rawDepth(stressSize));

        expect(find.text('DEPTH_TERMINAL'), findsOneWidget);

        debugPrint(
          'ROUND3_METRIC '
          'case=raw_depth '
          'size=$stressSize '
          'elapsed_ms=${elapsed.inMilliseconds}',
        );
      });
      break;

    case 'animation':
      testWidgets('ROUND3 animation storm $stressSize', (tester) async {
        final stopwatch = Stopwatch()..start();

        await pumpDocument(tester, animationStorm(stressSize));

        /*
           * Roughly two seconds worth of frames.
           */
        for (var i = 0; i < 120; i++) {
          await tester.pump(const Duration(milliseconds: 16));

          final error = tester.takeException();

          if (error != null) {
            throw error;
          }
        }

        stopwatch.stop();

        expect(
          find.text('ANIMATION_TERMINAL_${stressSize - 1}'),
          findsOneWidget,
        );

        debugPrint(
          'ROUND3_METRIC '
          'case=animation '
          'size=$stressSize '
          'elapsed_ms=${stopwatch.elapsedMilliseconds}',
        );
      });
      break;

    case 'serialized':
      testWidgets('ROUND3 serialized bomb $stressSize', (tester) async {
        final elapsed = await pumpDocument(tester, serializedBomb(stressSize));

        expect(find.text('SERIALIZED_SURVIVED'), findsOneWidget);

        debugPrint(
          'ROUND3_METRIC '
          'case=serialized '
          'size=$stressSize '
          'elapsed_ms=${elapsed.inMilliseconds}',
        );
      });
      break;

    case 'ram':
      testWidgets('ROUND3 RAM flood ${stressSize}MB', (tester) async {
        final stopwatch = Stopwatch()..start();

        final memory = allocateRealRam(stressSize);

        /*
           * Build Flutter UI while the RAM stays pinned.
           */
        await pumpDocument(tester, rawWidth(2048));

        await tester.pump(const Duration(milliseconds: 100));

        stopwatch.stop();

        var checksum = 0;

        for (final block in memory) {
          checksum += block[block.length ~/ 2];
        }

        debugPrint(
          'ROUND3_METRIC '
          'case=ram '
          'size_mb=$stressSize '
          'chunks=${memory.length} '
          'elapsed_ms=${stopwatch.elapsedMilliseconds} '
          'checksum=$checksum',
        );

        expect(find.text('RAW_TERMINAL_2047'), findsOneWidget);

        expect(memory.isNotEmpty, true);
      });
      break;

    case 'cpu':
      test('ROUND3 CPU saturation $stressSize seconds', () async {
        final checksum = await cpuSaturation(stressSize);

        expect(checksum, isA<int>());
      });
      break;

    default:
      test('invalid stress case', () {
        fail(
          'Unknown stress case: '
          '$stressCase',
        );
      });
  }
}

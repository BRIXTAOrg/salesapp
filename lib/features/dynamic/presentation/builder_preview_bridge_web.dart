// BRIXTA_UNIVERSAL_INTEGRATION_V1
// Web-only postMessage bridge for the CMS Flutter preview.
// Uses the current Dart web interop stack; no dart:html dependency.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'builder_preview_bridge_stub.dart';

class BuilderPreviewBridge {
  StreamSubscription<web.MessageEvent>? _subscription;

  void start(BuilderPreviewMessageHandler handler) {
    _subscription?.cancel();

    _subscription = web.window.onMessage.listen((event) {
      final raw = event.data.dartify();
      if (raw is! String) return;

      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          handler(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // The parent window may carry unrelated postMessage traffic.
        // Only valid BRIXTA JSON packets are consumed.
      }
    });

    announceReady();
  }

  void announceReady() {
    web.window.parent?.postMessage(
      jsonEncode({'type': 'brixta.preview.ready'}).toJS,
      '*'.toJS,
    );
  }

  void selectBlock(String blockId) {
    web.window.parent?.postMessage(
      jsonEncode({'type': 'brixta.preview.select', 'blockId': blockId}).toJS,
      '*'.toJS,
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

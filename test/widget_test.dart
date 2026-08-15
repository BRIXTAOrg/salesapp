import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:kamdhenu/app/brixta_app.dart';
import 'package:kamdhenu/core/config/tenant_config.dart';
import 'package:kamdhenu/core/services/auth/mock_auth_gateway.dart';
import 'package:kamdhenu/core/services/connectivity/connectivity_gateway.dart';
import 'package:kamdhenu/core/services/sync/sync_gateway.dart';
import 'package:kamdhenu/core/session/app_session_controller.dart';

void main() {
  testWidgets(
    'BRIXTA employee login screen loads',
    (WidgetTester tester) async {
      final connectivityGateway = TestConnectivityGateway();
      final syncGateway = TestSyncGateway();

      final controller = AppSessionController(
        tenant: TenantConfig.demo,
        authGateway: MockAuthGateway(),
        connectivityGateway: connectivityGateway,
        syncGateway: syncGateway,
      );

      await tester.pumpWidget(
        BrixtaApp(controller: controller),
      );

      await tester.pumpAndSettle();

      expect(find.text('Employee Login'), findsOneWidget);
      expect(find.text('Employee ID'), findsOneWidget);
      expect(find.text('Password / PIN'), findsOneWidget);
      expect(find.text('LOGIN'), findsOneWidget);

      controller.dispose();
      await connectivityGateway.dispose();
      await syncGateway.dispose();
    },
  );
}

class TestConnectivityGateway implements ConnectivityGateway {
  final StreamController<ConnectivityStateValue> _controller =
      StreamController<ConnectivityStateValue>.broadcast();

  @override
  ConnectivityStateValue get current => ConnectivityStateValue.online;

  @override
  Stream<ConnectivityStateValue> get changes => _controller.stream;

  Future<void> dispose() async {
    await _controller.close();
  }
}

class TestSyncGateway implements SyncGateway {
  final StreamController<SyncSnapshot> _controller =
      StreamController<SyncSnapshot>.broadcast();

  SyncSnapshot _current = SyncSnapshot.clean;

  @override
  SyncSnapshot get current => _current;

  @override
  Stream<SyncSnapshot> get changes => _controller.stream;

  @override
  Future<void> syncNow() async {
    _current = SyncSnapshot(
      pendingCount: _current.pendingCount,
      isSyncing: true,
      conflictCount: _current.conflictCount,
    );

    _controller.add(_current);

    await Future<void>.delayed(Duration.zero);

    _current = SyncSnapshot.clean;
    _controller.add(_current);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
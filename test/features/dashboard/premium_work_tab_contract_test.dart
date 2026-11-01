import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salesapp/core/config/tenant_config.dart';
import 'package:salesapp/core/models/auth_session.dart';
import 'package:salesapp/core/models/mobile_capability.dart';
import 'package:salesapp/core/services/auth/auth_gateway.dart';
import 'package:salesapp/core/services/connectivity/connectivity_gateway.dart';
import 'package:salesapp/core/services/sync/sync_gateway.dart';
import 'package:salesapp/core/session/app_session_controller.dart';
import 'package:salesapp/features/dashboard/presentation/premium_work_tab.dart';


void main() {
  group('BRIXTA CRM-first Work contract', () {
    testWidgets('empty work shows PJP and approval guidance, not legacy filters',
        (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller: controller));
      await tester.pump();

      expect(find.text('Visits, tasks & approvals'), findsOneWidget);
      expect(find.text('Approvals'), findsOneWidget);
      expect(find.text('No approval requests need your decision right now.'),
          findsOneWidget);
      expect(find.text('Search responsibilities'), findsNothing);
      expect(find.text('Responsibilities'), findsNothing);
      expect(find.text('To do'), findsNothing);
      expect(find.text('Decisions'), findsNothing);
      expect(find.text('Waiting'), findsNothing);
    });

    testWidgets('legacy ready queue is not silently presented as PJP work',
        (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      final item = <String, dynamic>{
        'id': 'legacy-work-001',
        'title': 'Inspect construction site',
        'kind': 'assigned_work',
      };
      Map<String, dynamic>? opened;
      await tester.pumpWidget(_app(
        controller: controller,
        readyWork: [item],
        onReadyTap: (value) => opened = value,
      ));
      await tester.pump();

      // Migration boundary: legacy Responsibility work must not masquerade
      // as a published, server-backed CRM/PJP assignment.
      expect(find.text('Inspect construction site'), findsNothing);
      expect(find.text('Visits, tasks & approvals'), findsOneWidget);
      expect(opened, isNull);
    });

    testWidgets('approvals remain visible and forward the exact request',
        (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      final approval = <String, dynamic>{
        'id': 'kernel:decision-001',
        'title': 'Approve dealer discount',
        'workflowName': 'Dealer approval',
        'status': 'pending',
      };
      Map<String, dynamic>? reviewed;
      await tester.pumpWidget(_app(
        controller: controller,
        approvals: [approval],
        onApprovalTap: (value) => reviewed = value,
      ));
      await tester.pump();

      expect(find.text('Approvals'), findsOneWidget);
      expect(find.text('Approve dealer discount'), findsOneWidget);
      expect(find.text('Dealer approval'), findsOneWidget);
      await tester.ensureVisible(find.text('Approve dealer discount'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve dealer discount'));
      await tester.pump();
      expect(reviewed, same(approval),
          reason: 'The same authorized approval request must reach the handler.');
    });

    testWidgets('legacy blocked queue is not exposed as a new action',
        (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      final blocked = <String, dynamic>{
        'id': 'legacy-blocked-001',
        'title': 'Submit expense report',
        'reason': 'Waiting for manager review',
      };
      await tester.pumpWidget(_app(
        controller: controller,
        blockedWork: [blocked],
      ));
      await tester.pump();
      expect(find.text('Submit expense report'), findsNothing);
      expect(find.text('Waiting for manager review'), findsNothing);
      expect(find.text('Waiting'), findsNothing);
    });

    testWidgets('legacy Responsibility modules do not appear in CRM-first Work',
        (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(
        controller: controller,
        modules: [
          _module(id: 1, key: 'attendance', title: 'Attendance'),
          _module(id: 2, key: 'journey', title: 'Journey Tracker'),
        ],
      ));
      await tester.pump();
      expect(find.text('Attendance'), findsNothing);
      expect(find.text('Journey Tracker'), findsNothing);
      expect(find.text('Visits, tasks & approvals'), findsOneWidget);
      expect(find.textContaining('Open FIELD and select the CRM module'),
          findsOneWidget);
    });
  });
}

Widget _app({
  required AppSessionController
      controller,
  List<MobileCapability>
      modules = const [],
  List<Map<String, dynamic>>
      readyWork = const [],
  List<Map<String, dynamic>>
      blockedWork = const [],
  List<Map<String, dynamic>>
      approvals = const [],
  ValueChanged<Map<String, dynamic>>?
      onReadyTap,
  ValueChanged<Map<String, dynamic>>?
      onApprovalTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PremiumWorkTab(
        controller:
            controller,
        modules:
            modules,
        readyWork:
            readyWork,
        blockedWork:
            blockedWork,
        approvals:
            approvals,
        onRefresh:
            () async {},
        onCapabilityTap:
            (_) {},
        onReadyTap:
            onReadyTap ??
            (_) {},
        onApprovalTap:
            onApprovalTap ??
            (_) {},
      ),
    ),
  );
}


AppSessionController _controller() {
  return AppSessionController(
    tenant:
        TenantConfig.demo,
    authGateway:
        _FakeAuthGateway(),
    connectivityGateway:
        _FakeConnectivityGateway(),
    syncGateway:
        _FakeSyncGateway(),
  );
}


MobileCapability _module({
  required int id,
  required String key,
  required String title,
}) {
  return MobileCapability(
    id: id,
    key: key,
    title: title,
    type: 'record',
    description:
        '$title Responsibility',
    config:
        const {},
    definition:
        const {},
  );
}


class _FakeConnectivityGateway
    implements ConnectivityGateway {
  @override
  ConnectivityStateValue
  get current =>
      ConnectivityStateValue.online;

  @override
  Stream<ConnectivityStateValue>
  get changes =>
      Stream<ConnectivityStateValue>
          .empty();
}


class _FakeSyncGateway
    implements SyncGateway {
  @override
  SyncSnapshot
  get current =>
      SyncSnapshot.clean;

  @override
  Stream<SyncSnapshot>
  get changes =>
      Stream<SyncSnapshot>.empty();

  @override
  Future<void> syncNow() async {}
}


class _FakeAuthGateway
    implements AuthGateway {
  @override
  Future<AuthSession> login(
    LoginRequest request,
  ) async {
    throw UnsupportedError(
      'Authentication is outside this widget contract test.',
    );
  }

  @override
  Future<AuthSession> refresh(
    AuthSession current,
  ) async {
    return current;
  }

  @override
  Future<void> logout() async {}
}

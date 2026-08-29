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
  group(
    'BRIXTA Work Inbox contract',
    () {
      testWidgets(
        'empty queues create zero operational clutter',
        (tester) async {
          final controller =
              _controller();

          addTearDown(
            controller.dispose,
          );

          await tester.pumpWidget(
            _app(
              controller:
                  controller,
            ),
          );

          await tester.pump();

          // Empty operational concepts should not occupy
          // employee attention.
          expect(
            find.text('To do'),
            findsNothing,
          );

          expect(
            find.text('Decisions'),
            findsNothing,
          );

          expect(
            find.text('Waiting'),
            findsNothing,
          );

          // Search remains a real primary function.
          expect(
            find.text(
              'Search responsibilities',
            ),
            findsOneWidget,
          );
        },
      );


      testWidgets(
        'To do appears only when actionable work exists and forwards exact item',
        (tester) async {
          final controller =
              _controller();

          addTearDown(
            controller.dispose,
          );

          final workItem =
              <String, dynamic>{
            'id': 'work-001',
            'kind':
                'assigned_work',
            'title':
                'Inspect construction site',
            'status':
                'assigned',
            'priority':
                'high',
          };

          Map<String, dynamic>?
              opened;

          await tester.pumpWidget(
            _app(
              controller:
                  controller,
              readyWork: [
                workItem,
              ],
              onReadyTap:
                  (item) {
                opened = item;
              },
            ),
          );

          await tester.pump();

          // User-facing terminology should be To do,
          // not the internal/runtime term Ready.
          expect(
            find.text('To do'),
            findsOneWidget,
          );

          expect(
            find.text('Ready'),
            findsNothing,
          );

          await tester.tap(
            find.text('To do'),
          );

          await tester.pumpAndSettle();

          expect(
            find.text(
              'Inspect construction site',
            ),
            findsOneWidget,
          );

          await tester.tap(
            find.text(
              'Inspect construction site',
            ),
          );

          // Queue cards intentionally await their small
          // interaction feedback before forwarding.
          await tester.pump(
            const Duration(
              milliseconds: 250,
            ),
          );

          expect(
            opened,
            same(workItem),
            reason:
                'The exact backend work item must reach '
                'onReadyTap. No synthetic replacement.',
          );
        },
      );


      testWidgets(
        'Decisions appears only for pending decisions and forwards exact approval',
        (tester) async {
          final controller =
              _controller();

          addTearDown(
            controller.dispose,
          );

          final approval =
              <String, dynamic>{
            'id':
                'kernel:decision-001',
            'title':
                'Approve dealer discount',
            'workflowName':
                'Dealer approval',
            'status':
                'pending',
          };

          Map<String, dynamic>?
              reviewed;

          await tester.pumpWidget(
            _app(
              controller:
                  controller,
              approvals: [
                approval,
              ],
              onApprovalTap:
                  (item) {
                reviewed = item;
              },
            ),
          );

          await tester.pump();

          expect(
            find.text('Decisions'),
            findsOneWidget,
          );

          await tester.tap(
            find.text('Decisions'),
          );

          await tester.pumpAndSettle();

          expect(
            find.text(
              'Approve dealer discount',
            ),
            findsOneWidget,
          );

          expect(
            find.text(
              'Dealer approval',
            ),
            findsOneWidget,
          );

          await tester.tap(
            find.text(
              'Approve dealer discount',
            ),
          );

          await tester.pump(
            const Duration(
              milliseconds: 250,
            ),
          );

          expect(
            reviewed,
            same(approval),
            reason:
                'The exact approval/Kernel decision must '
                'reach onApprovalTap.',
          );
        },
      );


      testWidgets(
        'Waiting is contextual and not actionable',
        (tester) async {
          final controller =
              _controller();

          addTearDown(
            controller.dispose,
          );

          final blocked =
              <String, dynamic>{
            'id':
                'blocked-001',
            'title':
                'Submit expense report',
            'reason':
                'Waiting for manager review',
          };

          await tester.pumpWidget(
            _app(
              controller:
                  controller,
              blockedWork: [
                blocked,
              ],
            ),
          );

          await tester.pump();

          expect(
            find.text('Waiting'),
            findsOneWidget,
          );

          await tester.tap(
            find.text('Waiting'),
          );

          await tester.pumpAndSettle();

          expect(
            find.text(
              'Submit expense report',
            ),
            findsOneWidget,
          );

          expect(
            find.text(
              'Waiting for manager review',
            ),
            findsOneWidget,
          );

          // Waiting work is information, not an executable
          // action. Its card should expose the lock affordance.
          expect(
            find.byIcon(
              Icons.lock_outline_rounded,
            ),
            findsWidgets,
          );
        },
      );


      testWidgets(
        'Responsibility search filters the actual assigned modules',
        (tester) async {
          final controller =
              _controller();

          addTearDown(
            controller.dispose,
          );

          final attendance =
              _module(
            id: 1,
            key: 'attendance',
            title: 'Attendance',
          );

          final journey =
              _module(
            id: 2,
            key: 'journey',
            title: 'Journey Tracker',
          );

          await tester.pumpWidget(
            _app(
              controller:
                  controller,
              modules: [
                attendance,
                journey,
              ],
            ),
          );

          await tester.pump();

          expect(
            find.text('Attendance'),
            findsOneWidget,
          );

          expect(
            find.text(
              'Journey Tracker',
            ),
            findsWidgets,
          );

          final search =
              find.byType(
            TextField,
          );

          expect(
            search,
            findsOneWidget,
          );

          await tester.enterText(
            search,
            'attendance',
          );

          await tester.pumpAndSettle();

          expect(
            find.text('Attendance'),
            findsOneWidget,
          );

          expect(
            find.text(
              'Journey Tracker',
            ),
            findsNothing,
          );

          await tester.enterText(
            search,
            'THIS_DOES_NOT_EXIST',
          );

          await tester.pumpAndSettle();

          expect(
            find.text(
              'No matching Responsibility',
            ),
            findsOneWidget,
          );
        },
      );
    },
  );
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

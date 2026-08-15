import 'package:flutter_test/flutter_test.dart';

import 'package:kamdhenu/app/brixta_app.dart';
import 'package:kamdhenu/core/config/tenant_config.dart';
import 'package:kamdhenu/core/services/auth/mock_auth_gateway.dart';
import 'package:kamdhenu/core/services/connectivity/mock_connectivity_gateway.dart';
import 'package:kamdhenu/core/services/sync/mock_sync_gateway.dart';
import 'package:kamdhenu/core/session/app_session_controller.dart';

void main() {
  testWidgets('BRIXTA employee login screen loads', (WidgetTester tester) async {
    final controller = AppSessionController(
      tenant: TenantConfig.demo,
      authGateway: MockAuthGateway(),
      connectivityGateway: MockConnectivityGateway(),
      syncGateway: MockSyncGateway(),
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
  });
}
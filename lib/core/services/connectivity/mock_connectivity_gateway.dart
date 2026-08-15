import 'connectivity_gateway.dart';

class MockConnectivityGateway implements ConnectivityGateway {
  @override
  ConnectivityStateValue get current => ConnectivityStateValue.online;

  @override
  Stream<ConnectivityStateValue> get changes =>
      Stream<ConnectivityStateValue>.value(ConnectivityStateValue.online);
}

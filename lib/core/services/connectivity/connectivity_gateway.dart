enum ConnectivityStateValue {
  online,
  offline,
}

abstract interface class ConnectivityGateway {
  ConnectivityStateValue get current;
  Stream<ConnectivityStateValue> get changes;
}

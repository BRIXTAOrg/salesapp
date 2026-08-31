// BRIXTA_UNIVERSAL_INTEGRATION_V1

typedef BuilderPreviewMessageHandler =
    void Function(Map<String, dynamic> message);

class BuilderPreviewBridge {
  void start(BuilderPreviewMessageHandler handler) {}
  void announceReady() {}
  void dispose() {}
}

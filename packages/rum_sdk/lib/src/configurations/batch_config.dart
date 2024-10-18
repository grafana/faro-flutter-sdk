class BatchConfig{
  Duration sendTimeout;
  int payloadItemLimit;
  bool enabled;

  BatchConfig({this.sendTimeout = const Duration(milliseconds: 300), this.payloadItemLimit = 30, this.enabled = true});
}

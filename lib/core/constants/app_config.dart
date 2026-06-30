enum ProcessingTiming {
  immediate,
  later,
}

class AppConfig {
  static const String baseUrl = '';
  static ProcessingTiming processingTiming = ProcessingTiming.immediate;
}

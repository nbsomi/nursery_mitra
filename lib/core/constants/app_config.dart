enum ProcessingTiming {
  immediate,
  later,
}

class AppConfig {
  static const String baseUrl = 'https://api.nurserymitra.in/api';
  static ProcessingTiming processingTiming = ProcessingTiming.immediate;
}

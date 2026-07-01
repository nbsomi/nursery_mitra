import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_config.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final String processingMode = prefs.getString('processingMode') ?? 'Batch Review';
  if (processingMode == 'Batch Review') {
    AppConfig.processingTiming = ProcessingTiming.later;
  } else {
    AppConfig.processingTiming = ProcessingTiming.immediate;
  }

  runApp(const NurseryMitraApp());
}

class NurseryMitraApp extends StatelessWidget {
  const NurseryMitraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nursery Mitra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  // Initialize bindings before launching the app structure
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NurseryMitraApp());
}

class NurseryMitraApp extends StatelessWidget {
  const NurseryMitraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nursery Mitra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
      ),
      // Bootstrap the operational dashboard as the primary surface
      home: const HomeScreen(),
    );
  }
}

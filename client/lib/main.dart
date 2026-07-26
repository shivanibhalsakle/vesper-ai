import 'package:flutter/material.dart';

import 'screens/session_setup_screen.dart';

void main() {
  runApp(const VesperApp());
}

class VesperApp extends StatelessWidget {
  const VesperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vesper',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const SessionSetupScreen(),
    );
  }
}

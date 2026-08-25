import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const ChristmasLightApp());
}

class ChristmasLightApp extends StatelessWidget {
  const ChristmasLightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Actuel RGB Light',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

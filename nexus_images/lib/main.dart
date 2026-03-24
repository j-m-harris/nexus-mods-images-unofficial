import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  runApp(const NexusImagesApp());
}

class NexusImagesApp extends StatelessWidget {
  const NexusImagesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus Mods Image Browser',
      debugShowCheckedModeBanner: false,
      theme: nexusTheme(),
      home: const HomeScreen(),
    );
  }
}

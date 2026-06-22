import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/favourites_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = 50 * 1024 * 1024
    ..maximumSize = 80;
  await FavouritesService.instance.init();
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

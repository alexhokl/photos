import 'package:flutter/material.dart';
import 'package:photos/widgets/photo_grid.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photos',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.cyan)),
      home: const HomePage(title: 'Photos'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: const PhotoGrid(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          if (index == 0) {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.phone_android),
            selectedIcon: Icon(Icons.phone_android),
            label: 'Device',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.cloud_outlined,
              color: Theme.of(context).disabledColor,
            ),
            selectedIcon: const Icon(Icons.cloud),
            label: 'Cloud',
            enabled: false,
          ),
        ],
      ),
    );
  }
}

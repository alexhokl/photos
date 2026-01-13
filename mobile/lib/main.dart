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
  int _selectedPhotoCount = 0;
  final GlobalKey<PhotoGridState> _photoGridKey = GlobalKey<PhotoGridState>();

  void _onSelectionChanged(int count) {
    setState(() {
      _selectedPhotoCount = count;
    });
  }

  void _onMenuAction(PhotoGridAction action) {
    _photoGridKey.currentState?.performAction(action);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          PopupMenuButton<PhotoGridAction>(
            enabled: _selectedPhotoCount > 0,
            icon: Icon(
              Icons.more_vert,
              color: _selectedPhotoCount > 0
                  ? null
                  : Theme.of(context).disabledColor,
            ),
            onSelected: _onMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: PhotoGridAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Delete'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                enabled: false,
                value: PhotoGridAction.upload,
                child: ListTile(
                  leading: Icon(Icons.cloud_upload),
                  title: Text('Upload'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: PhotoGrid(
        key: _photoGridKey,
        onSelectionChanged: _onSelectionChanged,
      ),
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

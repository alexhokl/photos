import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/widgets/cloud_photo_grid.dart';
import 'package:photos/widgets/photo_grid.dart';
import 'package:photos/widgets/photo_viewer.dart';
import 'package:photos/widgets/settings_page.dart';

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
  int _deviceSelectedCount = 0;
  int _cloudSelectedCount = 0;
  final GlobalKey<PhotoGridState> _photoGridKey = GlobalKey<PhotoGridState>();
  final GlobalKey<CloudPhotoGridState> _cloudPhotoGridKey =
      GlobalKey<CloudPhotoGridState>();

  void _onDeviceSelectionChanged(int count) {
    setState(() {
      _deviceSelectedCount = count;
    });
  }

  void _onCloudSelectionChanged(int count) {
    setState(() {
      _cloudSelectedCount = count;
    });
  }

  void _onDeviceMenuAction(PhotoGridAction action) {
    _photoGridKey.currentState?.performAction(action);
  }

  void _onCloudMenuAction(CloudPhotoGridAction action) {
    _cloudPhotoGridKey.currentState?.performAction(action);
  }

  Future<void> _onPhotoTap(AssetEntity photo, int index) async {
    final gridState = _photoGridKey.currentState;
    if (gridState == null) return;

    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PhotoViewer(assets: gridState.photos, initialIndex: index),
      ),
    );
    if (deleted == true) {
      _photoGridKey.currentState?.removePhoto(photo.id);
    }
  }

  List<Widget> _buildAppBarActions() {
    if (_selectedIndex == 0) {
      return [
        PopupMenuButton<PhotoGridAction>(
          enabled: _deviceSelectedCount > 0,
          icon: Icon(
            Icons.more_vert,
            color: _deviceSelectedCount > 0
                ? null
                : Theme.of(context).disabledColor,
          ),
          onSelected: _onDeviceMenuAction,
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
              value: PhotoGridAction.upload,
              child: ListTile(
                leading: Icon(Icons.cloud_upload),
                title: Text('Upload'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ];
    } else if (_selectedIndex == 1) {
      return [
        PopupMenuButton<CloudPhotoGridAction>(
          enabled: _cloudSelectedCount > 0,
          icon: Icon(
            Icons.more_vert,
            color: _cloudSelectedCount > 0
                ? null
                : Theme.of(context).disabledColor,
          ),
          onSelected: _onCloudMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: CloudPhotoGridAction.delete,
              child: ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: CloudPhotoGridAction.copy,
              child: ListTile(
                leading: Icon(Icons.copy),
                title: Text('Copy to...'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: CloudPhotoGridAction.move,
              child: ListTile(
                leading: Icon(Icons.drive_file_move),
                title: Text('Move to...'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: _buildAppBarActions(),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          PhotoGrid(
            key: _photoGridKey,
            onSelectionChanged: _onDeviceSelectionChanged,
            onPhotoTap: _onPhotoTap,
          ),
          CloudPhotoGrid(
            key: _cloudPhotoGridKey,
            onSelectionChanged: _onCloudSelectionChanged,
            isActive: _selectedIndex == 1,
          ),
          SettingsPage(isActive: _selectedIndex == 2),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.phone_android),
            selectedIcon: Icon(Icons.phone_android),
            label: 'Device',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Cloud',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

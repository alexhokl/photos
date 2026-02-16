import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/services/library_service.dart';
import 'package:photos/widgets/cloud_photo_grid.dart';
import 'package:photos/widgets/markdown_viewer_page.dart';
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
  bool _isDeviceLoading = true;
  String? _deviceLoadError;
  PhotoLoadProgress? _deviceLoadProgress;
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

  void _onDeviceLoadingChanged(bool isLoading) {
    setState(() {
      _isDeviceLoading = isLoading;
    });
  }

  void _onDeviceLoadError(String? error) {
    setState(() {
      _deviceLoadError = error;
    });
  }

  void _onDeviceLoadProgress(PhotoLoadProgress progress) {
    setState(() {
      _deviceLoadProgress = progress;
    });
  }

  void _onRetryDeviceLoading() {
    _photoGridKey.currentState?.retryLoading();
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

    final deletedPhotoId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PhotoViewer(assets: gridState.photos, initialIndex: index),
      ),
    );
    if (deletedPhotoId != null) {
      _photoGridKey.currentState?.removePhoto(deletedPhotoId);
    }
  }

  Future<void> _onNotesPressed() async {
    final cloudGridState = _cloudPhotoGridKey.currentState;
    if (cloudGridState == null) return;

    final currentPrefix = cloudGridState.currentPrefix;

    LibraryService? libraryService;
    try {
      final config = await BackendConfig.load();
      libraryService = LibraryService(host: config.host, port: config.port);

      final markdown = await libraryService.getMarkdown(currentPrefix);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MarkdownViewerPage(markdown: markdown),
        ),
      );
    } on LibraryException catch (e) {
      if (!mounted) return;
      // Check if it's a NOT_FOUND error (no markdown configured)
      if (e.grpcError?.code == StatusCode.notFound) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No notes found in this directory')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notes: ${e.message}')),
        );
      }
    } finally {
      await libraryService?.dispose();
    }
  }

  List<Widget> _buildAppBarActions() {
    if (_selectedIndex == 0) {
      return [
        if (_deviceLoadError != null)
          Tooltip(
            message: _deviceLoadError!,
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.red),
              onPressed: _onRetryDeviceLoading,
            ),
          )
        else if (_isDeviceLoading && _deviceLoadProgress != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Center(
              child: Text(
                '${_deviceLoadProgress!.loaded}/${_deviceLoadProgress!.total}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          )
        else if (_isDeviceLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
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
              value: PhotoGridAction.upload,
              child: ListTile(
                leading: Icon(Icons.cloud_upload),
                title: Text('Upload'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: PhotoGridAction.uploadTo,
              child: ListTile(
                leading: Icon(Icons.cloud_upload_outlined),
                title: Text('Upload to...'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: PhotoGridAction.delete,
              child: ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ];
    } else if (_selectedIndex == 1) {
      return [
        IconButton(icon: const Icon(Icons.note), onPressed: _onNotesPressed),
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
            onLoadingChanged: _onDeviceLoadingChanged,
            onLoadError: _onDeviceLoadError,
            onLoadProgress: _onDeviceLoadProgress,
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

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoGrid extends StatefulWidget {
  final void Function(int selectedCount)? onSelectionChanged;

  const PhotoGrid({super.key, this.onSelectionChanged});

  @override
  State<PhotoGrid> createState() => PhotoGridState();
}

enum PhotoGridAction { delete, upload }

class PhotoGridState extends State<PhotoGrid> {
  List<AssetEntity> _photos = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  String? _errorMessage;
  final Set<String> _selectedPhotoIds = {};

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadPhotos();
  }

  Future<void> _requestPermissionAndLoadPhotos() async {
    final PermissionState permission =
        await PhotoManager.requestPermissionExtend();

    if (permission.isAuth) {
      setState(() {
        _hasPermission = true;
      });
      await _loadPhotos();
    } else {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
        _errorMessage = permission == PermissionState.denied
            ? 'Photo access denied. Please grant permission in Settings.'
            : 'Limited photo access. Please grant full access in Settings.';
      });
    }
  }

  Future<void> _loadPhotos() async {
    try {
      // Get all photo albums
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );

      if (albums.isEmpty) {
        setState(() {
          _photos = [];
          _isLoading = false;
        });
        return;
      }

      // Get photos from the first album (usually "Recent" or "All Photos")
      final List<AssetEntity> photos = await albums.first.getAssetListRange(
        start: 0,
        end: 100, // Load first 100 photos
      );

      setState(() {
        _photos = photos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load photos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openSettings() async {
    await PhotoManager.openSetting();
  }

  void _toggleSelection(AssetEntity photo) {
    setState(() {
      if (_selectedPhotoIds.contains(photo.id)) {
        _selectedPhotoIds.remove(photo.id);
      } else {
        _selectedPhotoIds.add(photo.id);
      }
    });
    widget.onSelectionChanged?.call(_selectedPhotoIds.length);
  }

  void _clearSelection() {
    setState(() {
      _selectedPhotoIds.clear();
    });
    widget.onSelectionChanged?.call(0);
  }

  int get selectedCount => _selectedPhotoIds.length;

  Future<void> performAction(PhotoGridAction action) async {
    switch (action) {
      case PhotoGridAction.delete:
        await _deleteSelectedPhotos();
        break;
      case PhotoGridAction.upload:
        _uploadSelectedPhotos();
        break;
    }
  }

  List<AssetEntity> get _selectedPhotos {
    return _photos.where((p) => _selectedPhotoIds.contains(p.id)).toList();
  }

  Future<void> _deleteSelectedPhotos() async {
    final selectedPhotos = _selectedPhotos;
    if (selectedPhotos.isEmpty) return;

    final result = await PhotoManager.editor.deleteWithIds(
      selectedPhotos.map((p) => p.id).toList(),
    );

    if (result.isNotEmpty) {
      setState(() {
        _photos.removeWhere((p) => _selectedPhotoIds.contains(p.id));
        _selectedPhotoIds.clear();
      });
      widget.onSelectionChanged?.call(0);
    }
  }

  void _uploadSelectedPhotos() {
    // TODO: Implement upload functionality
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasPermission || _errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Unable to access photos',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openSettings,
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    if (_photos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No photos found'),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return PhotoThumbnail(
          asset: photo,
          isSelected: _selectedPhotoIds.contains(photo.id),
          onTap: () => _toggleSelection(photo),
        );
      },
    );
  }
}

class PhotoThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final bool isSelected;
  final VoidCallback? onTap;

  const PhotoThumbnail({
    super.key,
    required this.asset,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.data != null) {
                return Image.memory(snapshot.data!, fit: BoxFit.cover);
              }
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          ),
          if (isSelected)
            Container(
              color: Colors.blue.withValues(alpha: 0.3),
              child: const Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.check_circle, color: Colors.blue, size: 24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

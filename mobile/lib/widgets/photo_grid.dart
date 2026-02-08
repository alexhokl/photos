import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/services/upload_service.dart';
import 'package:photos/widgets/settings_page.dart';

class PhotoGrid extends StatefulWidget {
  final void Function(int selectedCount)? onSelectionChanged;
  final void Function(AssetEntity photo, int index)? onPhotoTap;

  const PhotoGrid({super.key, this.onSelectionChanged, this.onPhotoTap});

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
  bool _isSelectionMode = false;

  // Pagination state
  static const int _pageSize = 50;
  int _currentPage = 0;
  bool _hasMorePhotos = true;
  bool _isLoadingMore = false;
  AssetPathEntity? _primaryAlbum;
  final ScrollController _scrollController = ScrollController();

  bool get isSelectionMode => _isSelectionMode;

  /// Returns an unmodifiable view of the current photos list.
  List<AssetEntity> get photos => List.unmodifiable(_photos);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _requestPermissionAndLoadPhotos();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePhotos();
    }
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
          _hasMorePhotos = false;
        });
        return;
      }

      // Cache the primary album for pagination
      _primaryAlbum = albums.first;
      final totalCount = await _primaryAlbum!.assetCountAsync;

      // Get photos from the first album (usually "Recent" or "All Photos")
      final List<AssetEntity> photos = await _primaryAlbum!.getAssetListRange(
        start: 0,
        end: _pageSize,
      );

      setState(() {
        _photos = photos;
        _currentPage = 1;
        _hasMorePhotos = photos.length < totalCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load photos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMorePhotos() async {
    if (_isLoadingMore || !_hasMorePhotos || _primaryAlbum == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final start = _currentPage * _pageSize;
      final totalCount = await _primaryAlbum!.assetCountAsync;

      final List<AssetEntity> morePhotos = await _primaryAlbum!
          .getAssetListRange(start: start, end: start + _pageSize);

      setState(() {
        _photos.addAll(morePhotos);
        _currentPage++;
        _hasMorePhotos = _photos.length < totalCount;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
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
        // Exit selection mode if no photos are selected
        if (_selectedPhotoIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPhotoIds.add(photo.id);
      }
    });
    widget.onSelectionChanged?.call(_selectedPhotoIds.length);
  }

  void _enterSelectionMode(AssetEntity photo) {
    if (_isSelectionMode) return;
    setState(() {
      _isSelectionMode = true;
      _selectedPhotoIds.add(photo.id);
    });
    widget.onSelectionChanged?.call(_selectedPhotoIds.length);
  }

  void _clearSelection() {
    setState(() {
      _selectedPhotoIds.clear();
      _isSelectionMode = false;
    });
    widget.onSelectionChanged?.call(0);
  }

  int get selectedCount => _selectedPhotoIds.length;

  void removePhoto(String photoId) {
    setState(() {
      _photos.removeWhere((p) => p.id == photoId);
      _selectedPhotoIds.remove(photoId);
      if (_selectedPhotoIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
    widget.onSelectionChanged?.call(_selectedPhotoIds.length);
  }

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
        _isSelectionMode = false;
      });
      widget.onSelectionChanged?.call(0);
    }
  }

  Future<void> _uploadSelectedPhotos() async {
    final selectedPhotos = _selectedPhotos;
    if (selectedPhotos.isEmpty) return;

    final config = await BackendConfig.load();
    final uploadService = UploadService(host: config.host, port: config.port);

    try {
      // Show upload progress dialog
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _UploadProgressDialog(
          photos: selectedPhotos,
          uploadService: uploadService,
          onComplete: (results) {
            Navigator.pop(dialogContext);
            _showUploadResults(results);
          },
        ),
      );
    } finally {
      await uploadService.dispose();
    }
  }

  void _showUploadResults(List<UploadResult> results) {
    final successCount = results.where((r) => r.success).length;
    final failureCount = results.length - successCount;

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failureCount == 0
              ? 'Successfully uploaded $successCount photo${successCount == 1 ? '' : 's'}'
              : 'Uploaded $successCount, failed $failureCount',
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    // Clear selection after upload
    _clearSelection();
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
      controller: _scrollController,
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _photos.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the end
        if (index >= _photos.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final photo = _photos[index];
        return PhotoThumbnail(
          asset: photo,
          isSelected: _selectedPhotoIds.contains(photo.id),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(photo);
            } else {
              widget.onPhotoTap?.call(photo, index);
            }
          },
          onLongPress: () => _enterSelectionMode(photo),
        );
      },
    );
  }
}

class PhotoThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PhotoThumbnail({
    super.key,
    required this.asset,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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

/// Dialog that shows upload progress
class _UploadProgressDialog extends StatefulWidget {
  final List<AssetEntity> photos;
  final UploadService uploadService;
  final void Function(List<UploadResult> results) onComplete;

  const _UploadProgressDialog({
    required this.photos,
    required this.uploadService,
    required this.onComplete,
  });

  @override
  State<_UploadProgressDialog> createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<_UploadProgressDialog> {
  int _completed = 0;
  int _total = 0;
  String _currentFileName = '';

  @override
  void initState() {
    super.initState();
    _total = widget.photos.length;
    _startUpload();
  }

  Future<void> _startUpload() async {
    final results = await widget.uploadService.uploadPhotos(
      widget.photos,
      onProgress: (completed, total) {
        if (mounted) {
          setState(() {
            _completed = completed;
            _currentFileName = completed < widget.photos.length
                ? widget.photos[completed].title ?? 'Photo ${completed + 1}'
                : '';
          });
        }
      },
    );
    widget.onComplete(results);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total > 0 ? _completed / _total : 0.0;

    return AlertDialog(
      title: const Text('Uploading Photos'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 16),
          Text('$_completed of $_total'),
          if (_currentFileName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _currentFileName,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

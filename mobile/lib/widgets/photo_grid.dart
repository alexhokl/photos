import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/services/library_service.dart';
import 'package:photos/services/upload_service.dart';
import 'package:photos/widgets/settings_page.dart';

/// Represents a group of photos taken on the same date.
class PhotoDateGroup {
  final DateTime date;
  final List<AssetEntity> photos;

  PhotoDateGroup({required this.date, required this.photos});

  /// Returns the date formatted for display (e.g., "February 15, 2026").
  String get formattedDate => DateFormat.yMMMMd().format(date);

  /// Returns the day of week (e.g., "Saturday").
  String get dayOfWeek => DateFormat.EEEE().format(date);
}

/// Represents the progress of loading photos.
class PhotoLoadProgress {
  final int loaded;
  final int total;

  const PhotoLoadProgress({required this.loaded, required this.total});

  /// Returns true if all photos have been loaded.
  bool get isComplete => loaded >= total;

  /// Returns the progress as a value between 0.0 and 1.0.
  double get progress => total > 0 ? loaded / total : 0.0;
}

class PhotoGrid extends StatefulWidget {
  final void Function(int selectedCount)? onSelectionChanged;
  final void Function(AssetEntity photo, int index)? onPhotoTap;
  final void Function(bool isLoading)? onLoadingChanged;
  final void Function(String? error)? onLoadError;
  final void Function(PhotoLoadProgress progress)? onLoadProgress;

  const PhotoGrid({
    super.key,
    this.onSelectionChanged,
    this.onPhotoTap,
    this.onLoadingChanged,
    this.onLoadError,
    this.onLoadProgress,
  });

  @override
  State<PhotoGrid> createState() => PhotoGridState();
}

enum PhotoGridAction { delete, upload, uploadTo }

/// Notifier for photo selection state that allows individual thumbnails
/// to listen only to their own selection status changes.
class PhotoSelectionNotifier extends ChangeNotifier {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  bool get isSelectionMode => _isSelectionMode;
  int get selectedCount => _selectedIds.length;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  bool isSelected(String photoId) => _selectedIds.contains(photoId);

  void toggleSelection(String photoId) {
    if (_selectedIds.contains(photoId)) {
      _selectedIds.remove(photoId);
      if (_selectedIds.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedIds.add(photoId);
    }
    notifyListeners();
  }

  void enterSelectionMode(String photoId) {
    if (_isSelectionMode) return;
    _isSelectionMode = true;
    _selectedIds.add(photoId);
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  void removePhotoId(String photoId) {
    _selectedIds.remove(photoId);
    if (_selectedIds.isEmpty) {
      _isSelectionMode = false;
    }
    notifyListeners();
  }
}

class PhotoGridState extends State<PhotoGrid> {
  List<AssetEntity> _photos = [];
  List<PhotoDateGroup> _photoGroups = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  String? _errorMessage;
  final PhotoSelectionNotifier _selectionNotifier = PhotoSelectionNotifier();

  // Pagination state
  static const int _pageSize = 50;
  int _currentPage = 0;
  bool _hasMorePhotos = true;
  bool _isLoadingAll = false;
  AssetPathEntity? _primaryAlbum;
  final ScrollController _scrollController = ScrollController();

  // Error handling state
  String? _loadError;

  // Progress tracking
  int _totalPhotoCount = 0;

  bool get isSelectionMode => _selectionNotifier.isSelectionMode;

  /// Returns true if there was an error loading photos.
  bool get hasLoadError => _loadError != null;

  /// Returns the current load error message, if any.
  String? get loadError => _loadError;

  /// Returns the total number of photos to be loaded.
  int get totalPhotoCount => _totalPhotoCount;

  /// Returns an unmodifiable view of the current photos list.
  List<AssetEntity> get photos => List.unmodifiable(_photos);

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadPhotos();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _selectionNotifier.dispose();
    super.dispose();
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
          _photoGroups = [];
          _isLoading = false;
          _hasMorePhotos = false;
          _totalPhotoCount = 0;
        });
        widget.onLoadingChanged?.call(false);
        widget.onLoadProgress?.call(
          const PhotoLoadProgress(loaded: 0, total: 0),
        );
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
        _photoGroups = _groupPhotosByDate(photos);
        _currentPage = 1;
        _hasMorePhotos = photos.length < totalCount;
        _isLoading = false;
        _isLoadingAll = _hasMorePhotos;
        _totalPhotoCount = totalCount;
      });

      // Notify parent about loading state and progress
      widget.onLoadingChanged?.call(_hasMorePhotos);
      widget.onLoadProgress?.call(
        PhotoLoadProgress(loaded: photos.length, total: totalCount),
      );

      // Continue loading all remaining photos
      if (_hasMorePhotos) {
        _loadAllRemainingPhotos();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load photos: $e';
        _isLoading = false;
        _isLoadingAll = false;
      });
      widget.onLoadingChanged?.call(false);
    }
  }

  /// Groups photos by their creation date (local timezone).
  /// Returns a list sorted in reverse chronological order.
  List<PhotoDateGroup> _groupPhotosByDate(List<AssetEntity> photos) {
    final Map<DateTime, List<AssetEntity>> groups = {};

    for (final photo in photos) {
      // Use createDateTime which is in local timezone
      final date = photo.createDateTime;
      // Normalize to date-only (midnight)
      final dateOnly = DateTime(date.year, date.month, date.day);

      groups.putIfAbsent(dateOnly, () => []);
      groups[dateOnly]!.add(photo);
    }

    // Sort dates in reverse chronological order
    final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return sortedDates
        .map((date) => PhotoDateGroup(date: date, photos: groups[date]!))
        .toList();
  }

  /// Merges new photos into existing date groups, maintaining reverse chronological order.
  void _mergePhotosIntoGroups(List<AssetEntity> newPhotos) {
    final Map<DateTime, List<AssetEntity>> existingGroups = {};

    // Build map from existing groups
    for (final group in _photoGroups) {
      existingGroups[group.date] = List.from(group.photos);
    }

    // Add new photos to appropriate groups
    for (final photo in newPhotos) {
      final date = photo.createDateTime;
      final dateOnly = DateTime(date.year, date.month, date.day);

      existingGroups.putIfAbsent(dateOnly, () => []);
      existingGroups[dateOnly]!.add(photo);
    }

    // Sort dates in reverse chronological order
    final sortedDates = existingGroups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    _photoGroups = sortedDates
        .map(
          (date) => PhotoDateGroup(date: date, photos: existingGroups[date]!),
        )
        .toList();
  }

  /// Continuously loads all remaining photos in batches until complete.
  Future<void> _loadAllRemainingPhotos() async {
    if (!_hasMorePhotos || _primaryAlbum == null) return;

    // Clear any previous error when starting/retrying
    if (_loadError != null) {
      setState(() {
        _loadError = null;
      });
      widget.onLoadError?.call(null);
    }

    while (_hasMorePhotos && _primaryAlbum != null) {
      try {
        final start = _currentPage * _pageSize;
        final totalCount = await _primaryAlbum!.assetCountAsync;

        final List<AssetEntity> morePhotos = await _primaryAlbum!
            .getAssetListRange(start: start, end: start + _pageSize);

        if (!mounted) return;

        setState(() {
          _photos.addAll(morePhotos);
          _mergePhotosIntoGroups(morePhotos);
          _currentPage++;
          _hasMorePhotos = _photos.length < totalCount;
          _totalPhotoCount = totalCount;
        });

        // Report progress after each batch
        widget.onLoadProgress?.call(
          PhotoLoadProgress(loaded: _photos.length, total: totalCount),
        );
      } catch (e) {
        // Track error and stop loading
        if (mounted) {
          setState(() {
            _loadError = 'Failed to load photos: $e';
            _isLoadingAll = false;
          });
          widget.onLoadError?.call(_loadError);
          widget.onLoadingChanged?.call(false);
        }
        return;
      }
    }

    // All photos loaded successfully, notify parent
    if (mounted) {
      setState(() {
        _isLoadingAll = false;
      });
      widget.onLoadingChanged?.call(false);
    }
  }

  /// Retries loading photos after an error.
  /// Returns true if retry was started, false if there's nothing to retry.
  bool retryLoading() {
    if (_loadError == null || !_hasMorePhotos) {
      return false;
    }

    setState(() {
      _isLoadingAll = true;
    });
    widget.onLoadingChanged?.call(true);
    _loadAllRemainingPhotos();
    return true;
  }

  Future<void> _openSettings() async {
    await PhotoManager.openSetting();
  }

  void _toggleSelection(AssetEntity photo) {
    _selectionNotifier.toggleSelection(photo.id);
    widget.onSelectionChanged?.call(_selectionNotifier.selectedCount);
  }

  void _enterSelectionMode(AssetEntity photo) {
    _selectionNotifier.enterSelectionMode(photo.id);
    widget.onSelectionChanged?.call(_selectionNotifier.selectedCount);
  }

  void _clearSelection() {
    _selectionNotifier.clearSelection();
    widget.onSelectionChanged?.call(0);
  }

  int get selectedCount => _selectionNotifier.selectedCount;

  void removePhoto(String photoId) {
    setState(() {
      _photos.removeWhere((p) => p.id == photoId);
      _photoGroups = _groupPhotosByDate(_photos);
    });
    _selectionNotifier.removePhotoId(photoId);
    widget.onSelectionChanged?.call(_selectionNotifier.selectedCount);
  }

  Future<void> performAction(PhotoGridAction action) async {
    switch (action) {
      case PhotoGridAction.delete:
        await _deleteSelectedPhotos();
        break;
      case PhotoGridAction.upload:
        _uploadSelectedPhotos();
        break;
      case PhotoGridAction.uploadTo:
        _showUploadToDialog();
        break;
    }
  }

  List<AssetEntity> get _selectedPhotos {
    return _photos.where((p) => _selectionNotifier.isSelected(p.id)).toList();
  }

  Future<void> _deleteSelectedPhotos() async {
    final selectedPhotos = _selectedPhotos;
    if (selectedPhotos.isEmpty) return;

    final result = await PhotoManager.editor.deleteWithIds(
      selectedPhotos.map((p) => p.id).toList(),
    );

    if (result.isNotEmpty) {
      final selectedIds = _selectionNotifier.selectedIds;
      setState(() {
        _photos.removeWhere((p) => selectedIds.contains(p.id));
        _photoGroups = _groupPhotosByDate(_photos);
      });
      _selectionNotifier.clearSelection();
      widget.onSelectionChanged?.call(0);
    }
  }

  Future<void> _uploadSelectedPhotos() async {
    final selectedPhotos = _selectedPhotos;
    if (selectedPhotos.isEmpty) return;

    final config = await BackendConfig.load();
    final uploadService = UploadService(
      host: config.host,
      port: config.port,
      uploadTimeout: Duration(seconds: config.uploadTimeoutSeconds),
    );

    try {
      // Show upload progress dialog
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _UploadProgressDialog(
          photos: selectedPhotos,
          uploadService: uploadService,
          directoryPrefix: config.defaultDirectory,
          deleteAfterUpload: config.deleteAfterUpload,
          onComplete: (results) {
            Navigator.pop(dialogContext);
            _showUploadResults(results, config.deleteAfterUpload);
          },
        ),
      );
    } finally {
      await uploadService.dispose();
    }
  }

  void _showUploadToDialog() {
    final selectedPhotos = _selectedPhotos;
    if (selectedPhotos.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) => _UploadToDirectoryDialog(
        onDirectorySelected: (directory) {
          Navigator.pop(dialogContext);
          _uploadSelectedPhotosToDirectory(directory);
        },
      ),
    );
  }

  Future<void> _uploadSelectedPhotosToDirectory(String directory) async {
    final selectedPhotos = _selectedPhotos;
    if (selectedPhotos.isEmpty) return;

    final config = await BackendConfig.load();
    final uploadService = UploadService(
      host: config.host,
      port: config.port,
      uploadTimeout: Duration(seconds: config.uploadTimeoutSeconds),
    );

    try {
      // Show upload progress dialog
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _UploadProgressDialog(
          photos: selectedPhotos,
          uploadService: uploadService,
          directoryPrefix: directory,
          deleteAfterUpload: config.deleteAfterUpload,
          onComplete: (results) {
            Navigator.pop(dialogContext);
            _showUploadResults(results, config.deleteAfterUpload);
          },
        ),
      );
    } finally {
      await uploadService.dispose();
    }
  }

  void _showUploadResults(List<UploadResult> results, bool deleteAfterUpload) {
    // Handle case where upload was rolled back (empty results)
    if (results.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload cancelled - uploaded photos deleted'),
          duration: Duration(seconds: 3),
        ),
      );
      _clearSelection();
      return;
    }

    final successCount = results.where((r) => r.success).length;
    final failureCount = results.where((r) => !r.success && !r.timedOut).length;
    final timeoutCount = results.where((r) => r.timedOut).length;

    if (!mounted) return;

    String message;
    if (failureCount == 0 && timeoutCount == 0) {
      if (deleteAfterUpload) {
        message =
            'Successfully uploaded and deleted $successCount photo${successCount == 1 ? '' : 's'}';
      } else {
        message =
            'Successfully uploaded $successCount photo${successCount == 1 ? '' : 's'}';
      }
    } else if (timeoutCount > 0) {
      message = 'Uploaded $successCount, timed out on 1';
      if (failureCount > 0) {
        message += ', failed $failureCount';
      }
    } else {
      message = 'Uploaded $successCount, failed $failureCount';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );

    // Clear selection after upload
    _clearSelection();

    // Remove successfully uploaded photos from the grid if they were deleted
    if (deleteAfterUpload) {
      setState(() {
        final deletedIds = results
            .where((r) => r.success)
            .map((r) => r.asset.id)
            .toSet();
        _photos.removeWhere((p) => deletedIds.contains(p.id));
        _photoGroups = _groupPhotosByDate(_photos);
      });
    }
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

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Build date groups with headers and grids
        for (final group in _photoGroups) ...[
          // Date header
          SliverToBoxAdapter(
            child: _DateHeader(
              formattedDate: group.formattedDate,
              dayOfWeek: group.dayOfWeek,
              photoCount: group.photos.length,
            ),
          ),
          // Photo grid for this date
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final photo = group.photos[index];
                // Calculate global index for onPhotoTap
                final globalIndex = _photos.indexOf(photo);
                return _SelectablePhotoThumbnail(
                  key: ValueKey(photo.id),
                  asset: photo,
                  selectionNotifier: _selectionNotifier,
                  onTap: () {
                    if (_selectionNotifier.isSelectionMode) {
                      _toggleSelection(photo);
                    } else {
                      widget.onPhotoTap?.call(photo, globalIndex);
                    }
                  },
                  onLongPress: () => _enterSelectionMode(photo),
                );
              }, childCount: group.photos.length),
            ),
          ),
        ],
      ],
    );
  }
}

/// A photo thumbnail that efficiently listens to selection changes.
/// Only the selection overlay rebuilds when selection state changes,
/// not the entire thumbnail or the parent grid.
class _SelectablePhotoThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final PhotoSelectionNotifier selectionNotifier;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _SelectablePhotoThumbnail({
    super.key,
    required this.asset,
    required this.selectionNotifier,
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
          // The thumbnail image - does not rebuild on selection change
          _ThumbnailImage(asset: asset),
          // The selection overlay - only this rebuilds on selection change
          ListenableBuilder(
            listenable: selectionNotifier,
            builder: (context, child) {
              final isSelected = selectionNotifier.isSelected(asset.id);
              if (!isSelected) return const SizedBox.shrink();
              return Container(
                color: Colors.blue.withValues(alpha: 0.3),
                child: const Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Stateful widget that caches the thumbnail data to avoid reloading
/// when parent rebuilds.
class _ThumbnailImage extends StatefulWidget {
  final AssetEntity asset;

  const _ThumbnailImage({required this.asset});

  @override
  State<_ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<_ThumbnailImage> {
  Future<Uint8List?>? _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
    );
  }

  @override
  void didUpdateWidget(_ThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _thumbnailFuture = widget.asset.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumbnailFuture,
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
    );
  }
}

/// Widget to display the date header for a group of photos.
class _DateHeader extends StatelessWidget {
  final String formattedDate;
  final String dayOfWeek;
  final int photoCount;

  const _DateHeader({
    required this.formattedDate,
    required this.dayOfWeek,
    required this.photoCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedDate,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dayOfWeek,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$photoCount photo${photoCount == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
  final String? directoryPrefix;
  final bool deleteAfterUpload;
  final void Function(List<UploadResult> results) onComplete;

  const _UploadProgressDialog({
    required this.photos,
    required this.uploadService,
    required this.onComplete,
    this.directoryPrefix,
    this.deleteAfterUpload = false,
  });

  @override
  State<_UploadProgressDialog> createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<_UploadProgressDialog> {
  int _completed = 0;
  int _total = 0;
  String _currentFileName = '';
  bool _isUploading = true;
  bool _isDeleting = false;
  bool _timedOut = false;
  List<UploadResult> _results = [];

  @override
  void initState() {
    super.initState();
    _total = widget.photos.length;
    _startUpload();
  }

  Future<void> _startUpload() async {
    final results = await widget.uploadService.uploadPhotos(
      widget.photos,
      directoryPrefix: widget.directoryPrefix,
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

    if (!mounted) return;

    // Check if upload was stopped due to timeout
    final hasTimeout = results.any((r) => r.timedOut);

    setState(() {
      _results = results;
      _isUploading = false;
      _timedOut = hasTimeout;
    });

    // If no timeout, proceed with normal completion
    if (!hasTimeout) {
      await _completeUpload(results);
    }
  }

  Future<void> _completeUpload(List<UploadResult> results) async {
    // Delete successfully uploaded photos if setting is enabled
    if (widget.deleteAfterUpload) {
      final successfulIds = results
          .where((r) => r.success)
          .map((r) => r.asset.id)
          .toList();
      if (successfulIds.isNotEmpty) {
        await PhotoManager.editor.deleteWithIds(successfulIds);
      }
    }

    widget.onComplete(results);
  }

  Future<void> _deleteUploadedPhotos() async {
    setState(() {
      _isDeleting = true;
    });

    final successfulResults = _results.where((r) => r.success).toList();
    await widget.uploadService.deleteUploadedPhotos(successfulResults);

    if (!mounted) return;

    // Return empty results since we rolled back
    widget.onComplete([]);
  }

  void _keepUploadedPhotos() {
    // Proceed with completion, keeping the successfully uploaded photos
    _completeUpload(_results);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total > 0 ? _completed / _total : 0.0;

    // Show timeout dialog with rollback option
    if (_timedOut && !_isDeleting) {
      final successCount = _results.where((r) => r.success).length;
      final timedOutPhoto = _results.firstWhere((r) => r.timedOut);

      return AlertDialog(
        title: const Text('Upload Timed Out'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload timed out while uploading "${timedOutPhoto.asset.title ?? 'photo'}".',
            ),
            const SizedBox(height: 16),
            if (successCount > 0) ...[
              Text(
                '$successCount photo${successCount == 1 ? ' was' : 's were'} '
                'successfully uploaded before the timeout.',
              ),
              const SizedBox(height: 16),
              const Text('Would you like to delete the uploaded photos?'),
            ] else
              const Text('No photos were uploaded.'),
          ],
        ),
        actions: [
          if (successCount > 0) ...[
            TextButton(
              onPressed: _keepUploadedPhotos,
              child: const Text('Keep Uploaded'),
            ),
            TextButton(
              onPressed: _deleteUploadedPhotos,
              child: const Text('Delete Uploaded'),
            ),
          ] else
            TextButton(
              onPressed: () => widget.onComplete(_results),
              child: const Text('OK'),
            ),
        ],
      );
    }

    // Show deleting progress
    if (_isDeleting) {
      return AlertDialog(
        title: const Text('Deleting Uploaded Photos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Removing ${_results.where((r) => r.success).length} uploaded photos...',
            ),
          ],
        ),
      );
    }

    // Show upload progress
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

/// Dialog for selecting a directory to upload photos to
class _UploadToDirectoryDialog extends StatefulWidget {
  final void Function(String directory) onDirectorySelected;

  const _UploadToDirectoryDialog({required this.onDirectorySelected});

  @override
  State<_UploadToDirectoryDialog> createState() =>
      _UploadToDirectoryDialogState();
}

class _UploadToDirectoryDialogState extends State<_UploadToDirectoryDialog> {
  final TextEditingController _directoryController = TextEditingController();
  List<String> _directorySuggestions = [];
  bool _isLoadingDirectories = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadDirectorySuggestions();
  }

  @override
  void dispose() {
    _directoryController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectorySuggestions() async {
    setState(() {
      _isLoadingDirectories = true;
    });

    try {
      final config = await BackendConfig.load();
      final libraryService = LibraryService(
        host: config.host,
        port: config.port,
      );

      final directories = await libraryService.listDirectories(recursive: true);
      await libraryService.dispose();

      if (mounted) {
        setState(() {
          _directorySuggestions = directories
              .map((d) => d.endsWith('/') ? d : '$d/')
              .toList();
          _isLoadingDirectories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDirectories = false;
        });
      }
    }
  }

  void _onSubmit() {
    final directory = _directoryController.text.trim();
    if (directory.isEmpty) {
      setState(() {
        _errorText = 'Directory cannot be empty';
      });
      return;
    }
    widget.onDirectorySelected(directory);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload to Directory'),
      content: SizedBox(
        width: double.maxFinite,
        child: Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (_directorySuggestions.isEmpty) {
              return const Iterable<String>.empty();
            }
            final input = textEditingValue.text.toLowerCase();
            if (input.isEmpty) {
              return _directorySuggestions;
            }
            return _directorySuggestions.where(
              (directory) => directory.toLowerCase().contains(input),
            );
          },
          onSelected: (String selection) {
            _directoryController.text = selection;
            setState(() {
              _errorText = null;
            });
          },
          fieldViewBuilder:
              (
                BuildContext context,
                TextEditingController fieldController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted,
              ) {
                // Keep controllers in sync
                fieldController.addListener(() {
                  _directoryController.text = fieldController.text;
                });
                return TextField(
                  controller: fieldController,
                  focusNode: focusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Directory',
                    hintText: 'e.g., photos/2026/vacation',
                    prefixIcon: const Icon(Icons.folder),
                    suffixIcon: _isLoadingDirectories
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadDirectorySuggestions,
                            tooltip: 'Refresh directories',
                          ),
                    errorText: _errorText,
                  ),
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() {
                        _errorText = null;
                      });
                    }
                  },
                  onSubmitted: (_) => _onSubmit(),
                );
              },
          optionsViewBuilder:
              (
                BuildContext context,
                AutocompleteOnSelected<String> onSelected,
                Iterable<String> options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(option),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _onSubmit, child: const Text('Upload')),
      ],
    );
  }
}

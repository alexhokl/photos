import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photos/proto/photos.pb.dart';
import 'package:photos/services/library_service.dart';
import 'package:photos/widgets/cloud_photo_viewer.dart';
import 'package:photos/widgets/settings_page.dart';

enum CloudPhotoGridAction { delete, download, copy, move }

class CloudPhotoGrid extends StatefulWidget {
  final void Function(int selectedCount)? onSelectionChanged;
  final bool isActive;

  const CloudPhotoGrid({
    super.key,
    this.onSelectionChanged,
    this.isActive = true,
  });

  @override
  State<CloudPhotoGrid> createState() => CloudPhotoGridState();
}

class CloudPhotoGridState extends State<CloudPhotoGrid> {
  List<Photo> _photos = [];
  List<String> _subdirectories = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _currentPrefix = '';
  String? _nextPageToken;
  bool _isLoadingMore = false;
  final Set<String> _selectedObjectIds = {};
  bool _isSelectionMode = false;
  final ScrollController _scrollController = ScrollController();

  // Cache signed URLs to avoid re-generating for each rebuild
  final Map<String, String> _signedUrlCache = {};

  static const int _pageSize = 50;

  bool _hasInitiallyLoaded = false;

  bool get isSelectionMode => _isSelectionMode;
  int get selectedCount => _selectedObjectIds.length;

  /// Returns an unmodifiable view of the current photos list.
  List<Photo> get photos => List.unmodifiable(_photos);

  /// Returns an unmodifiable view of the signed URL cache.
  Map<String, String> get signedUrls => Map.unmodifiable(_signedUrlCache);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.isActive) {
      _hasInitiallyLoaded = true;
      _loadInitialData();
    }
  }

  @override
  void didUpdateWidget(CloudPhotoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_hasInitiallyLoaded) {
      _hasInitiallyLoaded = true;
      _loadInitialData();
    }
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

  Future<void> _loadInitialData() async {
    try {
      final config = await BackendConfig.load();
      final prefix = config.defaultDirectory.isNotEmpty
          ? (config.defaultDirectory.endsWith('/')
                ? config.defaultDirectory
                : '${config.defaultDirectory}/')
          : '';

      setState(() {
        _currentPrefix = prefix;
      });

      await _loadDirectory(prefix);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load configuration: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDirectory(String prefix) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _photos = [];
      _subdirectories = [];
      _nextPageToken = null;
      _signedUrlCache.clear();
      _clearSelection();
    });

    LibraryService? libraryService;
    try {
      final config = await BackendConfig.load();
      libraryService = LibraryService(host: config.host, port: config.port);

      // Load subdirectories and photos in parallel
      final dirFuture = libraryService.listDirectories(prefix: prefix);
      final photoFuture = libraryService.listPhotos(
        prefix: prefix,
        pageSize: _pageSize,
      );

      final results = await Future.wait([dirFuture, photoFuture]);
      final directories = results[0] as List<String>;
      final photosResult = results[1] as ListPhotosResult;

      if (!mounted) return;

      setState(() {
        _currentPrefix = prefix;
        _subdirectories = directories;
        _photos = photosResult.photos;
        _nextPageToken = photosResult.nextPageToken;
        _isLoading = false;
      });

      // Pre-fetch signed URLs for visible thumbnails
      _fetchSignedUrls(photosResult.photos, config);
    } on LibraryException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load photos: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load photos: $e';
        _isLoading = false;
      });
    } finally {
      await libraryService?.dispose();
    }
  }

  Future<void> _loadMorePhotos() async {
    if (_isLoadingMore || _nextPageToken == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    LibraryService? libraryService;
    try {
      final config = await BackendConfig.load();
      libraryService = LibraryService(host: config.host, port: config.port);

      final result = await libraryService.listPhotos(
        prefix: _currentPrefix,
        pageSize: _pageSize,
        pageToken: _nextPageToken,
      );

      if (!mounted) return;

      setState(() {
        _photos.addAll(result.photos);
        _nextPageToken = result.nextPageToken;
        _isLoadingMore = false;
      });

      _fetchSignedUrls(result.photos, config);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    } finally {
      await libraryService?.dispose();
    }
  }

  Future<void> _fetchSignedUrls(
    List<Photo> photos,
    BackendConfig config,
  ) async {
    LibraryService? libraryService;
    try {
      libraryService = LibraryService(host: config.host, port: config.port);

      for (final photo in photos) {
        if (_signedUrlCache.containsKey(photo.objectId)) continue;

        try {
          final result = await libraryService.generateSignedUrl(photo.objectId);
          if (mounted) {
            setState(() {
              _signedUrlCache[photo.objectId] = result.signedUrl;
            });
          }
        } catch (_) {
          // Skip individual failures; thumbnail will show placeholder
        }
      }
    } finally {
      await libraryService?.dispose();
    }
  }

  void _navigateToDirectory(String directory) {
    final prefix = directory.endsWith('/') ? directory : '$directory/';
    _loadDirectory(prefix);
  }

  void _navigateUp() {
    if (_currentPrefix.isEmpty) return;

    // Remove trailing slash, then find the last slash
    final withoutTrailing = _currentPrefix.endsWith('/')
        ? _currentPrefix.substring(0, _currentPrefix.length - 1)
        : _currentPrefix;
    final lastSlash = withoutTrailing.lastIndexOf('/');

    if (lastSlash == -1) {
      _loadDirectory('');
    } else {
      _loadDirectory(withoutTrailing.substring(0, lastSlash + 1));
    }
  }

  void _navigateToBreadcrumb(int segmentIndex) {
    final segments = _currentPrefix
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    if (segmentIndex < 0) {
      _loadDirectory('');
    } else {
      final path = '${segments.sublist(0, segmentIndex + 1).join('/')}/';
      _loadDirectory(path);
    }
  }

  void _toggleSelection(Photo photo) {
    setState(() {
      if (_selectedObjectIds.contains(photo.objectId)) {
        _selectedObjectIds.remove(photo.objectId);
        if (_selectedObjectIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedObjectIds.add(photo.objectId);
      }
    });
    widget.onSelectionChanged?.call(_selectedObjectIds.length);
  }

  void _enterSelectionMode(Photo photo) {
    if (_isSelectionMode) return;
    setState(() {
      _isSelectionMode = true;
      _selectedObjectIds.add(photo.objectId);
    });
    widget.onSelectionChanged?.call(_selectedObjectIds.length);
  }

  void _clearSelection() {
    setState(() {
      _selectedObjectIds.clear();
      _isSelectionMode = false;
    });
    widget.onSelectionChanged?.call(0);
  }

  List<Photo> get _selectedPhotos {
    return _photos
        .where((p) => _selectedObjectIds.contains(p.objectId))
        .toList();
  }

  void removePhoto(String objectId) {
    setState(() {
      _photos.removeWhere((p) => p.objectId == objectId);
      _selectedObjectIds.remove(objectId);
      _signedUrlCache.remove(objectId);
      if (_selectedObjectIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
    widget.onSelectionChanged?.call(_selectedObjectIds.length);
  }

  Future<void> performAction(CloudPhotoGridAction action) async {
    switch (action) {
      case CloudPhotoGridAction.delete:
        await _deleteSelectedPhotos();
        break;
      case CloudPhotoGridAction.download:
        // Download is handled per-photo in the viewer
        break;
      case CloudPhotoGridAction.copy:
        await _copyOrMoveSelectedPhotos(move: false);
        break;
      case CloudPhotoGridAction.move:
        await _copyOrMoveSelectedPhotos(move: true);
        break;
    }
  }

  Future<void> _deleteSelectedPhotos() async {
    final selected = _selectedPhotos;
    if (selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photos'),
        content: Text(
          'Delete ${selected.length} photo${selected.length == 1 ? '' : 's'} from cloud storage? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    LibraryService? libraryService;
    try {
      final config = await BackendConfig.load();
      libraryService = LibraryService(host: config.host, port: config.port);

      int successCount = 0;
      int failureCount = 0;

      for (final photo in selected) {
        try {
          await libraryService.deletePhoto(photo.objectId);
          removePhoto(photo.objectId);
          successCount++;
        } catch (_) {
          failureCount++;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failureCount == 0
                ? 'Deleted $successCount photo${successCount == 1 ? '' : 's'}'
                : 'Deleted $successCount, failed $failureCount',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      await libraryService?.dispose();
    }
  }

  Future<void> _copyOrMoveSelectedPhotos({required bool move}) async {
    final selected = _selectedPhotos;
    if (selected.isEmpty) return;

    // Show directory picker dialog
    final targetDirectory = await _showDirectoryPickerDialog(
      title: move ? 'Move to Directory' : 'Copy to Directory',
    );
    if (targetDirectory == null) return;

    LibraryService? libraryService;
    try {
      final config = await BackendConfig.load();
      libraryService = LibraryService(host: config.host, port: config.port);

      int successCount = 0;
      int failureCount = 0;

      for (final photo in selected) {
        try {
          // Extract filename from object_id
          final filename = photo.objectId.split('/').last;
          final destPrefix = targetDirectory.endsWith('/')
              ? targetDirectory
              : '$targetDirectory/';
          final destinationObjectId = '$destPrefix$filename';

          await libraryService.copyPhoto(photo.objectId, destinationObjectId);

          if (move) {
            await libraryService.deletePhoto(photo.objectId);
            removePhoto(photo.objectId);
          }

          successCount++;
        } catch (_) {
          failureCount++;
        }
      }

      if (!mounted) return;

      final action = move ? 'Moved' : 'Copied';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failureCount == 0
                ? '$action $successCount photo${successCount == 1 ? '' : 's'}'
                : '$action $successCount, failed $failureCount',
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      if (!move) {
        _clearSelection();
      }
    } finally {
      await libraryService?.dispose();
    }
  }

  Future<String?> _showDirectoryPickerDialog({required String title}) async {
    List<String> directories = [];
    String? error;

    try {
      final config = await BackendConfig.load();
      final libraryService = LibraryService(
        host: config.host,
        port: config.port,
      );
      directories = await libraryService.listDirectories(recursive: true);
      await libraryService.dispose();
    } catch (e) {
      error = 'Failed to load directories: $e';
    }

    if (!mounted) return null;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: error != null
              ? Center(child: Text(error))
              : directories.isEmpty
              ? const Center(child: Text('No directories found'))
              : ListView.builder(
                  itemCount: directories.length,
                  itemBuilder: (context, index) {
                    final dir = directories[index];
                    return ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(dir),
                      onTap: () => Navigator.pop(context, dir),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _onPhotoTap(Photo photo, int index) async {
    final signedUrl = _signedUrlCache[photo.objectId];
    if (signedUrl == null) return;

    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CloudPhotoViewer(
          photos: _photos,
          signedUrls: _signedUrlCache,
          initialIndex: index,
        ),
      ),
    );

    if (deleted == true) {
      removePhoto(photo.objectId);
    }
  }

  Future<void> _refresh() async {
    await _loadDirectory(_currentPrefix);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Breadcrumb navigation
          SliverToBoxAdapter(child: _buildBreadcrumb()),
          // Subdirectory chips
          if (_subdirectories.isNotEmpty)
            SliverToBoxAdapter(child: _buildDirectoryChips()),
          // Photo grid
          if (_photos.isEmpty && _subdirectories.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No photos in this directory'),
                  ],
                ),
              ),
            )
          else if (_photos.isEmpty)
            const SliverToBoxAdapter(child: SizedBox.shrink())
          else
            SliverPadding(
              padding: const EdgeInsets.all(4),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index >= _photos.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final photo = _photos[index];
                  return _CloudPhotoThumbnail(
                    photo: photo,
                    signedUrl: _signedUrlCache[photo.objectId],
                    isSelected: _selectedObjectIds.contains(photo.objectId),
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(photo);
                      } else {
                        _onPhotoTap(photo, index);
                      }
                    },
                    onLongPress: () => _enterSelectionMode(photo),
                  );
                }, childCount: _photos.length + (_isLoadingMore ? 1 : 0)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    final segments = _currentPrefix
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            InkWell(
              onTap: _currentPrefix.isNotEmpty
                  ? () => _navigateToBreadcrumb(-1)
                  : null,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Cloud',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (var i = 0; i < segments.length; i++) ...[
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              InkWell(
                onTap: i < segments.length - 1
                    ? () => _navigateToBreadcrumb(i)
                    : null,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    segments[i],
                    style: TextStyle(
                      color: i < segments.length - 1
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: i == segments.length - 1
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDirectoryChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _subdirectories.map((dir) {
          // Show only the last segment of the directory path
          final displayName = dir.endsWith('/')
              ? dir.substring(0, dir.length - 1).split('/').last
              : dir.split('/').last;

          return ActionChip(
            avatar: const Icon(Icons.folder, size: 18),
            label: Text(displayName),
            onPressed: () => _navigateToDirectory(dir),
          );
        }).toList(),
      ),
    );
  }
}

class _CloudPhotoThumbnail extends StatelessWidget {
  final Photo photo;
  final String? signedUrl;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _CloudPhotoThumbnail({
    required this.photo,
    this.signedUrl,
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
          if (signedUrl != null)
            CachedNetworkImage(
              imageUrl: signedUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            )
          else
            Container(
              color: Colors.grey[300],
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
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

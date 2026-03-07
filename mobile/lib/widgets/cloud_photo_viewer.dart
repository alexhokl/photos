import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/proto/photos.pb.dart';
import 'package:photos/services/download_service.dart';
import 'package:photos/services/library_service.dart';
import 'package:photos/services/photo_cache_manager.dart';
import 'package:photos/widgets/cloud_photo_info_view.dart';
import 'package:photos/widgets/settings_page.dart';

enum CloudPhotoViewerAction { info, delete, download, copy, move, rename }

/// Result returned from CloudPhotoViewer when navigating back.
/// Used to indicate what action was taken on the photo.
class CloudPhotoViewerResult {
  /// True if the photo was deleted or moved to another directory.
  final bool removed;

  /// If the photo was renamed, contains the old and new object IDs.
  final String? oldObjectId;
  final String? newObjectId;

  const CloudPhotoViewerResult.removed()
    : removed = true,
      oldObjectId = null,
      newObjectId = null;

  const CloudPhotoViewerResult.renamed({
    required String oldId,
    required String newId,
  }) : removed = false,
       oldObjectId = oldId,
       newObjectId = newId;
}

class CloudPhotoViewer extends StatefulWidget {
  final List<Photo> photos;
  final Map<String, String> signedUrls;
  final int initialIndex;

  const CloudPhotoViewer({
    super.key,
    required this.photos,
    required this.signedUrls,
    required this.initialIndex,
  });

  @override
  State<CloudPhotoViewer> createState() => _CloudPhotoViewerState();
}

class _CloudPhotoViewerState extends State<CloudPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _transformationControllers = {};
  bool _isZoomed = false;

  Photo get _currentPhoto => widget.photos[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _transformationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _getTransformationController(int index) {
    if (!_transformationControllers.containsKey(index)) {
      _transformationControllers[index] = TransformationController();
    }
    return _transformationControllers[index]!;
  }

  void _updateZoomState(int index) {
    final controller = _transformationControllers[index];
    if (controller != null) {
      final scale = controller.value.getMaxScaleOnAxis();
      final isZoomed = scale > 1.05;
      if (isZoomed != _isZoomed) {
        setState(() => _isZoomed = isZoomed);
      }
    }
  }

  void _resetZoomOnPageChange(int newIndex) {
    // Reset zoom state for the previous page
    final prevController = _transformationControllers[_currentIndex];
    if (prevController != null) {
      prevController.value = Matrix4.identity();
    }
    setState(() {
      _isZoomed = false;
      _currentIndex = newIndex;
    });
  }

  Future<void> _deletePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text(
          'Delete this photo from cloud storage? This cannot be undone.',
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
      await libraryService.deletePhoto(_currentPhoto.objectId);

      if (mounted) {
        Navigator.pop(context, const CloudPhotoViewerResult.removed());
      }
    } on LibraryException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: ${e.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      await libraryService?.dispose();
    }
  }

  Future<void> _downloadToDevice() async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DownloadProgressDialog(
        photo: _currentPhoto,
        onComplete: (success, error) {
          Navigator.pop(dialogContext);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved to device: ${_currentPhoto.filename}'),
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download failed: ${error ?? "Unknown error"}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _copyOrMovePhoto({required bool move}) async {
    if (!mounted) return;

    final targetDirectory = await showDialog<String>(
      context: context,
      builder: (context) => _DirectoryPickerDialog(
        title: move ? 'Move to Directory' : 'Copy to Directory',
        actionLabel: move ? 'Move' : 'Copy',
      ),
    );

    if (targetDirectory == null) return;

    LibraryService? libraryService;
    try {
      final config = await BackendConfig.load();
      libraryService = LibraryService(host: config.host, port: config.port);

      final filename = _currentPhoto.objectId.split('/').last;
      final destPrefix = targetDirectory.endsWith('/')
          ? targetDirectory
          : '$targetDirectory/';
      final destinationObjectId = '$destPrefix$filename';

      await libraryService.copyPhoto(
        _currentPhoto.objectId,
        destinationObjectId,
      );

      if (move) {
        await libraryService.deletePhoto(_currentPhoto.objectId);
      }

      if (!mounted) return;

      final action = move ? 'Moved' : 'Copied';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$action to $destinationObjectId'),
          duration: const Duration(seconds: 2),
        ),
      );

      if (move) {
        Navigator.pop(context, const CloudPhotoViewerResult.removed());
      }
    } on LibraryException catch (e) {
      if (!mounted) return;
      final action = move ? 'Move' : 'Copy';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$action failed: ${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      await libraryService?.dispose();
    }
  }

  Future<void> _renamePhoto() async {
    final objectId = _currentPhoto.objectId;
    final currentFilename = objectId.split('/').last;

    // Extract base name without extension
    final lastDot = currentFilename.lastIndexOf('.');
    final baseName = lastDot != -1
        ? currentFilename.substring(0, lastDot)
        : currentFilename;
    final extension = lastDot != -1 ? currentFilename.substring(lastDot) : '';

    final controller = TextEditingController(text: baseName);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Photo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'File name',
            hintText: 'Enter new file name',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == baseName) {
      return;
    }

    final newFilename = '$newName$extension';

    // Build the new object ID by replacing only the filename part
    final parts = objectId.split('/');
    parts[parts.length - 1] = newFilename;
    final newObjectId = parts.join('/');

    LibraryService? libraryService;
    try {
      final config = await BackendConfig.load();
      libraryService = LibraryService(host: config.host, port: config.port);
      await libraryService.renamePhoto(objectId, newObjectId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Renamed to $newFilename'),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(
          context,
          CloudPhotoViewerResult.renamed(oldId: objectId, newId: newObjectId),
        );
      }
    } on LibraryException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rename failed: ${e.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      await libraryService?.dispose();
    }
  }

  void _onMenuAction(CloudPhotoViewerAction action) {
    switch (action) {
      case CloudPhotoViewerAction.info:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CloudPhotoInfoView(photo: _currentPhoto),
          ),
        );
        break;
      case CloudPhotoViewerAction.delete:
        _deletePhoto();
        break;
      case CloudPhotoViewerAction.download:
        _downloadToDevice();
        break;
      case CloudPhotoViewerAction.copy:
        _copyOrMovePhoto(move: false);
        break;
      case CloudPhotoViewerAction.move:
        _copyOrMovePhoto(move: true);
        break;
      case CloudPhotoViewerAction.rename:
        _renamePhoto();
        break;
    }
  }

  Widget _buildPhotoPage(int index) {
    final photo = widget.photos[index];
    final signedUrl = widget.signedUrls[photo.objectId];

    if (signedUrl == null) {
      return const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
      );
    }

    return InteractiveViewer(
      transformationController: _getTransformationController(index),
      minScale: 0.5,
      maxScale: 4.0,
      onInteractionEnd: (_) => _updateZoomState(index),
      child: CachedNetworkImage(
        imageUrl: signedUrl,
        cacheManager: PhotoCacheManager.instance,
        fit: BoxFit.contain,
        placeholder: (context, url) =>
            const CircularProgressIndicator(color: Colors.white),
        errorWidget: (context, url, error) =>
            const Icon(Icons.broken_image, color: Colors.white54, size: 64),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extract display name from object_id
    final displayName = _currentPhoto.objectId.split('/').last;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(displayName, style: const TextStyle(color: Colors.white)),
        actions: [
          PopupMenuButton<CloudPhotoViewerAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: _onMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: CloudPhotoViewerAction.info,
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Info'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: CloudPhotoViewerAction.rename,
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Rename'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: CloudPhotoViewerAction.download,
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Download to Device'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: CloudPhotoViewerAction.copy,
                child: ListTile(
                  leading: Icon(Icons.copy),
                  title: Text('Copy to...'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: CloudPhotoViewerAction.move,
                child: ListTile(
                  leading: Icon(Icons.drive_file_move_outlined),
                  title: Text('Move to...'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: CloudPhotoViewerAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Delete'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        physics: _isZoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        onPageChanged: _resetZoomOnPageChange,
        itemBuilder: (context, index) => _buildPhotoPage(index),
      ),
    );
  }
}

/// Dialog that shows download progress
class _DownloadProgressDialog extends StatefulWidget {
  final Photo photo;
  final void Function(bool success, String? error) onComplete;

  const _DownloadProgressDialog({
    required this.photo,
    required this.onComplete,
  });

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  int _bytesReceived = 0;
  int _totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _totalBytes = widget.photo.sizeBytes.toInt();
    _startDownload();
  }

  Future<void> _startDownload() async {
    DownloadService? downloadService;
    try {
      final config = await BackendConfig.load();
      downloadService = DownloadService(host: config.host, port: config.port);

      final result = await downloadService.downloadPhoto(
        widget.photo.objectId,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _bytesReceived = received;
              _totalBytes = total;
            });
          }
        },
      );

      // Save to device gallery
      final filename = widget.photo.objectId.split('/').last;
      await PhotoManager.editor.saveImage(result.data, filename: filename);

      widget.onComplete(true, null);
    } catch (e) {
      widget.onComplete(false, e.toString());
    } finally {
      await downloadService?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalBytes > 0 ? _bytesReceived / _totalBytes : 0.0;
    final displayName = widget.photo.objectId.split('/').last;

    return AlertDialog(
      title: const Text('Downloading'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 16),
          Text(
            _totalBytes > 0
                ? '${_formatBytes(_bytesReceived)} / ${_formatBytes(_totalBytes)}'
                : 'Starting download...',
          ),
          const SizedBox(height: 8),
          Text(
            displayName,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Dialog for selecting a directory with free text input and autocomplete.
class _DirectoryPickerDialog extends StatefulWidget {
  final String title;
  final String actionLabel;

  const _DirectoryPickerDialog({
    required this.title,
    required this.actionLabel,
  });

  @override
  State<_DirectoryPickerDialog> createState() => _DirectoryPickerDialogState();
}

class _DirectoryPickerDialogState extends State<_DirectoryPickerDialog> {
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
    Navigator.pop(context, directory);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
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
        TextButton(onPressed: _onSubmit, child: Text(widget.actionLabel)),
      ],
    );
  }
}

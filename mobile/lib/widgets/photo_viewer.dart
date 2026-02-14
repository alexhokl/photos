import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/services/library_service.dart';
import 'package:photos/services/upload_service.dart';
import 'package:photos/widgets/photo_info_view.dart';
import 'package:photos/widgets/settings_page.dart';

enum PhotoViewerAction { info, delete, upload, uploadTo, rename }

class PhotoViewer extends StatefulWidget {
  final List<AssetEntity> assets;
  final int initialIndex;

  const PhotoViewer({
    super.key,
    required this.assets,
    required this.initialIndex,
  });

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, Uint8List?> _imageCache = {};
  final Map<int, bool> _loadingStates = {};
  final Map<int, TransformationController> _transformationControllers = {};
  bool _isZoomed = false;

  AssetEntity get _currentAsset => widget.assets[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _preloadImages(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _transformationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _preloadImages(int centerIndex) {
    // Load current and adjacent images
    for (int i = centerIndex - 1; i <= centerIndex + 1; i++) {
      if (i >= 0 && i < widget.assets.length && !_imageCache.containsKey(i)) {
        _loadImage(i);
      }
    }
    // Evict distant images to save memory
    _evictDistantImages(centerIndex);
  }

  void _evictDistantImages(int currentIndex) {
    final keysToRemove = <int>[];
    for (final key in _imageCache.keys) {
      if ((key - currentIndex).abs() > 2) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      _imageCache.remove(key);
      _loadingStates.remove(key);
      _transformationControllers[key]?.dispose();
      _transformationControllers.remove(key);
    }
  }

  Future<void> _loadImage(int index) async {
    if (_loadingStates[index] == true) return;
    _loadingStates[index] = true;

    final asset = widget.assets[index];
    final data = await asset.originBytes;

    if (mounted) {
      setState(() {
        _imageCache[index] = data;
        _loadingStates[index] = false;
      });
    }
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
    _preloadImages(newIndex);
  }

  Future<void> _deletePhoto() async {
    final deletedId = _currentAsset.id;
    final result = await PhotoManager.editor.deleteWithIds([deletedId]);
    if (result.isNotEmpty && mounted) {
      Navigator.pop(context, deletedId);
    }
  }

  Future<void> _renamePhoto() async {
    final renamedId = _currentAsset.id;
    final currentTitle = _currentAsset.title ?? '';
    // Extract base name without extension
    final lastDot = currentTitle.lastIndexOf('.');
    final baseName = lastDot != -1
        ? currentTitle.substring(0, lastDot)
        : currentTitle;
    final extension = lastDot != -1 ? currentTitle.substring(lastDot) : '';

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

    final newFileName = '$newName$extension';

    try {
      // Get the original image bytes
      final imageBytes = await _currentAsset.originBytes;
      if (imageBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access photo data'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Save as new file with the new name using MediaStore API
      await PhotoManager.editor.saveImage(imageBytes, filename: newFileName);

      // Delete the original file
      await PhotoManager.editor.deleteWithIds([renamedId]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Renamed to $newFileName'),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, renamedId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rename failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _uploadPhoto() async {
    final config = await BackendConfig.load();
    final uploadService = UploadService(host: config.host, port: config.port);
    final uploadedAssetId = _currentAsset.id;

    try {
      // Show uploading indicator
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Uploading'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_currentAsset.title ?? 'Photo'),
            ],
          ),
        ),
      );

      final response = await uploadService.uploadPhoto(
        _currentAsset,
        directoryPrefix: config.defaultDirectory,
      );

      // Delete from device if setting is enabled
      if (config.deleteAfterUpload) {
        await PhotoManager.editor.deleteWithIds([uploadedAssetId]);
      }

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      final message = config.deleteAfterUpload
          ? 'Uploaded and deleted: ${response.photo.objectId}'
          : 'Uploaded: ${response.photo.objectId}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );

      // Navigate back if photo was deleted
      if (config.deleteAfterUpload && mounted) {
        Navigator.pop(context, uploadedAssetId);
      }
    } on UploadException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: ${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      await uploadService.dispose();
    }
  }

  void _onMenuAction(PhotoViewerAction action) {
    switch (action) {
      case PhotoViewerAction.delete:
        _deletePhoto();
        break;
      case PhotoViewerAction.info:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoInfoView(asset: _currentAsset),
          ),
        );
        break;
      case PhotoViewerAction.upload:
        _uploadPhoto();
        break;
      case PhotoViewerAction.uploadTo:
        _showUploadToDialog();
        break;
      case PhotoViewerAction.rename:
        _renamePhoto();
        break;
    }
  }

  void _showUploadToDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => _UploadToDirectoryDialog(
        onDirectorySelected: (directory) {
          Navigator.pop(dialogContext);
          _uploadPhotoToDirectory(directory);
        },
      ),
    );
  }

  Future<void> _uploadPhotoToDirectory(String directory) async {
    final config = await BackendConfig.load();
    final uploadService = UploadService(host: config.host, port: config.port);
    final uploadedAssetId = _currentAsset.id;

    try {
      // Show uploading indicator
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Uploading'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_currentAsset.title ?? 'Photo'),
              const SizedBox(height: 8),
              Text(
                'to $directory',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );

      final response = await uploadService.uploadPhoto(
        _currentAsset,
        directoryPrefix: directory,
      );

      // Delete from device if setting is enabled
      if (config.deleteAfterUpload) {
        await PhotoManager.editor.deleteWithIds([uploadedAssetId]);
      }

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      final message = config.deleteAfterUpload
          ? 'Uploaded and deleted: ${response.photo.objectId}'
          : 'Uploaded: ${response.photo.objectId}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );

      // Navigate back if photo was deleted
      if (config.deleteAfterUpload && mounted) {
        Navigator.pop(context, uploadedAssetId);
      }
    } on UploadException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: ${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      await uploadService.dispose();
    }
  }

  Widget _buildPhotoPage(int index) {
    final imageData = _imageCache[index];
    final isLoading = _loadingStates[index] ?? true;

    if (isLoading && imageData == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (imageData == null) {
      return const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
      );
    }

    return InteractiveViewer(
      transformationController: _getTransformationController(index),
      minScale: 0.5,
      maxScale: 4.0,
      onInteractionEnd: (_) => _updateZoomState(index),
      child: Image.memory(imageData, fit: BoxFit.contain),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _currentAsset.title ?? 'Photo',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          PopupMenuButton<PhotoViewerAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: _onMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: PhotoViewerAction.info,
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Info'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: PhotoViewerAction.rename,
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Rename'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: PhotoViewerAction.upload,
                child: ListTile(
                  leading: Icon(Icons.cloud_upload),
                  title: Text('Upload'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: PhotoViewerAction.uploadTo,
                child: ListTile(
                  leading: Icon(Icons.cloud_upload_outlined),
                  title: Text('Upload to...'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: PhotoViewerAction.delete,
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
        itemCount: widget.assets.length,
        physics: _isZoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        onPageChanged: _resetZoomOnPageChange,
        itemBuilder: (context, index) => _buildPhotoPage(index),
      ),
    );
  }
}

/// Dialog for selecting a directory to upload a photo to
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

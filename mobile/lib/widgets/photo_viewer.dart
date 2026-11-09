import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/services/library_service.dart';
import 'package:photos/services/upload_service.dart';
import 'package:photos/widgets/device_video_player.dart';
import 'package:photos/widgets/index_keyed_maps.dart';
import 'package:photos/widgets/photo_info_view.dart';
import 'package:photos/widgets/settings_page.dart';

enum PhotoViewerAction {
  info,
  delete,
  upload,
  uploadTo,
  rename,
  rotateAntiClockwise,
}

/// Rotates an encoded image 90 degrees anti-clockwise, keeping its metadata.
///
/// Any EXIF orientation is applied to the pixels first, so the result is
/// rotated relative to how the photo is displayed. The original EXIF data
/// (date taken, GPS, camera, ...) and ICC profile are carried over, with the
/// orientation reset to normal, the pixel dimensions updated and the stale
/// embedded thumbnail dropped. The output is PNG if [png] is true, otherwise
/// JPEG. Returns null if [bytes] cannot be decoded.
Uint8List? rotateImageAntiClockwise(Uint8List bytes, {required bool png}) {
  img.Image? image;
  try {
    image = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (image == null) return null;

  // The JPEG decoder already applies (and removes) the EXIF orientation
  final exif = img.ExifData.from(image.exif);
  final rotated = img.copyRotate(img.bakeOrientation(image), angle: -90);

  if (!exif.isEmpty) {
    exif.imageIfd.orientation = 1;
  }
  if (exif.directories['ifd0']?.sub.containsKey('exif') ?? false) {
    final exifIfd = exif.exifIfd;
    if (exifIfd['ExifImageWidth'] != null) {
      exifIfd['ExifImageWidth'] = img.IfdValueLong(rotated.width);
    }
    if (exifIfd['ExifImageLength'] != null) {
      exifIfd['ExifImageLength'] = img.IfdValueLong(rotated.height);
    }
  }
  exif.directories.remove('ifd1');
  rotated
    ..exif = exif
    ..iccProfile = image.iccProfile;

  return png ? img.encodePng(rotated) : img.encodeJpg(rotated, quality: 95);
}

/// Runs [rotateImageAntiClockwise] on a background isolate.
///
/// This is a top-level function so the closure sent to the isolate captures
/// only [bytes] and [png]. A closure created inside a State method can capture
/// the State itself, which cannot be sent to another isolate.
Future<Uint8List?> rotateImageAntiClockwiseInBackground(
  Uint8List bytes, {
  required bool png,
}) => Isolate.run(() => rotateImageAntiClockwise(bytes, png: png));

class PhotoViewer extends StatefulWidget {
  final List<AssetEntity> assets;
  final int initialIndex;

  /// Called with the asset ID when a photo is deleted from the viewer, which
  /// then advances to the next photo instead of closing.
  final void Function(String assetId)? onDeleted;

  /// Called with the old asset ID and the new asset when a photo is replaced
  /// (e.g. rotated), which the viewer then shows instead of closing.
  final void Function(String oldId, AssetEntity newAsset)? onReplaced;

  const PhotoViewer({
    super.key,
    required this.assets,
    required this.initialIndex,
    this.onDeleted,
    this.onReplaced,
  });

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;
  late final List<AssetEntity> _assets = List.of(widget.assets);
  final Map<int, Uint8List?> _imageCache = {};
  final Map<int, bool> _loadingStates = {};
  final Map<int, TransformationController> _transformationControllers = {};
  final Map<int, DeviceVideoPlayerController> _videoControllers = {};
  bool _isZoomed = false;

  AssetEntity get _currentAsset => _assets[_currentIndex];

  bool _isVideo(int index) => _assets[index].type == AssetType.video;

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
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _preloadImages(int centerIndex) {
    // Load current and adjacent images (skip videos - they load on demand)
    for (int i = centerIndex - 1; i <= centerIndex + 1; i++) {
      if (i >= 0 &&
          i < _assets.length &&
          !_imageCache.containsKey(i) &&
          !_isVideo(i)) {
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
    // Also clean up distant video controllers
    final videoKeysToRemove = <int>[];
    for (final key in _videoControllers.keys) {
      if ((key - currentIndex).abs() > 2) {
        videoKeysToRemove.add(key);
      }
    }
    for (final key in videoKeysToRemove) {
      _videoControllers[key]?.dispose();
      _videoControllers.remove(key);
    }
  }

  Future<void> _loadImage(int index) async {
    if (_loadingStates[index] == true) return;
    _loadingStates[index] = true;

    final asset = _assets[index];
    final data = await asset.originBytes;

    // The photo may have moved to another index if one was deleted meanwhile
    if (mounted && index < _assets.length && _assets[index].id == asset.id) {
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

  DeviceVideoPlayerController _getVideoController(int index) {
    if (!_videoControllers.containsKey(index)) {
      _videoControllers[index] = DeviceVideoPlayerController();
    }
    return _videoControllers[index]!;
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
    // Pause video on the previous page if it was a video
    if (_isVideo(_currentIndex)) {
      _videoControllers[_currentIndex]?.pause();
    }
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
    if (result.isEmpty || !mounted) return;

    final onDeleted = widget.onDeleted;
    if (onDeleted == null) {
      Navigator.pop(context, deletedId);
      return;
    }
    onDeleted(deletedId);

    if (_assets.length == 1) {
      Navigator.pop(context);
      return;
    }
    _removeAssetAt(_currentIndex);
  }

  /// Removes the asset at [index] and shows the next one (or the previous one
  /// if it was the last), shifting the per-index caches to match.
  void _removeAssetAt(int index) {
    final transformationController = _transformationControllers.remove(index);
    final videoController = _videoControllers.remove(index);
    _imageCache.remove(index);
    _loadingStates.remove(index);
    shiftIndexKeysAfter(_imageCache, index);
    shiftIndexKeysAfter(_loadingStates, index);
    shiftIndexKeysAfter(_transformationControllers, index);
    shiftIndexKeysAfter(_videoControllers, index);

    final newIndex = index < _assets.length - 1 ? index : index - 1;
    setState(() {
      _assets.removeAt(index);
      _isZoomed = false;
      _currentIndex = newIndex;
    });
    if (newIndex != index) {
      _pageController.jumpToPage(newIndex);
    }
    _preloadImages(newIndex);

    // Dispose once the deleted page is no longer built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      transformationController?.dispose();
      videoController?.dispose();
    });
  }

  /// Shows [asset] in place of the asset at [index], e.g. after rotating it.
  void _replaceAssetAt(int index, AssetEntity asset) {
    final transformationController = _transformationControllers.remove(index);
    setState(() {
      _assets[index] = asset;
      _imageCache.remove(index);
      _loadingStates.remove(index);
      _isZoomed = false;
    });
    _loadImage(index);

    // Dispose once the old page is no longer built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      transformationController?.dispose();
    });
  }

  Future<void> _renamePhoto() async {
    final renamedId = _currentAsset.id;
    final currentTitle = _currentAsset.title ?? '';
    final isVideo = _currentAsset.type == AssetType.video;
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
        title: Text(isVideo ? 'Rename Video' : 'Rename Photo'),
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
      if (isVideo) {
        // For videos, get the file and save with new name
        final file = await _currentAsset.file;
        if (file == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not access video file'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Save video with new name
        await PhotoManager.editor.saveVideo(file, title: newFileName);
      } else {
        // For images, get the bytes and save with new name
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
      }

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

  Future<void> _rotatePhotoAntiClockwise() async {
    final asset = _currentAsset;
    final rotatedId = asset.id;
    final filename = asset.title ?? 'photo.jpg';
    final isPng = filename.toLowerCase().endsWith('.png');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rotating'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(filename),
          ],
        ),
      ),
    );

    void showError(String message) {
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    try {
      final imageBytes = await asset.originBytes;
      if (imageBytes == null) {
        showError('Could not access photo data');
        return;
      }

      final rotatedBytes = await rotateImageAntiClockwiseInBackground(
        imageBytes,
        png: isPng,
      );
      if (rotatedBytes == null) {
        showError('Rotate failed: unsupported image format');
        return;
      }

      // Save as a new file, keeping the library metadata of the original
      final latitude = asset.latitude;
      final longitude = asset.longitude;
      final hasLocation =
          latitude != null &&
          longitude != null &&
          (latitude != 0 || longitude != 0);
      final newAsset = await PhotoManager.editor.saveImage(
        rotatedBytes,
        filename: filename,
        title: filename,
        relativePath: asset.relativePath,
        creationDate: asset.createDateTime,
        latitude: hasLocation ? latitude : null,
        longitude: hasLocation ? longitude : null,
      );

      // Delete the original file
      await PhotoManager.editor.deleteWithIds([rotatedId]);

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rotated $filename'),
          duration: const Duration(seconds: 2),
        ),
      );

      final onReplaced = widget.onReplaced;
      if (onReplaced == null) {
        Navigator.pop(context, rotatedId);
        return;
      }
      onReplaced(rotatedId, newAsset);
      _replaceAssetAt(_currentIndex, newAsset);
    } on PlatformException catch (e) {
      debugPrint('Rotate failed: $e');
      showError('Rotate failed: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('Rotate failed: $e');
      showError('Rotate failed: ${e.runtimeType}');
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
      case PhotoViewerAction.rotateAntiClockwise:
        _rotatePhotoAntiClockwise();
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
    // Check if this is a video
    if (_isVideo(index)) {
      return DeviceVideoPlayer(
        asset: _assets[index],
        controller: _getVideoController(index),
      );
    }

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
    final isCurrentVideo = _isVideo(_currentIndex);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _currentAsset.title ?? (isCurrentVideo ? 'Video' : 'Photo'),
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
              if (!isCurrentVideo)
                const PopupMenuItem(
                  value: PhotoViewerAction.rotateAntiClockwise,
                  child: ListTile(
                    leading: Icon(Icons.rotate_left),
                    title: Text('Rotate anti-clockwise'),
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
        itemCount: _assets.length,
        physics: _isZoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        onPageChanged: _resetZoomOnPageChange,
        itemBuilder: (context, index) => KeyedSubtree(
          key: ValueKey(_assets[index].id),
          child: _buildPhotoPage(index),
        ),
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

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/widgets/photo_info_view.dart';

enum PhotoViewerAction { info, delete, upload }

class PhotoViewer extends StatefulWidget {
  final AssetEntity asset;

  const PhotoViewer({super.key, required this.asset});

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  Uint8List? _imageData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFullImage();
  }

  Future<void> _loadFullImage() async {
    final data = await widget.asset.originBytes;
    if (mounted) {
      setState(() {
        _imageData = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePhoto() async {
    final result = await PhotoManager.editor.deleteWithIds([widget.asset.id]);
    if (result.isNotEmpty && mounted) {
      Navigator.pop(context, true);
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
            builder: (context) => PhotoInfoView(asset: widget.asset),
          ),
        );
        break;
      case PhotoViewerAction.upload:
        // Not implemented yet
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.asset.title ?? 'Photo',
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
                value: PhotoViewerAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Delete'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                enabled: false,
                value: PhotoViewerAction.upload,
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
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : _imageData != null
            ? InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(_imageData!, fit: BoxFit.contain),
              )
            : const Icon(Icons.broken_image, color: Colors.white54, size: 64),
      ),
    );
  }
}

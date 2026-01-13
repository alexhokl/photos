import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

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

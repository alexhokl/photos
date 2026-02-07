import 'package:flutter/material.dart';
import 'package:photos/proto/photos.pb.dart';

class CloudPhotoInfoView extends StatelessWidget {
  final Photo photo;

  const CloudPhotoInfoView({super.key, required this.photo});

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Cloud Photo Info'),
      ),
      body: ListView(
        children: [
          _InfoTile(
            icon: Icons.label,
            title: 'Object ID',
            value: photo.objectId,
          ),
          _InfoTile(
            icon: Icons.image,
            title: 'Filename',
            value: photo.filename.isNotEmpty
                ? photo.filename
                : photo.objectId.split('/').last,
          ),
          _InfoTile(
            icon: Icons.description,
            title: 'Content Type',
            value: photo.contentType.isNotEmpty ? photo.contentType : 'Unknown',
          ),
          _InfoTile(
            icon: Icons.data_usage,
            title: 'Size',
            value: photo.sizeBytes.toInt() > 0
                ? _formatBytes(photo.sizeBytes.toInt())
                : 'Unknown',
          ),
          _InfoTile(
            icon: Icons.calendar_today,
            title: 'Created',
            value: photo.createdAt.isNotEmpty ? photo.createdAt : 'Unknown',
          ),
          _InfoTile(
            icon: Icons.update,
            title: 'Updated',
            value: photo.updatedAt.isNotEmpty ? photo.updatedAt : 'Unknown',
          ),
          _InfoTile(
            icon: Icons.fingerprint,
            title: 'MD5 Hash',
            value: photo.md5Hash.isNotEmpty ? photo.md5Hash : 'Unknown',
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(value),
    );
  }
}

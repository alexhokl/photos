import 'package:flutter/material.dart';
import 'package:photos/proto/photos.pb.dart';
import 'package:photos/services/library_service.dart';
import 'package:photos/widgets/settings_page.dart';

class CloudPhotoInfoView extends StatefulWidget {
  final Photo photo;

  const CloudPhotoInfoView({super.key, required this.photo});

  @override
  State<CloudPhotoInfoView> createState() => _CloudPhotoInfoViewState();
}

class _CloudPhotoInfoViewState extends State<CloudPhotoInfoView> {
  Photo? _detailedPhoto;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPhotoDetails();
  }

  Future<void> _loadPhotoDetails() async {
    LibraryService? libraryService;
    try {
      final config = await BackendConfig.load();
      libraryService = LibraryService(host: config.host, port: config.port);
      final photo = await libraryService.getPhoto(widget.photo.objectId);
      if (mounted) {
        setState(() {
          _detailedPhoto = photo;
          _isLoading = false;
        });
      }
    } on LibraryException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    } finally {
      await libraryService?.dispose();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatLocation(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  String _formatDimensions(int width, int height) {
    return '$width x $height pixels';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Cloud Photo Info'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load photo details: $_errorMessage',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadPhotoDetails();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final photo = _detailedPhoto!;
    return ListView(
      children: [
        _InfoTile(icon: Icons.label, title: 'Object ID', value: photo.objectId),
        if (photo.originalFilename.isNotEmpty)
          _InfoTile(
            icon: Icons.insert_drive_file,
            title: 'Original Filename',
            value: photo.originalFilename,
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
        if (photo.hasDimensions)
          _InfoTile(
            icon: Icons.aspect_ratio,
            title: 'Dimensions',
            value: _formatDimensions(photo.width, photo.height),
          ),
        if (photo.hasDateTaken_12)
          _InfoTile(
            icon: Icons.camera_alt,
            title: 'Date Taken',
            value: photo.dateTaken,
          ),
        if (photo.hasLocation)
          _InfoTile(
            icon: Icons.location_on,
            title: 'Location',
            value: _formatLocation(photo.latitude, photo.longitude),
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

import 'package:flutter/material.dart';
import 'package:photos/proto/photos.pb.dart';
import 'package:photos/services/library_service.dart';
import 'package:photos/widgets/settings_page.dart';
import 'package:url_launcher/url_launcher.dart';

class CloudPhotoInfoView extends StatefulWidget {
  final Photo photo;

  /// If true, skip the async fetch and use the provided photo directly.
  /// This is useful for testing or when the photo already has all required data.
  final bool skipFetch;

  const CloudPhotoInfoView({
    super.key,
    required this.photo,
    this.skipFetch = false,
  });

  @override
  State<CloudPhotoInfoView> createState() => _CloudPhotoInfoViewState();
}

class _CloudPhotoInfoViewState extends State<CloudPhotoInfoView> {
  Photo? _detailedPhoto;
  late bool _isLoading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.skipFetch) {
      _detailedPhoto = widget.photo;
      _isLoading = false;
    } else {
      _isLoading = true;
      _loadPhotoDetails();
    }
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

  String _getGoogleMapsUrl(double latitude, double longitude) {
    return 'https://www.google.com/maps?q=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
  }

  String _formatExposureTime(double exposureTime) {
    if (exposureTime <= 0) return '';
    if (exposureTime >= 1) {
      return '${exposureTime.toStringAsFixed(1)}s';
    }
    // Convert to fraction (e.g., 0.001 -> 1/1000)
    final denominator = (1 / exposureTime).round();
    return '1/${denominator}s';
  }

  String _formatAperture(double aperture) {
    if (aperture <= 0) return '';
    return 'f/${aperture.toStringAsFixed(1)}';
  }

  String _formatFocalLength(double focalLength) {
    if (focalLength <= 0) return '';
    return '${focalLength.toStringAsFixed(1)}mm';
  }

  Future<void> _launchGoogleMaps(double latitude, double longitude) async {
    final url = Uri.parse(_getGoogleMapsUrl(latitude, longitude));
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Metadata'),
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
    final hasCameraInfo =
        photo.cameraMake.isNotEmpty ||
        photo.cameraModel.isNotEmpty ||
        photo.lensModel.isNotEmpty;
    final hasExposureInfo =
        photo.focalLength > 0 ||
        photo.aperture > 0 ||
        photo.exposureTime > 0 ||
        photo.iso > 0;

    return ListView(
      children: [
        // File Information section
        const _SectionHeader(title: 'FILE INFORMATION'),
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

        // Location section
        if (photo.hasLocation) const _SectionHeader(title: 'LOCATION'),
        if (photo.hasLocation)
          _InfoTile(
            icon: Icons.location_on,
            title: 'Location',
            value: _formatLocation(photo.latitude, photo.longitude),
          ),
        if (photo.hasLocation)
          _TappableInfoTile(
            icon: Icons.map,
            title: 'Google Maps',
            value: _getGoogleMapsUrl(photo.latitude, photo.longitude),
            onTap: () => _launchGoogleMaps(photo.latitude, photo.longitude),
          ),

        // Camera section
        if (hasCameraInfo) const _SectionHeader(title: 'CAMERA'),
        if (photo.cameraMake.isNotEmpty)
          _InfoTile(
            icon: Icons.business,
            title: 'Camera Make',
            value: photo.cameraMake,
          ),
        if (photo.cameraModel.isNotEmpty)
          _InfoTile(
            icon: Icons.camera,
            title: 'Camera Model',
            value: photo.cameraModel,
          ),
        if (photo.lensModel.isNotEmpty)
          _InfoTile(
            icon: Icons.camera_outdoor,
            title: 'Lens',
            value: photo.lensModel,
          ),

        // Exposure Settings section
        if (hasExposureInfo) const _SectionHeader(title: 'EXPOSURE SETTINGS'),
        if (photo.focalLength > 0)
          _InfoTile(
            icon: Icons.straighten,
            title: 'Focal Length',
            value: _formatFocalLength(photo.focalLength),
          ),
        if (photo.aperture > 0)
          _InfoTile(
            icon: Icons.camera,
            title: 'Aperture',
            value: _formatAperture(photo.aperture),
          ),
        if (photo.exposureTime > 0)
          _InfoTile(
            icon: Icons.shutter_speed,
            title: 'Shutter Speed',
            value: _formatExposureTime(photo.exposureTime),
          ),
        if (photo.iso > 0)
          _InfoTile(icon: Icons.iso, title: 'ISO', value: photo.iso.toString()),

        // System section
        const _SectionHeader(title: 'SYSTEM'),
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

class _TappableInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  const _TappableInfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        value,
        style: const TextStyle(decoration: TextDecoration.underline),
      ),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

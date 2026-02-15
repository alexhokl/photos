import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/services/exif_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PhotoInfoView extends StatefulWidget {
  final AssetEntity asset;

  /// Optional pre-loaded EXIF metadata for testing.
  /// When provided, skips loading EXIF from the asset.
  final ExifMetadata? exifMetadata;

  /// If true, skip the async EXIF extraction.
  /// This is useful for testing or when EXIF data is pre-loaded.
  final bool skipExifExtraction;

  const PhotoInfoView({
    super.key,
    required this.asset,
    this.exifMetadata,
    this.skipExifExtraction = false,
  });

  @override
  State<PhotoInfoView> createState() => _PhotoInfoViewState();
}

class _PhotoInfoViewState extends State<PhotoInfoView> {
  LatLng? _latLng;
  bool _isLoadingLocation = true;
  ExifMetadata? _exifMetadata;
  bool _isLoadingExif = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
    if (widget.skipExifExtraction) {
      _exifMetadata = widget.exifMetadata;
      _isLoadingExif = false;
    } else {
      _loadExifData();
    }
  }

  Future<void> _loadLocation() async {
    final latLng = await widget.asset.latlngAsync();
    if (mounted) {
      setState(() {
        _latLng = latLng;
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _loadExifData() async {
    try {
      final bytes = await widget.asset.originBytes;
      if (bytes != null && mounted) {
        final metadata = await ExifService.extractMetadata(bytes);
        if (mounted) {
          setState(() {
            _exifMetadata = metadata;
            _isLoadingExif = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _exifMetadata = const ExifMetadata();
          _isLoadingExif = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _exifMetadata = const ExifMetadata();
          _isLoadingExif = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  String _formatLocation(LatLng? latLng) {
    if (latLng == null) {
      return 'Unknown';
    }
    return '${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}';
  }

  String _getGoogleMapsUrl(LatLng latLng) {
    return 'https://www.google.com/maps?q=${latLng.latitude.toStringAsFixed(6)},${latLng.longitude.toStringAsFixed(6)}';
  }

  Future<void> _launchGoogleMaps(LatLng latLng) async {
    final url = Uri.parse(_getGoogleMapsUrl(latLng));
    await launchUrl(url, mode: LaunchMode.externalApplication);
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
    final exif = _exifMetadata;
    final hasCameraInfo = exif?.hasCameraInfo ?? false;
    final hasExposureInfo = exif?.hasExposureInfo ?? false;
    final hasLocation = !_isLoadingLocation && _latLng != null;

    return ListView(
      children: [
        // File Information section
        const _SectionHeader(title: 'FILE INFORMATION'),
        _InfoTile(
          icon: Icons.image,
          title: 'Filename',
          value: widget.asset.title ?? 'Unknown',
        ),
        _InfoTile(
          icon: Icons.aspect_ratio,
          title: 'Dimensions',
          value: '${widget.asset.width} x ${widget.asset.height} pixels',
        ),
        _InfoTile(
          icon: Icons.calendar_today,
          title: 'Date Taken',
          value: _formatDateTime(widget.asset.createDateTime),
        ),

        // Location section
        if (hasLocation) const _SectionHeader(title: 'LOCATION'),
        if (!hasLocation)
          _InfoTile(
            icon: Icons.location_on,
            title: 'Location',
            value: _isLoadingLocation ? 'Loading...' : 'Unknown',
          ),
        if (hasLocation)
          _InfoTile(
            icon: Icons.location_on,
            title: 'Location',
            value: _formatLocation(_latLng),
          ),
        if (hasLocation)
          _TappableInfoTile(
            icon: Icons.map,
            title: 'Google Maps',
            value: _getGoogleMapsUrl(_latLng!),
            onTap: () => _launchGoogleMaps(_latLng!),
          ),

        // Camera section
        if (_isLoadingExif)
          const _InfoTile(
            icon: Icons.camera,
            title: 'Camera Info',
            value: 'Loading...',
          ),
        if (!_isLoadingExif && hasCameraInfo)
          const _SectionHeader(title: 'CAMERA'),
        if (!_isLoadingExif && (exif?.cameraMake?.isNotEmpty ?? false))
          _InfoTile(
            icon: Icons.business,
            title: 'Camera Make',
            value: exif!.cameraMake!,
          ),
        if (!_isLoadingExif && (exif?.cameraModel?.isNotEmpty ?? false))
          _InfoTile(
            icon: Icons.camera,
            title: 'Camera Model',
            value: exif!.cameraModel!,
          ),
        if (!_isLoadingExif && (exif?.lensModel?.isNotEmpty ?? false))
          _InfoTile(
            icon: Icons.camera_outdoor,
            title: 'Lens',
            value: exif!.lensModel!,
          ),

        // Exposure Settings section
        if (!_isLoadingExif && hasExposureInfo)
          const _SectionHeader(title: 'EXPOSURE SETTINGS'),
        if (!_isLoadingExif && (exif?.focalLength ?? 0) > 0)
          _InfoTile(
            icon: Icons.straighten,
            title: 'Focal Length',
            value: _formatFocalLength(exif!.focalLength!),
          ),
        if (!_isLoadingExif && (exif?.aperture ?? 0) > 0)
          _InfoTile(
            icon: Icons.camera,
            title: 'Aperture',
            value: _formatAperture(exif!.aperture!),
          ),
        if (!_isLoadingExif && (exif?.exposureTime ?? 0) > 0)
          _InfoTile(
            icon: Icons.shutter_speed,
            title: 'Shutter Speed',
            value: _formatExposureTime(exif!.exposureTime!),
          ),
        if (!_isLoadingExif && (exif?.iso ?? 0) > 0)
          _InfoTile(icon: Icons.iso, title: 'ISO', value: exif!.iso.toString()),
      ],
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

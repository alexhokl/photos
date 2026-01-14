import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoInfoView extends StatefulWidget {
  final AssetEntity asset;

  const PhotoInfoView({super.key, required this.asset});

  @override
  State<PhotoInfoView> createState() => _PhotoInfoViewState();
}

class _PhotoInfoViewState extends State<PhotoInfoView> {
  LatLng? _latLng;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Metadata Info'),
      ),
      body: ListView(
        children: [
          _InfoTile(
            icon: Icons.image,
            title: 'Filename',
            value: widget.asset.title ?? 'Unknown',
          ),
          _InfoTile(
            icon: Icons.aspect_ratio,
            title: 'Size',
            value: '${widget.asset.width} x ${widget.asset.height} pixels',
          ),
          _InfoTile(
            icon: Icons.calendar_today,
            title: 'Date Taken',
            value: _formatDateTime(widget.asset.createDateTime),
          ),
          _InfoTile(
            icon: Icons.location_on,
            title: 'Location',
            value: _isLoadingLocation ? 'Loading...' : _formatLocation(_latLng),
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

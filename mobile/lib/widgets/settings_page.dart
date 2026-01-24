import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parsed backend URL configuration
class BackendConfig {
  final String host;
  final int port;

  const BackendConfig({required this.host, required this.port});

  /// Parse a URL string into host and port
  /// Defaults to port 443 for https, 80 for http if not specified
  factory BackendConfig.fromUrl(String url) {
    final uri = Uri.parse(url);
    final host = uri.host;
    int port;

    if (uri.hasPort) {
      port = uri.port;
    } else {
      // Default ports based on scheme
      port = uri.scheme == 'https' ? 443 : 80;
    }

    return BackendConfig(host: host, port: port);
  }

  /// Load backend configuration from shared preferences
  static Future<BackendConfig> load() async {
    final prefs = SharedPreferencesAsync();
    final url =
        await prefs.getString(SettingsPage.backendUrlKey) ??
        SettingsPage.defaultBackendUrl;
    return BackendConfig.fromUrl(url);
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  static const String backendUrlKey = 'backend_url';
  static const String defaultBackendUrl = 'https://photos.a-b.ts.net';

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _backendUrlController = TextEditingController();
  late final SharedPreferencesAsync _prefs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPreferences();
  }

  Future<void> _initPreferences() async {
    _prefs = SharedPreferencesAsync();
    final savedUrl = await _prefs.getString(SettingsPage.backendUrlKey);
    setState(() {
      _backendUrlController.text = savedUrl ?? SettingsPage.defaultBackendUrl;
      _isLoading = false;
    });
  }

  Future<void> _saveBackendUrl(String url) async {
    await _prefs.setString(SettingsPage.backendUrlKey, url);
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backend Configuration',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _backendUrlController,
            decoration: const InputDecoration(
              labelText: 'Backend Service URL',
              hintText: 'Enter the backend service URL',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.cloud),
            ),
            keyboardType: TextInputType.url,
            onChanged: _saveBackendUrl,
          ),
        ],
      ),
    );
  }
}

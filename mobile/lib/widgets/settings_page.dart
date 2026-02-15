import 'package:flutter/material.dart';
import 'package:photos/services/library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parsed backend URL configuration
class BackendConfig {
  final String host;
  final int port;
  final String defaultDirectory;
  final bool deleteAfterUpload;
  final int uploadTimeoutSeconds;
  final int signedUrlExpirationSeconds;

  const BackendConfig({
    required this.host,
    required this.port,
    this.defaultDirectory = '',
    this.deleteAfterUpload = false,
    this.uploadTimeoutSeconds = SettingsPage.defaultUploadTimeoutSeconds,
    this.signedUrlExpirationSeconds =
        SettingsPage.defaultSignedUrlExpirationSeconds,
  });

  /// Parse a URL string into host and port
  /// Defaults to port 443 for https, 80 for http if not specified
  factory BackendConfig.fromUrl(
    String url, {
    String defaultDirectory = '',
    bool deleteAfterUpload = false,
    int uploadTimeoutSeconds = SettingsPage.defaultUploadTimeoutSeconds,
    int signedUrlExpirationSeconds =
        SettingsPage.defaultSignedUrlExpirationSeconds,
  }) {
    final uri = Uri.parse(url);
    final host = uri.host;
    int port;

    if (uri.hasPort) {
      port = uri.port;
    } else {
      // Default ports based on scheme
      port = uri.scheme == 'https' ? 443 : 80;
    }

    return BackendConfig(
      host: host,
      port: port,
      defaultDirectory: defaultDirectory,
      deleteAfterUpload: deleteAfterUpload,
      uploadTimeoutSeconds: uploadTimeoutSeconds,
      signedUrlExpirationSeconds: signedUrlExpirationSeconds,
    );
  }

  /// Load backend configuration from shared preferences
  static Future<BackendConfig> load() async {
    final prefs = SharedPreferencesAsync();
    final url =
        await prefs.getString(SettingsPage.backendUrlKey) ??
        SettingsPage.defaultBackendUrl;
    final defaultDir =
        await prefs.getString(SettingsPage.defaultDirectoryKey) ?? '';
    final deleteAfterUpload =
        await prefs.getBool(SettingsPage.deleteAfterUploadKey) ?? false;
    final uploadTimeoutSeconds =
        await prefs.getInt(SettingsPage.uploadTimeoutKey) ??
        SettingsPage.defaultUploadTimeoutSeconds;
    final signedUrlExpirationSeconds =
        await prefs.getInt(SettingsPage.signedUrlExpirationKey) ??
        SettingsPage.defaultSignedUrlExpirationSeconds;
    return BackendConfig.fromUrl(
      url,
      defaultDirectory: defaultDir,
      deleteAfterUpload: deleteAfterUpload,
      uploadTimeoutSeconds: uploadTimeoutSeconds,
      signedUrlExpirationSeconds: signedUrlExpirationSeconds,
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.isActive = true});

  final bool isActive;

  static const String backendUrlKey = 'backend_url';
  static const String defaultBackendUrl = 'https://photos.a-b.ts.net';
  static const String defaultDirectoryKey = 'default_directory';
  static const String deleteAfterUploadKey = 'delete_after_upload';
  static const String uploadTimeoutKey = 'upload_timeout_seconds';
  static const int defaultUploadTimeoutSeconds = 30;
  static const String signedUrlExpirationKey = 'signed_url_expiration_seconds';
  static const int defaultSignedUrlExpirationSeconds = 300;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _backendUrlController = TextEditingController();
  final TextEditingController _directoryController = TextEditingController();
  final TextEditingController _uploadTimeoutController =
      TextEditingController();
  final TextEditingController _signedUrlExpirationController =
      TextEditingController();
  late final SharedPreferencesAsync _prefs;
  bool _isLoading = true;
  List<String> _directorySuggestions = [];
  bool _isLoadingDirectories = false;
  String? _directoryError;
  bool _hasInitiallyLoaded = false;
  bool _deleteAfterUpload = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _hasInitiallyLoaded = true;
      _initPreferences();
    }
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_hasInitiallyLoaded) {
      _hasInitiallyLoaded = true;
      _initPreferences();
    }
  }

  Future<void> _initPreferences() async {
    _prefs = SharedPreferencesAsync();
    final savedUrl = await _prefs.getString(SettingsPage.backendUrlKey);
    final savedDirectory = await _prefs.getString(
      SettingsPage.defaultDirectoryKey,
    );
    final deleteAfterUpload = await _prefs.getBool(
      SettingsPage.deleteAfterUploadKey,
    );
    final uploadTimeoutSeconds = await _prefs.getInt(
      SettingsPage.uploadTimeoutKey,
    );
    final signedUrlExpirationSeconds = await _prefs.getInt(
      SettingsPage.signedUrlExpirationKey,
    );
    setState(() {
      _backendUrlController.text = savedUrl ?? SettingsPage.defaultBackendUrl;
      _directoryController.text = savedDirectory ?? '';
      _deleteAfterUpload = deleteAfterUpload ?? false;
      _uploadTimeoutController.text =
          (uploadTimeoutSeconds ?? SettingsPage.defaultUploadTimeoutSeconds)
              .toString();
      _signedUrlExpirationController.text =
          (signedUrlExpirationSeconds ??
                  SettingsPage.defaultSignedUrlExpirationSeconds)
              .toString();
      _isLoading = false;
    });
    // Load directory suggestions after preferences are loaded
    _loadDirectorySuggestions();
  }

  Future<void> _saveBackendUrl(String url) async {
    await _prefs.setString(SettingsPage.backendUrlKey, url);
    // Reload directory suggestions when backend URL changes
    _loadDirectorySuggestions();
  }

  Future<void> _saveDefaultDirectory(String directory) async {
    await _prefs.setString(SettingsPage.defaultDirectoryKey, directory);
  }

  Future<void> _saveDeleteAfterUpload(bool value) async {
    await _prefs.setBool(SettingsPage.deleteAfterUploadKey, value);
  }

  Future<void> _saveUploadTimeout(String value) async {
    final seconds = int.tryParse(value);
    if (seconds != null && seconds > 0) {
      await _prefs.setInt(SettingsPage.uploadTimeoutKey, seconds);
    }
  }

  Future<void> _saveSignedUrlExpiration(String value) async {
    final seconds = int.tryParse(value);
    if (seconds != null && seconds > 0 && seconds <= 604800) {
      await _prefs.setInt(SettingsPage.signedUrlExpirationKey, seconds);
    }
  }

  Future<void> _loadDirectorySuggestions() async {
    setState(() {
      _isLoadingDirectories = true;
      _directoryError = null;
    });

    try {
      final config = BackendConfig.fromUrl(_backendUrlController.text);
      final libraryService = LibraryService(
        host: config.host,
        port: config.port,
      );

      final directories = await libraryService.listDirectories(recursive: true);
      await libraryService.dispose();

      setState(() {
        _directorySuggestions = directories
            .map((d) => d.endsWith('/') ? d : '$d/')
            .toList();
        _isLoadingDirectories = false;
      });
    } catch (e) {
      setState(() {
        _directoryError = 'Failed to load directories';
        _isLoadingDirectories = false;
      });
    }
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    _directoryController.dispose();
    _uploadTimeoutController.dispose();
    _signedUrlExpirationController.dispose();
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
          const SizedBox(height: 24),
          Text(
            'Upload Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (_directorySuggestions.isEmpty) {
                return const Iterable<String>.empty();
              }
              // Filter suggestions based on user input
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
              _saveDefaultDirectory(selection);
            },
            fieldViewBuilder:
                (
                  BuildContext context,
                  TextEditingController fieldController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  // Sync the field controller with our controller on first build
                  if (fieldController.text.isEmpty &&
                      _directoryController.text.isNotEmpty) {
                    fieldController.text = _directoryController.text;
                  }
                  return TextField(
                    controller: fieldController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Default Upload Directory',
                      hintText: 'Enter or select a directory prefix',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.folder),
                      suffixIcon: _isLoadingDirectories
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _loadDirectorySuggestions,
                              tooltip: 'Refresh directories',
                            ),
                      errorText: _directoryError,
                      helperText:
                          'Photos will be uploaded to this directory by default',
                    ),
                    onChanged: (value) {
                      _directoryController.text = value;
                      _saveDefaultDirectory(value);
                    },
                    onSubmitted: (_) => onFieldSubmitted(),
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
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Delete after upload'),
            subtitle: const Text(
              'Automatically delete photos from device after successful upload',
            ),
            value: _deleteAfterUpload,
            onChanged: (value) {
              setState(() {
                _deleteAfterUpload = value;
              });
              _saveDeleteAfterUpload(value);
            },
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _uploadTimeoutController,
            decoration: const InputDecoration(
              labelText: 'Upload timeout (in seconds)',
              hintText: 'Enter timeout in seconds',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.timer),
              helperText:
                  'Time to wait for each photo upload before timing out',
            ),
            keyboardType: TextInputType.number,
            onChanged: _saveUploadTimeout,
          ),
          const SizedBox(height: 24),
          Text(
            'Photo Viewing Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _signedUrlExpirationController,
            decoration: const InputDecoration(
              labelText: 'Signed URL expiration (in seconds)',
              hintText: 'Enter expiration in seconds',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
              helperText:
                  'How long photo URLs remain valid (max 604800 = 7 days)',
            ),
            keyboardType: TextInputType.number,
            onChanged: _saveSignedUrlExpiration,
          ),
        ],
      ),
    );
  }
}

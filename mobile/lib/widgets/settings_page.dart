import 'package:flutter/material.dart';
import 'package:photos/services/library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parsed backend URL configuration
class BackendConfig {
  final String host;
  final int port;
  final String defaultDirectory;

  const BackendConfig({
    required this.host,
    required this.port,
    this.defaultDirectory = '',
  });

  /// Parse a URL string into host and port
  /// Defaults to port 443 for https, 80 for http if not specified
  factory BackendConfig.fromUrl(String url, {String defaultDirectory = ''}) {
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
    return BackendConfig.fromUrl(url, defaultDirectory: defaultDir);
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  static const String backendUrlKey = 'backend_url';
  static const String defaultBackendUrl = 'https://photos.a-b.ts.net';
  static const String defaultDirectoryKey = 'default_directory';

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _backendUrlController = TextEditingController();
  final TextEditingController _directoryController = TextEditingController();
  late final SharedPreferencesAsync _prefs;
  bool _isLoading = true;
  List<String> _directorySuggestions = [];
  bool _isLoadingDirectories = false;
  String? _directoryError;

  @override
  void initState() {
    super.initState();
    _initPreferences();
  }

  Future<void> _initPreferences() async {
    _prefs = SharedPreferencesAsync();
    final savedUrl = await _prefs.getString(SettingsPage.backendUrlKey);
    final savedDirectory = await _prefs.getString(
      SettingsPage.defaultDirectoryKey,
    );
    setState(() {
      _backendUrlController.text = savedUrl ?? SettingsPage.defaultBackendUrl;
      _directoryController.text = savedDirectory ?? '';
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
        _directorySuggestions = directories;
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
        ],
      ),
    );
  }
}

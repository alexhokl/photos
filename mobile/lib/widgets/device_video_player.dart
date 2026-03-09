import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

/// Controller for DeviceVideoPlayer that allows external control.
class DeviceVideoPlayerController extends ChangeNotifier {
  _DeviceVideoPlayerState? _state;

  void _attach(_DeviceVideoPlayerState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  /// Pause the video playback.
  void pause() {
    _state?.pause();
  }

  /// Play the video.
  void play() {
    _state?.play();
  }

  /// Check if the video is currently playing.
  bool get isPlaying => _state?.isPlaying ?? false;

  /// Check if the video is initialized.
  bool get isInitialized => _state?._isInitialized ?? false;
}

/// A video player widget for displaying device local videos.
/// Takes an AssetEntity and handles video playback with controls.
class DeviceVideoPlayer extends StatefulWidget {
  final AssetEntity asset;
  final bool autoPlay;
  final DeviceVideoPlayerController? controller;

  const DeviceVideoPlayer({
    super.key,
    required this.asset,
    this.autoPlay = false,
    this.controller,
  });

  @override
  State<DeviceVideoPlayer> createState() => _DeviceVideoPlayerState();
}

class _DeviceVideoPlayerState extends State<DeviceVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _initializeController();
  }

  Future<void> _initializeController() async {
    try {
      final file = await widget.asset.file;
      if (file == null) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Could not access video file';
          });
        }
        return;
      }

      _controller = VideoPlayerController.file(file);
      _controller!.addListener(_onVideoStateChanged);

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        if (widget.autoPlay) {
          _controller!.play();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onVideoStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _controller?.removeListener(_onVideoStateChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  /// Play the video.
  void play() {
    if (_isInitialized &&
        _controller != null &&
        !_controller!.value.isPlaying) {
      _controller!.play();
    }
  }

  /// Pause the video. Called externally when navigating away.
  void pause() {
    if (_isInitialized && _controller != null && _controller!.value.isPlaying) {
      _controller!.pause();
    }
  }

  /// Check if the video is currently playing.
  bool get isPlaying =>
      _isInitialized && _controller != null && _controller!.value.isPlaying;

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Failed to load video',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video player
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),

          // Play/Pause overlay (always visible when paused)
          if (!_controller!.value.isPlaying || _showControls)
            AnimatedOpacity(
              opacity: _showControls || !_controller!.value.isPlaying
                  ? 1.0
                  : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _controller!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    size: 64,
                    color: Colors.white,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
            ),

          // Bottom controls
          if (_showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress bar
                    VideoProgressIndicator(
                      _controller!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.white,
                        bufferedColor: Colors.white38,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Time display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_controller!.value.position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(_controller!.value.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Buffering indicator
          if (_controller!.value.isBuffering)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}

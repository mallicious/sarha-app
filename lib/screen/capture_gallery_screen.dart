import 'package:flutter/material.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import '../services/image_upload_services.dart';
import 'package:intl/intl.dart';

class CaptureGalleryScreen extends StatefulWidget {
  const CaptureGalleryScreen({super.key});

  @override
  State<CaptureGalleryScreen> createState() => _CaptureGalleryScreenState();
}

class _CaptureGalleryScreenState extends State<CaptureGalleryScreen> {
  static const Color softLavender = Color(0xFFA7B5F4);
  static const Color coral = Color(0xFFFF9B85);
  static const Color cream = Color(0xFFFAF8F5);
  static const Color deepPurple = Color(0xFF4A4063);

  final ImageUploadService _uploadService = ImageUploadService();
  List<Map<String, dynamic>> _captures = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCaptures();
  }

  Future<void> _loadCaptures() async {
    setState(() => _isLoading = true);

    final captures = await _uploadService.getAllCaptures();

    if (mounted) {
      setState(() {
        _captures = captures;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCapture(String captureId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Capture?', style: TextStyle(color: deepPurple)),
        content: Text(
          'This action cannot be undone.',
          style: TextStyle(color: deepPurple.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: coral),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _uploadService.deleteCapture(captureId);
      if (success) {
        _loadCaptures();
        _showSnackBar('Capture deleted', Colors.green[400]!);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('My Captures',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: softLavender,
        foregroundColor: deepPurple,
        elevation: 0,
        actions: [
          if (_captures.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_rounded),
              onPressed: _deleteAllCaptures,
              tooltip: 'Delete All',
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: coral))
          : _captures.isEmpty
              ? _buildEmptyState()
              : _buildGalleryGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 80, color: deepPurple.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No captures yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the AR camera to capture hazards',
            style: TextStyle(
              color: deepPurple.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _captures.length,
      itemBuilder: (context, index) {
        final capture = _captures[index];
        return _buildCaptureCard(capture);
      },
    );
  }

  Widget _buildCaptureCard(Map<String, dynamic> capture) {
    final isPhoto = capture['type'] == 'photo';
    final timestamp = DateTime.parse(capture['timestamp']);
    final dateStr = DateFormat('MMM d, h:mm a').format(timestamp);

    return GestureDetector(
      onTap: () => _viewCapture(capture),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isPhoto)
                      Image.file(
                        File(capture['path']),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: deepPurple.withOpacity(0.1),
                            child: Icon(Icons.broken_image_rounded,
                                color: coral, size: 48),
                          );
                        },
                      )
                    else
                      Container(
                        color: Colors.black,
                        child: Icon(Icons.play_circle_outline_rounded,
                            color: Colors.white, size: 64),
                      ),

                    // Type Badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPhoto ? coral : softLavender,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPhoto
                                  ? Icons.photo_rounded
                                  : Icons.videocam_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPhoto ? 'Photo' : 'Video',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: deepPurple.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _viewCapture(capture),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: softLavender,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('View',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon:
                            Icon(Icons.delete_rounded, color: coral, size: 20),
                        onPressed: () => _deleteCapture(capture['id']),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewCapture(Map<String, dynamic> capture) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CaptureViewScreen(capture: capture),
      ),
    );
  }

  Future<void> _deleteAllCaptures() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            Text('Delete All Captures?', style: TextStyle(color: deepPurple)),
        content: Text(
          'This will permanently delete all ${_captures.length} captures.',
          style: TextStyle(color: deepPurple.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _uploadService.deleteAllCaptures();
      if (success) {
        _loadCaptures();
        _showSnackBar('All captures deleted', Colors.green[400]!);
      }
    }
  }
}

// === FULL SCREEN CAPTURE VIEWER ===
class CaptureViewScreen extends StatefulWidget {
  final Map<String, dynamic> capture;

  const CaptureViewScreen({super.key, required this.capture});

  @override
  State<CaptureViewScreen> createState() => _CaptureViewScreenState();
}

class _CaptureViewScreenState extends State<CaptureViewScreen> {
  static const Color deepPurple = Color(0xFF4A4063);
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.capture['type'] == 'video') {
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.file(File(widget.capture['path']));
    await _videoController!.initialize();
    setState(() => _isVideoInitialized = true);
  }

  @override
  Widget build(BuildContext context) {
    final isPhoto = widget.capture['type'] == 'photo';
    final timestamp = DateTime.parse(widget.capture['timestamp']);
    final dateStr = DateFormat('MMMM d, yyyy • h:mm a').format(timestamp);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: isPhoto
                  ? InteractiveViewer(
                      child: Image.file(
                        File(widget.capture['path']),
                        fit: BoxFit.contain,
                      ),
                    )
                  : _isVideoInitialized
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                            IconButton(
                              icon: Icon(
                                _videoController!.value.isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                size: 64,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_videoController!.value.isPlaying) {
                                    _videoController!.pause();
                                  } else {
                                    _videoController!.play();
                                  }
                                });
                              },
                            ),
                          ],
                        )
                      : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: deepPurple,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isPhoto ? Icons.photo_rounded : Icons.videocam_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isPhoto ? 'Photo Capture' : 'Video Capture',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

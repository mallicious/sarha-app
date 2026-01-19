import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DashcamService {
  static final DashcamService _instance = DashcamService._internal();
  factory DashcamService() => _instance;
  DashcamService._internal();

  CameraController? _controller;
  bool _isRecording = false;
  String? _videoPath;
  DateTime? _recordingStartTime;

  bool get isRecording => _isRecording;
  CameraController? get controller => _controller;
  Duration? get recordingDuration => _recordingStartTime != null
      ? DateTime.now().difference(_recordingStartTime!)
      : null;

  // Initialize camera
  Future<bool> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('❌ No cameras found');
        return false;
      }

      // Use back camera
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      print('✅ Camera initialized');
      return true;
    } catch (e) {
      print('❌ Camera initialization error: $e');
      return false;
    }
  }

  // Start recording
  Future<bool> startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print('❌ Camera not initialized');
      return false;
    }

    if (_isRecording) {
      print('⚠️ Already recording');
      return false;
    }

    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _videoPath = '${directory.path}/dashcam_$timestamp.mp4';

      await _controller!.startVideoRecording();
      _isRecording = true;
      _recordingStartTime = DateTime.now();

      print('🔴 Recording started: $_videoPath');
      return true;
    } catch (e) {
      print('❌ Start recording error: $e');
      return false;
    }
  }

  // Stop recording
  Future<String?> stopRecording() async {
    if (!_isRecording || _controller == null) {
      print('⚠️ Not recording');
      return null;
    }

    try {
      final video = await _controller!.stopVideoRecording();
      _isRecording = false;
      _videoPath = video.path;
      _recordingStartTime = null;

      print('⏹️ Recording stopped: $_videoPath');
      return _videoPath;
    } catch (e) {
      print('❌ Stop recording error: $e');
      _isRecording = false;
      _recordingStartTime = null;
      return null;
    }
  }

  // Upload video to Firebase Storage
  Future<String?> uploadVideo(String videoPath, String hazardId) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        print('❌ Video file not found');
        return null;
      }

      final ref = FirebaseStorage.instance
          .ref()
          .child('dashcam_videos')
          .child('$hazardId.mp4');

      print('📤 Uploading video...');
      final uploadTask = ref.putFile(file);

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Video uploaded: $downloadUrl');

      // Delete local file after upload
      await file.delete();

      return downloadUrl;
    } catch (e) {
      print('❌ Upload error: $e');
      return null;
    }
  }

  // Dispose camera
  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isRecording = false;
    _recordingStartTime = null;
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final ImagePicker _picker = ImagePicker();
  static const String _capturesKey = 'ar_captures';

  // === GET PERMANENT DIRECTORY FOR MEDIA ===
  Future<Directory> _getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/hazard_captures');
    
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    
    return mediaDir;
  }

  // === SAVE PHOTO FROM CAMERA ===
  Future<Map<String, dynamic>?> savePhotoFromCamera(String tempPath) async {
    try {
      final mediaDir = await _getMediaDirectory();
      final fileName = 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final permanentPath = path.join(mediaDir.path, fileName);
      
      // Copy from temp to permanent location
      final File sourceFile = File(tempPath);
      await sourceFile.copy(permanentPath);
      
      final captureData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'path': permanentPath,
        'type': 'photo',
        'timestamp': DateTime.now().toIso8601String(),
        'fileName': fileName,
      };
      
      await _saveCaptureToPrefs(captureData);
      
      print('✅ Photo saved: $permanentPath');
      return captureData;
    } catch (e) {
      print('❌ Save photo error: $e');
      return null;
    }
  }

  // === SAVE VIDEO FROM CAMERA ===
  Future<Map<String, dynamic>?> saveVideoFromCamera(String tempPath) async {
    try {
      final mediaDir = await _getMediaDirectory();
      final fileName = 'VID_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final permanentPath = path.join(mediaDir.path, fileName);
      
      // Copy from temp to permanent location
      final File sourceFile = File(tempPath);
      await sourceFile.copy(permanentPath);
      
      final captureData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'path': permanentPath,
        'type': 'video',
        'timestamp': DateTime.now().toIso8601String(),
        'fileName': fileName,
      };
      
      await _saveCaptureToPrefs(captureData);
      
      print('✅ Video saved: $permanentPath');
      return captureData;
    } catch (e) {
      print('❌ Save video error: $e');
      return null;
    }
  }

  // === SAVE TO SHARED PREFERENCES ===
  Future<void> _saveCaptureToPrefs(Map<String, dynamic> captureData) async {
    final prefs = await SharedPreferences.getInstance();
    final capturesList = prefs.getStringList(_capturesKey) ?? [];
    
    capturesList.add(jsonEncode(captureData));
    await prefs.setStringList(_capturesKey, capturesList);
  }

  // === GET ALL CAPTURES ===
  Future<List<Map<String, dynamic>>> getAllCaptures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final capturesList = prefs.getStringList(_capturesKey) ?? [];
      
      final captures = capturesList.map((json) {
        return jsonDecode(json) as Map<String, dynamic>;
      }).toList();
      
      // Sort by timestamp (newest first)
      captures.sort((a, b) => 
        DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp']))
      );
      
      // Verify files still exist
      final validCaptures = <Map<String, dynamic>>[];
      for (var capture in captures) {
        final file = File(capture['path']);
        if (await file.exists()) {
          validCaptures.add(capture);
        }
      }
      
      // Update prefs if some files were deleted
      if (validCaptures.length != captures.length) {
        final validList = validCaptures.map((c) => jsonEncode(c)).toList();
        await prefs.setStringList(_capturesKey, validList);
      }
      
      return validCaptures;
    } catch (e) {
      print('❌ Get captures error: $e');
      return [];
    }
  }

  // === DELETE CAPTURE ===
  Future<bool> deleteCapture(String captureId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final capturesList = prefs.getStringList(_capturesKey) ?? [];
      
      String? pathToDelete;
      final updatedList = <String>[];
      
      for (var json in capturesList) {
        final capture = jsonDecode(json) as Map<String, dynamic>;
        if (capture['id'] != captureId) {
          updatedList.add(json);
        } else {
          pathToDelete = capture['path'];
        }
      }
      
      // Delete file
      if (pathToDelete != null) {
        final file = File(pathToDelete);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      await prefs.setStringList(_capturesKey, updatedList);
      
      print('✅ Capture deleted: $captureId');
      return true;
    } catch (e) {
      print('❌ Delete capture error: $e');
      return false;
    }
  }

  // === DELETE ALL CAPTURES ===
  Future<bool> deleteAllCaptures() async {
    try {
      final mediaDir = await _getMediaDirectory();
      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_capturesKey);
      
      print('✅ All captures deleted');
      return true;
    } catch (e) {
      print('❌ Delete all captures error: $e');
      return false;
    }
  }

  // === PICK IMAGE FROM GALLERY ===
  Future<Map<String, dynamic>?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) return null;
      
      return await savePhotoFromCamera(image.path);
    } catch (e) {
      print('❌ Pick image error: $e');
      return null;
    }
  }

  // === PICK VIDEO FROM GALLERY ===
  Future<Map<String, dynamic>?> pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      
      if (video == null) return null;
      
      return await saveVideoFromCamera(video.path);
    } catch (e) {
      print('❌ Pick video error: $e');
      return null;
    }
  }

  // === SHOW IMAGE SOURCE DIALOG (Camera or Gallery) ===
  Future<File?> showImageSourceDialog(BuildContext context) async {
    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFFF9B85)),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFA7B5F4)),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return null;

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return null;

      return File(image.path);
    } catch (e) {
      print('❌ Image picker error: $e');
      return null;
    }
  }

  // === GET CAPTURE BY ID ===
  Future<Map<String, dynamic>?> getCaptureById(String captureId) async {
    final captures = await getAllCaptures();
    try {
      return captures.firstWhere((c) => c['id'] == captureId);
    } catch (e) {
      return null;
    }
  }

  // === CHECK IF FILE EXISTS ===
  Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  // === UPLOAD IMAGE TO FIREBASE STORAGE ===
  Future<String?> uploadImageToFirebase(File imageFile, String hazardId) async {
    try {
      // This is a placeholder - Firebase Storage upload is handled separately
      // Just return the local file path for now
      return imageFile.path;
    } catch (e) {
      print('❌ Firebase upload error: $e');
      return null;
    }
  }
}
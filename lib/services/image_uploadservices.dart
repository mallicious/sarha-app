import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Pick image from camera or gallery
  Future<File?> pickImage({required ImageSource source}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85, // Compress to reduce size
      );

      if (pickedFile == null) {
        print('❌ No image selected');
        return null;
      }

      final file = File(pickedFile.path);
      print('✅ Image picked: ${file.path}');
      return file;
    } catch (e) {
      print('❌ Image picker error: $e');
      return null;
    }
  }

  // Show dialog to choose camera or gallery
  Future<File?> showImageSourceDialog(BuildContext context) async {
    return await showDialog<File?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF8F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.add_a_photo_rounded, color: Color(0xFFFF9B85), size: 28),
            const SizedBox(width: 12),
            const Text('Add Photo', style: TextStyle(color: Color(0xFF4A4063), fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFA7B5F4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFA7B5F4)),
              ),
              title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Use camera', style: TextStyle(fontSize: 12)),
              onTap: () async {
                Navigator.pop(context);
                final file = await pickImage(source: ImageSource.camera);
                if (context.mounted) {
                  Navigator.pop(context, file);
                }
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9B85).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFFFF9B85)),
              ),
              title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Select existing photo', style: TextStyle(fontSize: 12)),
              onTap: () async {
                Navigator.pop(context);
                final file = await pickImage(source: ImageSource.gallery);
                if (context.mounted) {
                  Navigator.pop(context, file);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // Upload image to Firebase Storage
  Future<String?> uploadImage(File imageFile, String hazardId) async {
    try {
      print('📤 Uploading image for hazard: $hazardId');

      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${hazardId}_$timestamp.jpg';

      // Create reference to Firebase Storage
      final ref = _storage.ref().child('hazard_images').child(fileName);

      // Upload file
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'hazardId': hazardId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Show upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📊 Upload progress: ${progress.toStringAsFixed(0)}%');
      });

      // Wait for completion
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Image uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Upload error: $e');
      return null;
    }
  }

  // Upload multiple images
  Future<List<String>> uploadMultipleImages(List<File> imageFiles, String hazardId) async {
    List<String> urls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      final url = await uploadImage(imageFiles[i], '${hazardId}_$i');
      if (url != null) {
        urls.add(url);
      }
    }

    print('✅ Uploaded ${urls.length}/${imageFiles.length} images');
    return urls;
  }

  // Delete image from Firebase Storage
  Future<bool> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('✅ Image deleted');
      return true;
    } catch (e) {
      print('❌ Delete error: $e');
      return false;
    }
  }

  deleteCapture(String captureId) {}

  deleteAllCaptures() {}

  savePhotoFromCamera(String path) {}

  saveVideoFromCamera(String path) {}
}

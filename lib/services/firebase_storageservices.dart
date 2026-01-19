import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class FirebaseStorageService {
  static final FirebaseStorageService _instance = FirebaseStorageService._internal();
  factory FirebaseStorageService() => _instance;
  FirebaseStorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload image to Firebase Storage and return download URL
  Future<String?> uploadImage(File imageFile, String hazardId) async {
    try {
      final fileName = path.basename(imageFile.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = _storage.ref().child('hazard_images/$hazardId/${timestamp}_$fileName');

      print('📤 Uploading image to Firebase Storage...');

      // Upload file
      final uploadTask = await storageRef.putFile(imageFile);

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      print('✅ Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Firebase upload error: $e');
      return null;
    }
  }

  /// Upload video to Firebase Storage and return download URL
  Future<String?> uploadVideo(File videoFile, String hazardId) async {
    try {
      final fileName = path.basename(videoFile.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = _storage.ref().child('hazard_videos/$hazardId/${timestamp}_$fileName');

      print('📤 Uploading video to Firebase Storage...');

      // Upload file
      final uploadTask = await storageRef.putFile(videoFile);

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      print('✅ Video uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Firebase upload error: $e');
      return null;
    }
  }

  /// Delete file from Firebase Storage
  Future<bool> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      print('✅ File deleted from Firebase Storage');
      return true;
    } catch (e) {
      print('❌ Firebase delete error: $e');
      return false;
    }
  }
}
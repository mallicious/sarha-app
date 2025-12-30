import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // === CALM COLOR PALETTE ===
  static const Color softLavender = Color(0xFFA7B5F4);
  static const Color coral = Color(0xFFFF9B85);
  static const Color cream = Color(0xFFFAF8F5);
  static const Color deepPurple = Color(0xFF4A4063);
  static const Color lightPurple = Color(0xFFD1D5F7);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isLoading = false;
  String? _currentProfilePicUrl;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (userDoc.exists) {
        final data = userDoc.data();
        _nameController.text = data?['displayName'] ?? user.displayName ?? '';
        _phoneController.text = data?['phoneNumber'] ?? '';
        _currentProfilePicUrl = data?['profilePicUrl'];
      } else {
        _nameController.text = user.displayName ?? '';
      }
      _emailController.text = user.email ?? '';
    } catch (e) {
      _showSnackBar('Failed to load profile data', coral);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        _showSnackBar('Image selected! Click Save to update.', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: ${e.toString()}', coral);
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_selectedImage == null) return _currentProfilePicUrl;

    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // Delete old image if it exists
      if (_currentProfilePicUrl != null && _currentProfilePicUrl!.isNotEmpty) {
        try {
          final oldRef = _storage.refFromURL(_currentProfilePicUrl!);
          await oldRef.delete();
        } catch (e) {
          print('Could not delete old image: $e');
        }
      }

      // Upload new image with better error handling
      final fileName = 'profile_${user.uid}.jpg'; // Use consistent filename
      final storageRef = _storage.ref('profile_pictures/$fileName'); // Use ref() not child()

      // Upload with metadata
      final uploadTask = storageRef.putFile(
        _selectedImage!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Upload error details: $e');
      _showSnackBar('Failed to upload: ${e.toString().split(':').last}', coral);
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Upload image if one was selected
      String? profilePicUrl = _currentProfilePicUrl;
      if (_selectedImage != null) {
        _showSnackBar('Uploading image...', Colors.blue);
        profilePicUrl = await _uploadProfileImage();
        if (profilePicUrl == null) {
          _showSnackBar('Failed to upload image', coral);
          setState(() => _isLoading = false);
          return;
        }
      }

      // Update email if changed
      if (_emailController.text.trim() != user.email) {
        try {
          await user.verifyBeforeUpdateEmail(_emailController.text.trim());
          _showSnackBar('Verification email sent! Check your inbox.', Colors.blue);
        } catch (e) {
          _showSnackBar('Failed to update email: ${e.toString()}', coral);
        }
      }

      // Update display name in Firebase Auth
      await user.updateDisplayName(_nameController.text.trim());

      // Update Firestore user document
      await _firestore.collection('users').doc(user.uid).set({
        'displayName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'profilePicUrl': profilePicUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update local state
      setState(() {
        _currentProfilePicUrl = profilePicUrl;
        _selectedImage = null;
        _uploadProgress = 0.0;
      });

      _showSnackBar('Profile updated successfully!', Colors.green);
      
      // Wait a moment then go back
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackBar('Failed to update profile: ${e.toString()}', coral);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: softLavender,
        foregroundColor: deepPurple,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: coral),
                  const SizedBox(height: 20),
                  if (_uploadProgress > 0 && _uploadProgress < 1)
                    Column(
                      children: [
                        Text('Uploading image...', style: TextStyle(color: deepPurple)),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: lightPurple,
                            valueColor: AlwaysStoppedAnimation<Color>(coral),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontWeight: FontWeight.bold, color: coral),
                        ),
                      ],
                    ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Profile Picture Section
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: softLavender.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 70,
                              backgroundColor: lightPurple,
                              backgroundImage: _selectedImage != null
                                  ? FileImage(_selectedImage!)
                                  : (_currentProfilePicUrl != null
                                      ? NetworkImage(_currentProfilePicUrl!)
                                      : null) as ImageProvider?,
                              child: (_selectedImage == null && _currentProfilePicUrl == null)
                                  ? Text(
                                      _nameController.text.isNotEmpty
                                          ? _nameController.text[0].toUpperCase()
                                          : user?.email?[0].toUpperCase() ?? 'U',
                                      style: TextStyle(
                                        fontSize: 50,
                                        color: deepPurple,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: coral,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Tap to change photo',
                      style: TextStyle(
                        color: deepPurple.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      style: TextStyle(color: deepPurple, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: deepPurple.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.email_outlined, color: softLavender),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: softLavender.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: softLavender, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: deepPurple, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: TextStyle(color: deepPurple.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.person_outline_rounded, color: softLavender),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: softLavender.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: softLavender, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Phone Field
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: deepPurple, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        labelStyle: TextStyle(color: deepPurple.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.phone_outlined, color: softLavender),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: softLavender.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: softLavender, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _saveProfile,
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
                        label: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: coral,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Cancel Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: deepPurple, size: 22),
                        label: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 17,
                            color: deepPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: softLavender, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
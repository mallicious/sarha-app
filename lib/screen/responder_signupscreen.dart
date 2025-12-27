// lib/screen/responder_signup_screen.dart (WITH FIREBASE STORAGE ENABLED)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ResponderSignupScreen extends StatefulWidget {
  const ResponderSignupScreen({super.key});

  @override
  State<ResponderSignupScreen> createState() => _ResponderSignupScreenState();
}

class _ResponderSignupScreenState extends State<ResponderSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _organizationController = TextEditingController();
  final _phoneController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  File? _idCardImage;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _idNumberController.dispose();
    _organizationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickIdCard() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _idCardImage = File(image.path);
        });
        _showSnackBar('ID card selected! Ready to submit.', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: ${e.toString()}', Colors.red);
    }
  }

  Future<String?> _uploadIdCardToStorage(String userId) async {
    if (_idCardImage == null) return null;

    try {
      // Create unique filename
      final fileName = 'id_card_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef =
          _storage.ref().child('responder_ids/$userId/$fileName');

      // Upload with progress tracking
      final uploadTask = storageRef.putFile(_idCardImage!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask;

      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Upload error: $e');
      _showSnackBar('Failed to upload ID card: ${e.toString()}', Colors.red);
      return null;
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_idCardImage == null) {
      _showSnackBar('Please upload your ID card for verification.', Colors.red);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match.', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create Firebase Auth account
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = userCredential.user!.uid;

      // Update display name
      await userCredential.user!.updateDisplayName(_nameController.text.trim());

      // Upload ID card to Firebase Storage
      _showSnackBar('Uploading ID card...', Colors.blue);
      final idCardUrl = await _uploadIdCardToStorage(userId);

      if (idCardUrl == null) {
        // Upload failed, delete the auth account
        await userCredential.user!.delete();
        _showSnackBar(
            'Failed to upload ID card. Please try again.', Colors.red);
        setState(() => _isLoading = false);
        return;
      }

      // Auto-verify admin emails (YOUR EMAILS HERE)
      final adminEmails = [
        'mesoyina25@gmail.com', // Your first email
        'mals.core18@gmail.com', // Replace with your second email
      ];

      final isAdmin =
          adminEmails.contains(_emailController.text.trim().toLowerCase());

      // Save to Firestore (responders collection)
      await _firestore.collection('responders').doc(userId).set({
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'organization': _organizationController.text.trim(),
        'idNumber': _idNumberController.text.trim(),
        'isVerified': isAdmin, // Auto-verify if admin email
        'userType': 'responder',
        'isAdmin': isAdmin, // Mark as admin
        'createdAt': FieldValue.serverTimestamp(),
        'idCardUrl': idCardUrl, // Store the download URL
        'idCardUploaded': true,
        'verificationStatus': isAdmin ? 'approved' : 'pending',
      });

      _showSnackBar(
        isAdmin
            ? 'Admin account created! You can login immediately.'
            : 'Account created! Please wait for admin verification.',
        Colors.green,
      );

      // Wait 2 seconds then go back to login
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Sign up failed';
      if (e.code == 'weak-password') {
        message = 'Password is too weak. Use at least 6 characters.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists with this email.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      }
      _showSnackBar(message, Colors.red);
    } catch (e) {
      _showSnackBar('An error occurred: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Responder Sign Up'),
        backgroundColor: const Color(0xFFFF9800),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFFF9800)),
                  const SizedBox(height: 20),
                  if (_uploadProgress > 0 && _uploadProgress < 1)
                    Column(
                      children: [
                        Text(
                          'Uploading ID card...',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFFF9800)),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF9800),
                          ),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Register as Road Authority',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF9800),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Please provide your official credentials for verification',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 30),

                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon:
                            Icon(Icons.person, color: Color(0xFFFF9800)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 15),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Official Email *',
                        prefixIcon: Icon(Icons.email, color: Color(0xFFFF9800)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
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

                    const SizedBox(height: 15),

                    // Phone
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        prefixIcon: Icon(Icons.phone, color: Color(0xFFFF9800)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your phone number';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 15),

                    // Organization
                    TextFormField(
                      controller: _organizationController,
                      decoration: const InputDecoration(
                        labelText: 'Organization / Department *',
                        hintText: 'e.g., Federal Road Safety Corps',
                        prefixIcon:
                            Icon(Icons.business, color: Color(0xFFFF9800)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your organization';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 15),

                    // ID Number
                    TextFormField(
                      controller: _idNumberController,
                      decoration: const InputDecoration(
                        labelText: 'ID Number / Staff Number *',
                        prefixIcon: Icon(Icons.badge, color: Color(0xFFFF9800)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your ID number';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ID Card Upload Section
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _idCardImage != null
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.card_membership,
                                color: _idCardImage != null
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Upload ID Card *',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_idCardImage != null)
                            Column(
                              children: [
                                Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: FileImage(_idCardImage!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        color: Colors.green, size: 20),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'ID card uploaded',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _pickIdCard,
                              icon: Icon(
                                _idCardImage != null
                                    ? Icons.refresh
                                    : Icons.upload_file,
                              ),
                              label: Text(
                                _idCardImage != null
                                    ? 'Change ID Card'
                                    : 'Select ID Card',
                              ),
                              style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: Color(0xFFFF9800)),
                                foregroundColor: const Color(0xFFFF9800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        prefixIcon:
                            const Icon(Icons.lock, color: Color(0xFFFF9800)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(
                                () => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 15),

                    // Confirm Password
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password *',
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Color(0xFFFF9800)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => _obscureConfirmPassword =
                                !_obscureConfirmPassword);
                          },
                        ),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 30),

                    // Sign Up Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _signUp,
                        icon: const Icon(Icons.how_to_reg, color: Colors.white),
                        label: const Text(
                          'Submit for Verification',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9800),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: Colors.green[700]),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your ID card will be securely uploaded to Firebase Storage and verified by administrators within 24-48 hours.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

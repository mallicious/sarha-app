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
  // === CALM COLOR PALETTE ===
  static const Color softLavender = Color(0xFFA7B5F4);
  static const Color coral = Color(0xFFFF9B85);
  static const Color cream = Color(0xFFFAF8F5);
  static const Color deepPurple = Color(0xFF4A4063);
  static const Color lightPurple = Color(0xFFD1D5F7);

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
        setState(() => _idCardImage = File(image.path));
        _showSnackBar('ID card selected! Ready to submit.', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: ${e.toString()}', coral);
    }
  }

  Future<String?> _uploadIdCardToStorage(String userId) async {
    if (_idCardImage == null) return null;

    try {
      final fileName = 'id_card_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef =
          _storage.ref().child('responder_ids/$userId/$fileName');

      final uploadTask = storageRef.putFile(_idCardImage!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask;
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      _showSnackBar('Failed to upload ID card: ${e.toString()}', coral);
      return null;
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_idCardImage == null) {
      _showSnackBar('Please upload your ID card for verification.', coral);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match.', coral);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = userCredential.user!.uid;
      await userCredential.user!.updateDisplayName(_nameController.text.trim());

      _showSnackBar('Uploading ID card...', Colors.blue);
      final idCardUrl = await _uploadIdCardToStorage(userId);

      if (idCardUrl == null) {
        await userCredential.user!.delete();
        _showSnackBar('Failed to upload ID card. Please try again.', coral);
        setState(() => _isLoading = false);
        return;
      }

      final adminEmails = ['mesoyina25@gmail.com', 'mals.core18@gmail.com'];
      final isAdmin =
          adminEmails.contains(_emailController.text.trim().toLowerCase());

      await _firestore.collection('responders').doc(userId).set({
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'organization': _organizationController.text.trim(),
        'idNumber': _idNumberController.text.trim(),
        'isVerified': isAdmin,
        'userType': 'responder',
        'isAdmin': isAdmin,
        'createdAt': FieldValue.serverTimestamp(),
        'idCardUrl': idCardUrl,
        'idCardUploaded': true,
        'verificationStatus': isAdmin ? 'approved' : 'pending',
      });

      _showSnackBar(
        isAdmin
            ? 'Admin account created! You can login immediately.'
            : 'Account created! Please wait for admin verification.',
        Colors.green,
      );

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = 'Sign up failed';
      if (e.code == 'weak-password') {
        message = 'Password is too weak. Use at least 6 characters.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists with this email.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      }
      _showSnackBar(message, coral);
    } catch (e) {
      _showSnackBar('An error occurred: ${e.toString()}', coral);
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Responder Sign Up',
            style: TextStyle(fontWeight: FontWeight.w600)),
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
                        Text('Uploading ID card...',
                            style: TextStyle(color: deepPurple)),
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
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: coral),
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
                    Text(
                      'Register as Road Authority',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: deepPurple),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Please provide your official credentials for verification',
                      style: TextStyle(
                          fontSize: 14, color: deepPurple.withOpacity(0.6)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name *',
                      icon: Icons.person_rounded,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter your full name'
                          : null,
                    ),
                    const SizedBox(height: 15),

                    _buildTextField(
                      controller: _emailController,
                      label: 'Official Email *',
                      icon: Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!v.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number *',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter your phone number'
                          : null,
                    ),
                    const SizedBox(height: 15),

                    _buildTextField(
                      controller: _organizationController,
                      label: 'Organization / Department *',
                      icon: Icons.business_rounded,
                      hint: 'e.g., Federal Road Safety Corps',
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter your organization'
                          : null,
                    ),
                    const SizedBox(height: 15),

                    _buildTextField(
                      controller: _idNumberController,
                      label: 'ID Number / Staff Number *',
                      icon: Icons.badge_rounded,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter your ID number'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // ID Card Upload
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _idCardImage != null
                                ? Colors.green
                                : softLavender),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.card_membership_rounded,
                                  color: _idCardImage != null
                                      ? Colors.green
                                      : softLavender),
                              const SizedBox(width: 10),
                              Text('Upload ID Card *',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: deepPurple)),
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
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                        image: FileImage(_idCardImage!),
                                        fit: BoxFit.cover),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: Colors.green, size: 20),
                                    const SizedBox(width: 5),
                                    const Text('ID card uploaded',
                                        style: TextStyle(color: Colors.green)),
                                  ],
                                ),
                              ],
                            ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _pickIdCard,
                              icon: Icon(_idCardImage != null
                                  ? Icons.refresh_rounded
                                  : Icons.upload_file_rounded),
                              label: Text(_idCardImage != null
                                  ? 'Change ID Card'
                                  : 'Select ID Card'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: softLavender),
                                foregroundColor: softLavender,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password *',
                      icon: Icons.lock_rounded,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (v.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    _buildTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password *',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded),
                        onPressed: () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Please confirm your password'
                          : null,
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _signUp,
                        icon: const Icon(Icons.how_to_reg_rounded, size: 22),
                        label: const Text('Submit for Verification',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: coral,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              color: Colors.green[700]),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your ID card will be securely uploaded to Firebase Storage and verified by administrators within 24-48 hours.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.green[900]),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(color: deepPurple, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: deepPurple.withOpacity(0.7)),
        hintStyle: TextStyle(color: deepPurple.withOpacity(0.4), fontSize: 13),
        prefixIcon: Icon(icon, color: softLavender),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
      validator: validator,
    );
  }
}

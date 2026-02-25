import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // === CALM COLOR PALETTE ===
  static const Color softLavender = Color(0xFFA7B5F4);
  static const Color coral = Color(0xFFFF9B85);
  static const Color cream = Color(0xFFFAF8F5);
  static const Color deepPurple = Color(0xFF4A4063);
  static const Color lightPurple = Color(0xFFD1D5F7);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _stayLoggedIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // === SAVE LOGIN STATE ===
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('stayLoggedIn', _stayLoggedIn);
      await prefs.setString('userType', 'driver');

      // Save timestamp for 2-week expiry
      if (_stayLoggedIn) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt('loginTimestamp', now);
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/driverDashboard');
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      }
      _showSnackBar(message, coral);
    } catch (e) {
      _showSnackBar('An error occurred: ${e.toString()}', coral);
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
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _showPasswordResetDialog() async {
    final resetEmailController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email to receive a password reset link.'),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: softLavender,
            ),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) {
                _showSnackBar('Please enter your email', coral);
                return;
              }
              if (!email.contains('@')) {
                _showSnackBar('Please enter a valid email', coral);
                return;
              }

              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                Navigator.pop(context);
                _showSnackBar(
                  'Password reset email sent! Check your inbox.',
                  Colors.green,
                );
              } on FirebaseAuthException catch (e) {
                String message = 'Failed to send reset email';
                if (e.code == 'user-not-found') {
                  message = 'No account found with this email.';
                } else if (e.code == 'invalid-email') {
                  message = 'Invalid email address.';
                }
                _showSnackBar(message, coral);
              } catch (e) {
                _showSnackBar('Error: ${e.toString()}', coral);
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 228, 162, 64),
      appBar: AppBar(
        title: const Text('Driver Login',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: softLavender,
        foregroundColor: deepPurple,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: coral))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: lightPurple,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: softLavender.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(Icons.directions_car_filled_rounded,
                            size: 80, color: deepPurple),
                      ),
                    ),

                    const SizedBox(height: 30),

                    Text(
                      'Welcome Back, Driver!',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: deepPurple),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Sign in to continue protecting roads',
                      style: TextStyle(
                          fontSize: 14, color: deepPurple.withOpacity(0.6)),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(
                          color: deepPurple, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle:
                            TextStyle(color: deepPurple.withOpacity(0.7)),
                        prefixIcon:
                            Icon(Icons.email_rounded, color: softLavender),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: softLavender.withOpacity(0.3)),
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

                    const SizedBox(height: 20),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(
                          color: deepPurple, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle:
                            TextStyle(color: deepPurple.withOpacity(0.7)),
                        prefixIcon:
                            Icon(Icons.lock_rounded, color: softLavender),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: deepPurple.withOpacity(0.5),
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: softLavender.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: softLavender, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 8),

                    // Forgot Password Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showPasswordResetDialog,
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: softLavender,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Keep Logged In Checkbox
                    CheckboxListTile(
                      title: Text(
                        "Keep me logged in for 2 weeks",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: deepPurple),
                      ),
                      value: _stayLoggedIn,
                      activeColor: coral,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      onChanged: (bool? value) {
                        setState(() => _stayLoggedIn = value ?? false);
                      },
                    ),

                    const SizedBox(height: 10),

                    // Login Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _login,
                        icon: const Icon(Icons.login_rounded, size: 22),
                        label: const Text('Login',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: softLavender,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ",
                            style:
                                TextStyle(color: deepPurple.withOpacity(0.7))),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/driverSignup'),
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                                color: softLavender,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Colors.green[700]),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Help make roads safer by reporting hazards as you drive.',
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
}

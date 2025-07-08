import 'package:avatar_map_navigation/map/map_page.dart';
import 'package:avatar_map_navigation/mapview/triphome.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../hive_models/user_model.dart';
import 'hiveService.dart';
import 'loginScreen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _showFieldErrors = false;
  bool _isLoading = false;

  void _validateAndSignUp() async {
    setState(() {
      _showFieldErrors = true;
    });

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay

        // Create a new user with 0 trips
        User newUser = User(userId: _emailController.text.trim(), trips: []);

        await HiveService.saveUser(newUser);

        await HiveService.saveLoggedInUser(newUser.userId);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Account created successfully!'), backgroundColor: Colors.green));
        //Get.to(() => TripLogHomePage()); // replaces current page
        Get.offAll(() => MapPage()); // navigates to TripLogHomePage and removes all previous pages from the stack
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Something went wrong'), backgroundColor: Colors.redAccent));
      }

      setState(() => _isLoading = false);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❌ Please fix the errors to continue'), backgroundColor: Colors.redAccent));
    }
  }

  String? _validateEmail(String? value) {
    if (!_showFieldErrors) return null;
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (!_showFieldErrors) return null;
    if (value == null || value.trim().isEmpty) return 'Password is required';
    if (value.trim().length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (!_showFieldErrors) return null;
    if (value == null || value.trim().isEmpty) return 'Please confirm your password';
    if (value.trim() != _passwordController.text.trim()) return 'Passwords do not match';
    return null;
  }

  void _resetErrors() {
    if (_showFieldErrors) {
      setState(() => _showFieldErrors = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Icon(Icons.person_add_alt, size: 80, color: Colors.deepPurple),
                const SizedBox(height: 20),
                Text("Create Account", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: _validateEmail,
                  onChanged: (_) => _resetErrors(),
                ),
                const SizedBox(height: 20),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: _validatePassword,
                  onChanged: (_) => _resetErrors(),
                ),
                const SizedBox(height: 20),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: _validateConfirmPassword,
                  onChanged: (_) => _resetErrors(),
                ),
                const SizedBox(height: 30),

                // Sign Up Button / Loader
                SizedBox(
                  width: double.infinity,
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                          : ElevatedButton(
                            onPressed: _validateAndSignUp,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Sign Up', style: TextStyle(fontSize: 16,color:Colors.white)),
                          ),
                ),
                const SizedBox(height: 30),


                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    GestureDetector(
                      onTap: () {
                         Get.to(() => const LoginScreen());
                      },
                      child: const Text(
                        "Log In",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}

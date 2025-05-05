import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: _emailController.text.trim(),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Password reset link sent! Please check your email.')),
        );

        Navigator.pop(context); // Go back to login screen
      } on FirebaseAuthException catch (e) {
        String message = 'An error occurred. Please try again.';
        if (e.code == 'user-not-found') {
          message = 'No user found with this email.';
        } else if (e.code == 'invalid-email') {
          message = 'Invalid email format.';
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                'Enter your email to receive a reset link.',
                style: TextStyle(
                    fontSize: 18, color: isDark ? Colors.white : Colors.black),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  labelStyle:
                      TextStyle(color: isDark ? Colors.white : Colors.black),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: isDark ? Colors.white : Colors.black),
                  ),
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter your email';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 30),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _sendResetEmail,
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(
                          isDark
                              ? Colors.grey[800]
                              : Colors.white, // Button color
                        ),
                        foregroundColor: MaterialStateProperty.all(
                          isDark ? Colors.white : Colors.black, // Text color
                        ),
                      ),
                      child: Text('Send Reset Link'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

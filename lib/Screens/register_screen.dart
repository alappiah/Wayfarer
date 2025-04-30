import 'package:flutter/material.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Full-screen gradient background
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFAB96CE), // Dark purple
              Color(0xFF38419C), // Lighter purple
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header text in the gradient area
              Padding(
                padding: EdgeInsets.only(left: 20, top: 20, bottom: 30),
                child: Text(
                  'Begin Your Journey',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),

              // White content area with rounded top corners
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // CHANGED: Increased spacing at the top from 10 to 40
                          SizedBox(height: 40),

                          // Login title
                          Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.purple[300],
                              fontWeight: FontWeight.w400,
                            ),
                          ),

                          // First name field
                          SizedBox(height: 40),
                          TextField(
                            controller: _firstNameController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'First Name',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.purple),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Last name field
                          TextField(
                            controller: _lastNameController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'Last Name',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.purple),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Email field
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'Email',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.purple),
                              ),
                            ),
                          ),

                          SizedBox(height: 16),

                          // Password field
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.purple),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),

                          SizedBox(height: 16),

                          //Confirm password field
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Confirm Password',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.purple),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),

                          SizedBox(height: 16),

                          // Log in button
                          ElevatedButton(
                            onPressed: () {
                              // Handle login logic
                            },
                            child: Text(
                              'Register',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF001A33),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              minimumSize: Size(double.infinity, 48),
                            ),
                          ),

                          SizedBox(height: 20),

                          // Register link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account? ",
                                style: TextStyle(color: Colors.black87),
                              ),
                              InkWell(
                                onTap: () {
                                  // Navigate to login screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LoginScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Login',
                                  style: TextStyle(
                                    color: Colors.blue[700],
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class LandingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Color(0xFF000E29),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF000E29),
          foregroundColor: Colors.black,
        ),
      ),
      child: Scaffold(
        body: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 400, maxHeight: 700),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Column(
                children: [
                  // Top part with the image background
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(
                            'assets/images/wayfarer_background.png',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Wayfarer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Your journey, your story.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom part with the buttons
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 20.0,
                    ),
                    decoration: BoxDecoration(
                      color: Color(0x000E29),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Navigate to the LoginScreen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LoginScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF7B5AA6),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'LOG IN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              // Navigate to the RegisterScreen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RegisterScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Color(0xFF7B5AA6),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Color(0xFF7B5AA6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'REGISTER',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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
        ),
      ),
    );
  }
}

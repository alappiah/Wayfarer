import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer/Screens/home_screen.dart';
import 'screens/landing_screen.dart'; // or wherever LandingPage is defined
// import 'screens/home_screen.dart'; // Replace with your main homepage screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool isFirstLaunch = await checkFirstLaunch();
  runApp(MyApp(isFirstLaunch: isFirstLaunch));
}

Future<bool> checkFirstLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
  
  if (isFirstLaunch) {
    // Set the value to false after the first launch
    await prefs.setBool('isFirstLaunch', false);
  }

  return isFirstLaunch;
}

class MyApp extends StatelessWidget {
  final bool isFirstLaunch;
  const MyApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wayfarer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: isFirstLaunch ? LandingPage() : HomeScreen(), // Show LandingPage only on the first launch
      debugShowCheckedModeBanner: false,
    );
  }
}

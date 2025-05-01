import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/landing_screen.dart'; // Import your existing landing page
import 'screens/bookmarked_screen.dart';
import 'screens/private_screen.dart';
import 'screens/settings_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required before Firebase.init
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _hasSeenLandingPage = false;
  
  @override
  void initState() {
    super.initState();
    _checkLandingPageStatus();
  }

  // Check if user has seen the landing page before
  Future<void> _checkLandingPageStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasSeenLandingPage = prefs.getBool('hasSeenLandingPage') ?? false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: _isLoading
          ? _buildLoadingScreen()
          : _getInitialScreen(),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _getInitialScreen() {
    // First check if user has seen landing page
    if (!_hasSeenLandingPage) {
      return LandingPage();
    }
    
    // If user has seen landing page, check Firebase auth
    return FirebaseAuth.instance.currentUser == null
        ? LoginScreen()
        : const JournalAppHome();
  }
}

class JournalAppHome extends StatefulWidget {
  const JournalAppHome({super.key});

  @override
  State<JournalAppHome> createState() => _JournalAppHomeState();
}

class _JournalAppHomeState extends State<JournalAppHome> {
  int _currentIndex = 0;

  final List<String> _appBarTitles = [
    "JOURNAL",
    "BOOKMARKED",
    "PRIVATE",
    "SETTINGS",
  ];

  final List<Widget> _screens = [
    const JournalApp(),
    const BookmarkedScreen(),
    const PrivateScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _appBarTitles[_currentIndex],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: NetworkImage('https://via.placeholder.com/100'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(child: _screens[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        unselectedItemColor: Colors.black,
        selectedItemColor: Colors.purpleAccent,
        currentIndex: _currentIndex,
        showUnselectedLabels: false,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Bookmarked',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.lock), label: 'Private'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
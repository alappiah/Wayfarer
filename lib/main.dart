import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/bookmarked_screen.dart';
import 'screens/private_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      home: const JournalAppHome(),
    );
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

  // Create the screens for each tab
  final List<Widget> _screens = [
    const JournalApp(),
    const BookmarkedScreen(),
    const PrivateScreen(),
    const SettingsScreen(),
  ];

  void _showAddEntryOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Entry',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Add Photo'),
                onTap: () {
                  Navigator.pop(context);
                  // Forward the action to the journal screen
                  if (_currentIndex == 0) {
                    // Only allow adding entries from the journal tab
                    // In a real app, you would use a more robust approach
                    // like a global state management solution
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Record Audio'),
                onTap: () {
                  Navigator.pop(context);
                  // Forward the action to the journal screen
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Write Text Entry'),
                onTap: () {
                  Navigator.pop(context);
                  // Forward the action to the journal screen
                },
              ),
            ],
          ),
        );
      },
    );
  }

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
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.add, color: Colors.white, size: 28),
          onPressed: () {
            // Show modal bottom sheet for creating new entry
            _showAddEntryOptions(context);
          },
        ),
      ),
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

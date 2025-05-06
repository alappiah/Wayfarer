import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/journal_entry.dart';
import '../widgets/journal_entry_card.dart';
import '../services/journal_security_service.dart';
import 'add_journal_screen.dart';
import 'edit_journal_screen.dart';

class JournalApp extends StatefulWidget {
  const JournalApp({super.key});

  @override
  State createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalApp> {
  // Stream for listening to journal entries from Firestore
  late Stream<QuerySnapshot> _entriesStream;
  List<JournalEntry> _entries = [];
  List<JournalEntry> _filteredEntries = []; // For search results
  bool _isLoading = true;
  final JournalSecurityService _securityService = JournalSecurityService();

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  String firstName = 'User';

  @override
  void initState() {
    super.initState();

    // Initialize app
    _initializeApp();

    _getUserFirstName();

    // Add listener for search
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // Search functionality
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterEntries();
    });
  }

  void _filterEntries() {
    if (_searchQuery.isEmpty) {
      _filteredEntries = List.from(_entries);
    } else {
      _filteredEntries =
          _entries
              .where(
                (entry) => entry.title.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filterEntries();
      }
    });
  }

  // Add a dedicated method to get user's first name from both Auth and Firestore
  Future<void> _getUserFirstName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // First check if displayName is available in Firebase Auth
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          setState(() {
            firstName = user.displayName!.split(' ').first;
          });
        } else {
          // If displayName is not in Auth, try to get it from Firestore
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();

          if (userDoc.exists) {
            final userData = userDoc.data();
            if (userData != null &&
                userData['firstName'] != null &&
                userData['firstName'].isNotEmpty) {
              setState(() {
                firstName = userData['firstName'];
              });
            } else if (userData != null &&
                userData['displayName'] != null &&
                userData['displayName'].isNotEmpty) {
              // Try to get displayName from Firestore
              setState(() {
                firstName = userData['displayName'].toString().split(' ').first;
              });
            }
          }
        }

        print('User first name set to: $firstName');
      }
    } catch (e) {
      print('Error fetching user name: $e');
      // Keep the default "User" name
    }
  }

  Future<void> _initializeApp() async {
    // Initialize location manager
    await JournalLocationManager.initialize();

    // Initialize Firestore stream with security filter
    _updateEntriesStream();

    // Load initial entries
    _loadJournalEntries();
  }

  // Updates the entries stream based on current security settings
  void _updateEntriesStream() {
    // Get current user ID
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      setState(() {
        _entries = [];
        _filteredEntries = [];
        _isLoading = false;
      });
      return;
    }

    // FIXED: Show all unlocked entries (including bookmarked and non-bookmarked)
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('journals')
        .where('userId', isEqualTo: userId)
        .where('isLocked', isEqualTo: false) // Only show unlocked entries
        .orderBy('date', descending: true);

    // Update the stream
    _entriesStream = query.snapshots();
  }

  // Load journal entries from Firestore
  void _loadJournalEntries() {
    _entriesStream.listen(
      (snapshot) {
        setState(() {
          _entries =
              snapshot.docs.map((doc) {
                Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

                // Convert Firestore Timestamp to DateTime
                DateTime date;
                if (data['date'] is Timestamp) {
                  date = (data['date'] as Timestamp).toDate();
                } else {
                  date = DateTime.now(); // Default fallback
                }

                // Convert audio recordings if they exist
                List<AudioRecording> audioRecordings = [];
                if (data['audioRecordings'] != null) {
                  for (var audioData in data['audioRecordings']) {
                    DateTime recordedAt;
                    if (audioData['recordedAt'] is Timestamp) {
                      recordedAt =
                          (audioData['recordedAt'] as Timestamp).toDate();
                    } else {
                      recordedAt = DateTime.now();
                    }

                    audioRecordings.add(
                      AudioRecording(
                        id: audioData['id'] ?? '',
                        duration: audioData['duration'] ?? '00:00',
                        recordedAt: recordedAt,
                        title: audioData['title'] ?? 'Recording',
                      ),
                    );
                  }
                }

                // Convert additional images if they exist
                List<String> additionalImages = [];
                if (data['additionalImages'] != null) {
                  additionalImages = List<String>.from(
                    data['additionalImages'],
                  );
                }

                // Make sure location data is stored in the manager
                if (data['hasLocationData'] == true &&
                    data['locationData'] != null) {
                  JournalLocationManager.setLocationsForEntry(
                    doc.id,
                    data['locationData'] as List<dynamic>,
                  );
                  print('Stored location data for entry ${doc.id}');
                }

                return JournalEntry(
                  id: doc.id,
                  imageUrl: data['imageUrl'] ?? '',
                  title: data['title'] ?? '',
                  description: data['description'] ?? '',
                  date: date,
                  hasLocationData: data['hasLocationData'] ?? false,
                  locationName: data['locationName'],
                  location: data['location'],
                  additionalImages: additionalImages,
                  audioRecordings: audioRecordings,
                  isBookmarked: data['isBookmarked'] ?? false,
                  isLocked: data['isLocked'] ?? false,
                );
              }).toList();

          // Initialize filtered entries with all entries
          _filterEntries();
          _isLoading = false;
        });
      },
      onError: (error) {
        print('Error loading journal entries: $error');
        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  // FIXED: Handle entry updates to properly maintain entries regardless of bookmark status
  void _handleEntryUpdated(JournalEntry updatedEntry) {
    setState(() {
      // Only remove entries that become locked
      if (updatedEntry.isLocked) {
        _entries.removeWhere((entry) => entry.id == updatedEntry.id);
      } else {
        // For all other updates (including bookmark changes), update the entry
        final index = _entries.indexWhere(
          (entry) => entry.id == updatedEntry.id,
        );
        if (index >= 0) {
          // Update the entry but keep it in the list regardless of bookmark status
          _entries[index] = updatedEntry;
        } else {
          // If the entry was previously locked and now unlocked, add it
          _entries.add(updatedEntry);
          // Sort by date descending
          _entries.sort((a, b) => b.date.compareTo(a.date));
        }
      }

      // Update filtered entries after modifying the main list
      _filterEntries();
    });
  }

  // Handle tapping on a journal entry
  Future<void> _handleEntryTap(JournalEntry entry) async {
    // Check if user can access this entry
    bool canAccess = await _securityService.canAccessEntry(entry, context);

    if (canAccess && context.mounted) {
      // Navigate to view/edit entry screen
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => EditJournalScreen(
                entry: entry,
                onEntryUpdated: _handleEntryUpdated,
              ),
        ),
      );

      if (result != null && result is JournalEntry) {
        _handleEntryUpdated(result);
      }
    }
    // If canAccess is false, the security service already showed a message
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: CustomScrollView(
        slivers: [
          // App bar with search functionality
          SliverAppBar(
            floating: true,
            automaticallyImplyLeading: false,
            title:
                _isSearching
                    ? TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search journal titles...',
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _toggleSearch();
                          },
                        ),
                      ),
                      autofocus: true,
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Welcome, $firstName',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
            actions: [
              if (!_isSearching)
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _toggleSearch,
                ),
            ],
            backgroundColor: Colors.white,
            elevation: 0,
          ),

          // Loading indicator or empty state
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (_entries.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.book_outlined,
                        size: 64.0,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No journal entries yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to create your first entry',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          // Empty search results state
          else if (_filteredEntries.isEmpty && _searchQuery.isNotEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64.0,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No matching journal entries',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try a different search term',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          // Journal entries list (filtered or all)
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final entry = _filteredEntries[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: GestureDetector(
                    onTap: () => _handleEntryTap(entry),
                    child: JournalEntryCard(
                      entry: entry,
                      onEntryUpdated: _handleEntryUpdated,
                      onLockToggle: (entry) async {
                        // Use the security service to handle lock toggle
                        final success = await _securityService.toggleLock(
                          entry,
                          context,
                        );
                        if (success) {
                          // Update the entry in memory after successful toggle
                          final updatedEntry = entry.copyWith(
                            isLocked: !entry.isLocked,
                          );
                          _handleEntryUpdated(updatedEntry);
                        }
                      },
                    ),
                  ),
                );
              }, childCount: _filteredEntries.length),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddJournal(context),
        backgroundColor: Colors.black,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Navigate to add journal screen and handle the result
  void _navigateToAddJournal(BuildContext context) async {
    // Navigate to the add journal screen and await result
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => AddJournalScreen()));

    // If we get a new entry back and it's unlocked, add it to our list
    if (result != null && result is JournalEntry && !result.isLocked) {
      _handleEntryUpdated(result);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Journal entry added')));
    }
  }
}

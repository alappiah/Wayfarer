import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wayfarer/Screens/edit_journal_screen.dart';
import '../models/journal_entry.dart';
import '../widgets/journal_entry_card.dart';
import '../services/local_auth_service.dart';
import '../services/journal_security_service.dart';

class BookmarkedScreen extends StatefulWidget {
  const BookmarkedScreen({super.key});

  @override
  State<BookmarkedScreen> createState() => _BookmarkedScreenState();
}

class _BookmarkedScreenState extends State<BookmarkedScreen>
    with AutomaticKeepAliveClientMixin {
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

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  @override
  void initState() {
    super.initState();
    // Initialize the stream
    _initializeStream();

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

  // Initialize stream to get bookmarked entries
  void _initializeStream() {
    // Get current user ID
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      // Handle case when no user is logged in
      setState(() {
        _entries = [];
        _filteredEntries = [];
        _isLoading = false;
      });
      return;
    }

    // FIXED: Only show unlocked bookmarked entries
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('journals')
        .where('userId', isEqualTo: userId)
        .where('isBookmarked', isEqualTo: true)
        .where('isLocked', isEqualTo: false) // Only show unlocked entries
        .orderBy('date', descending: true);

    // Update the stream
    _entriesStream = query.snapshots();

    // Load initial entries
    _loadJournalEntries();
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

          _isLoading = false;

          // Initialize filtered entries with all entries
          _filterEntries();
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

  // IMPROVED: Handle entry updates
  void _handleEntryUpdated(JournalEntry updatedEntry) {
    setState(() {
      // If entry is no longer bookmarked or becomes locked, remove it from our list
      if (!updatedEntry.isBookmarked || updatedEntry.isLocked) {
        _entries.removeWhere((entry) => entry.id == updatedEntry.id);
      } else {
        // Find the entry in our list and update it
        final index = _entries.indexWhere(
          (entry) => entry.id == updatedEntry.id,
        );
        if (index >= 0) {
          _entries[index] = updatedEntry;
        } else {
          // New bookmarked entry - add it
          _entries.add(updatedEntry);
          // Sort by date descending
          _entries.sort((a, b) => b.date.compareTo(a.date));
        }
      }

      // Update filtered entries after modifying the main list
      _filterEntries();
    });
  }

  // Refresh the entire screen
  void _refreshEntries() {
    setState(() {
      _isLoading = true;
    });
    _initializeStream();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title:
            _isSearching
                ? TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search bookmarked entries...',
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
                : const Text(
                  '',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.black87),
              onPressed: _toggleSearch,
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "No Bookmarked Entries",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        "Bookmark your favorite journal entries to find them here",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              )
              // Empty search results state
              : _filteredEntries.isEmpty && _searchQuery.isNotEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      "No Matching Entries",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        "Try a different search term",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: () async {
                  _refreshEntries();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredEntries.length,
                  itemBuilder: (context, index) {
                    final entry = _filteredEntries[index];
                    return JournalEntryCard(
                      entry: entry,
                      onEntryUpdated: _handleEntryUpdated,
                      onEditTap: () async {
                        // Use security service to check if user can access this entry
                        bool canAccess = await _securityService.canAccessEntry(
                          entry,
                          context,
                        );
                        if (!canAccess) return;

                        // If successfully authenticated, navigate to edit screen
                        if (context.mounted) {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => EditJournalScreen(
                                    entry: entry,
                                    onEntryUpdated: _handleEntryUpdated,
                                  ),
                            ),
                          );

                          // No need to manually refresh when returning from edit screen
                          // The onEntryUpdated callback should handle the update
                        }
                      },
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
                    );
                  },
                ),
              ),
    );
  }
}

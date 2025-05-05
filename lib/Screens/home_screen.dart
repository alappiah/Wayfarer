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
  bool _isLoading = true;
  bool _includeLockedEntries = true; // Whether to show locked entries
  final JournalSecurityService _securityService = JournalSecurityService();

  @override
  void initState() {
    super.initState();

    // Initialize app
    _initializeApp();
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
    // Get query from security service that properly filters entries
    Query<Map<String, dynamic>> query = _securityService.getJournalsQuery(
      includeLockedEntries: _includeLockedEntries,
    );

    // Add ordering
    query = query.orderBy('date', descending: true);

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
                  isLocked: data['isLocked'] ?? false, // Add isLocked property
                );
              }).toList();

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

  // Handle entry updates from any screen
  void _handleEntryUpdated(JournalEntry updatedEntry) {
    setState(() {
      // Find the entry in our list and update it
      final index = _entries.indexWhere((entry) => entry.id == updatedEntry.id);
      if (index >= 0) {
        _entries[index] = updatedEntry;
      }
    });
  }

  // Handle tapping on a journal entry
  Future<void> _handleEntryTap(JournalEntry entry) async {
    // Check if user can access this entry
    bool canAccess = await _securityService.canAccessEntry(entry, context);

    if (canAccess) {
      // Navigate to view/edit entry screen
      final updatedEntry = await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => EditJournalScreen(
                entry: entry,
                onEntryUpdated: (JournalEntry updatedEntry) {},
              ),
        ),
      );

      if (updatedEntry != null && updatedEntry is JournalEntry) {
        _handleEntryUpdated(updatedEntry);
      }
    }
    // If canAccess is false, the security service already showed a message
  }

  // Toggle showing locked entries
  void _toggleShowLockedEntries() {
    setState(() {
      _includeLockedEntries = !_includeLockedEntries;
      _isLoading = true;
    });

    _updateEntriesStream();
    _loadJournalEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removed app bar as requested
      // Adding lock toggle button to a row at the top instead
      extendBody: true,
      body: CustomScrollView(
        slivers: [
          // Welcome text with lock toggle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Welcome, Percy',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  // Toggle button for showing/hiding locked entries
                  // IconButton(
                  //   icon: Icon(
                  //     _includeLockedEntries ? Icons.lock_open : Icons.lock,
                  //     color: Colors.black87,
                  //   ),
                  //   onPressed: _toggleShowLockedEntries,
                  //   tooltip: _includeLockedEntries
                  //       ? 'Showing all entries'
                  //       : 'Showing only unlocked entries',
                  // ),
                ],
              ),
            ),
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
          // Journal entries list
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final entry = _entries[index];
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
                      // Remove securityService parameter since it's not defined in JournalEntryCard
                    ),
                  ),
                );
              }, childCount: _entries.length),
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

    // Since entries are now loaded from Firestore, we don't need to manually
    // add them to the list anymore. The stream will automatically update.
    if (result != null && result is JournalEntry) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Journal entry added')));
    }
  }
}

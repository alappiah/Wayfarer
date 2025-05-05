import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wayfarer/Screens/edit_journal_screen.dart';
import '../models/journal_entry.dart';
import '../widgets/journal_entry_card.dart';
import '../services/local_auth_service.dart';

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
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  @override
  void initState() {
    super.initState();
    // Initialize the stream
    _initializeStream();
  }

  // Initialize stream to get bookmarked entries
  void _initializeStream() {
    _entriesStream =
        FirebaseFirestore.instance
            .collection('journals')
            .where('isBookmarked', isEqualTo: true)
            .orderBy('date', descending: true)
            .snapshots();

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

  // Handle entry updates - improved to handle in-memory updates
  void _handleEntryUpdated(JournalEntry updatedEntry) {
    setState(() {
      // If the entry is no longer bookmarked, remove it from our list
      if (!updatedEntry.isBookmarked) {
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
    });
  }

  // Refresh the entire screen
  void _refreshEntries() {
    setState(() {
      _isLoading = true;
    });
    _initializeStream();
  }

  // Handle authentication for locked entries
  Future<bool> _authenticateForLockedEntry(BuildContext context) async {
    final LocalAuthService authService = LocalAuthService();
    bool authenticated = await authService.authenticate(
      reason: 'Authenticate to view locked journal entry',
    );

    if (!authenticated) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Authentication failed')));
    }

    return authenticated;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
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
              : RefreshIndicator(
                onRefresh: () async {
                  _refreshEntries();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return JournalEntryCard(
                      entry: entry,
                      onEntryUpdated: _handleEntryUpdated,
                      onEditTap: () async {
                        // Handle authentication for locked entries
                        if (entry.isLocked) {
                          bool authenticated =
                              await _authenticateForLockedEntry(context);
                          if (!authenticated) return;
                        }

                        // If not locked or successfully authenticated, navigate to edit screen
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
                        // Handle lock toggling with proper authentication
                        if (entry.isLocked) {
                          // Need to authenticate to unlock
                          bool authenticated =
                              await _authenticateForLockedEntry(context);
                          if (!authenticated) return;

                          // Update in Firestore if authenticated
                          await _updateEntryLockStatus(context, entry, false);
                        } else {
                          // No authentication needed to lock
                          await _updateEntryLockStatus(context, entry, true);
                        }
                      },
                    );
                  },
                ),
              ),
    );
  }

  // Helper method to update lock status in Firestore
  Future<void> _updateEntryLockStatus(
    BuildContext context,
    JournalEntry entry,
    bool lockStatus,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('journals')
          .doc(entry.id)
          .update({'isLocked': lockStatus});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lockStatus ? 'Entry locked' : 'Entry unlocked')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating lock status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

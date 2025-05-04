import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/journal_entry.dart';
import '../widgets/journal_entry_card.dart';
import 'add_journal_screen.dart';

class JournalApp extends StatefulWidget {
  const JournalApp({super.key});

  @override
  State createState() => _JournalScreenState();
}





class _JournalScreenState extends State {
  // Stream for listening to journal entries from Firestore
  late Stream<QuerySnapshot> _entriesStream;
  List<JournalEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize Firestore stream - ordered by date descending (newest first)
    _entriesStream =
        FirebaseFirestore.instance
            .collection('journals')
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

                return JournalEntry(
                  id: doc.id,
                  imageUrl: data['imageUrl'] ?? '',
                  title: data['title'] ?? '',
                  description: data['description'] ?? '',
                  date: date,
                  hasLocationData: data['hasLocationData'] ?? false,
                  additionalImages: additionalImages,
                  audioRecordings: audioRecordings,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Welcome text
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Welcome, Percy',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
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
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: JournalEntryCard(entry: _entries[index]),
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

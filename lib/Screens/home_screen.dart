import 'package:flutter/material.dart';
import 'dart:math';
import '../models/journal_entry.dart';
import '../widgets/journal_entry_card.dart';
import 'add_journal_screen.dart';

class JournalApp extends StatefulWidget {
  const JournalApp({super.key});

  @override
  State<JournalApp> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalApp> {
  final List<JournalEntry> _entries = [
    JournalEntry(
      id: '1',
      imageUrl:
          'https://media.tenor.com/F2zkoLGtLFkAAAAe/lr-teq-vegito-dokkan-vegito.png',
      additionalImages: [
        'https://i.ytimg.com/vi/pMZRQJiYbAA/maxresdefault.jpg',
        'https://i.ytimg.com/vi/pMZRQJiYbAA/maxresdefault.jpg',
        'https://via.placeholder.com/400x200/33FF57/FFFFFF?text=Additional+2',
      ],
      title: 'Morning Visit, Maui Beach',
      description:
          'Last night, my dream featured surfing. Whenever this occurs, I am confident that I will have an excellent day on the water.',
      date: DateTime.now().subtract(const Duration(days: 1)),
      audioRecordings: [
        AudioRecording(
          id: 'audio1',
          duration: '00:15',
          recordedAt: DateTime.now().subtract(
            const Duration(days: 1, hours: 2),
          ),
          title: 'Beach sounds',
        ),
        AudioRecording(
          id: 'audio2',
          duration: '00:32',
          recordedAt: DateTime.now().subtract(
            const Duration(days: 1, hours: 1),
          ),
          title: 'Thoughts about the day',
        ),
      ],
    ),
    JournalEntry(
      id: '2',
      imageUrl:
          'https://via.placeholder.com/400x200/8A9A5B/FFFFFF?text=Mountain+Landscape',
      title: 'Morning like, Kalahaku Overlook',
      description:
          'I dreamt about surfing last night, and whenever that happens, I am assured of having a fantastic day on the water.',
      date: DateTime.now().subtract(const Duration(days: 2)),
      hasLocationData: true,
      additionalImages: [
        'https://via.placeholder.com/400x200/5733FF/FFFFFF?text=Mountain+View',
      ],
    ),
    JournalEntry(
      id: '3',
      imageUrl:
          'https://via.placeholder.com/400x200/DB7093/FFFFFF?text=Beach+Sunset',
      title: 'Evening at Wailea Beach',
      description:
          'The sunset was breathtaking today. The colors reflected off the water creating a magical atmosphere that I want to remember.',
      date: DateTime.now().subtract(const Duration(days: 3)),
      audioRecordings: [
        AudioRecording(
          id: 'audio3',
          duration: '01:05',
          recordedAt: DateTime.now().subtract(
            const Duration(days: 3, hours: 4),
          ),
          title: 'Sunset thoughts',
        ),
      ],
    ),
  ];

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

          // Journal entries list
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
    // Create a new empty journal entry to pass to the add screen
    // final newEntry = JournalEntry(
    //   id: DateTime.now().millisecondsSinceEpoch.toString(),
    //   imageUrl: '',
    //   title: '',
    //   description: '',
    //   date: DateTime.now(),
    // );
    
    // Navigate to the add journal screen and await result
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddJournalScreen(),
      ),
    );
    
    // If we got a result back (saved entry), add it to our entries list
    if (result != null && result is JournalEntry) {
      setState(() {
        _entries.insert(0, result);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal entry added'))
      );
    }
  }

  // Method to add new entry with photo (keeping these methods for your reference)
  void addNewEntryWithPhoto() {
    // Simulate adding a new entry with photo
    final random = Random();
    final colors = ['4B86B4', '8A9A5B', 'DB7093', 'DAA520', '708090'];
    final titles = [
      'Beach Walk',
      'Mountain Hike',
      'City Exploration',
      'Forest Adventure',
      'Lake Visit',
    ];

    setState(() {
      _entries.insert(
        0,
        JournalEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          imageUrl:
              'https://via.placeholder.com/400x200/${colors[random.nextInt(colors.length)]}/FFFFFF?text=New+Entry',
          additionalImages: [
            'https://via.placeholder.com/400x200/${colors[random.nextInt(colors.length)]}/FFFFFF?text=Additional',
          ],
          title: titles[random.nextInt(titles.length)],
          description:
              'A new adventure begins. This is a dynamically created journal entry with photo.',
          date: DateTime.now(),
          hasLocationData: random.nextBool(),
        ),
      );
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('New photo entry created')));
  }

  // Method to add new entry with audio
  void addNewEntryWithAudio() {
    // Simulate adding a new entry with audio
    final random = Random();
    final colors = ['4B86B4', '8A9A5B', 'DB7093', 'DAA520', '708090'];
    final titles = [
      'Voice Note',
      'Audio Thoughts',
      'Sound Diary',
      'Voice Journal',
      'Audio Memory',
    ];

    setState(() {
      _entries.insert(
        0,
        JournalEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          imageUrl:
              'https://via.placeholder.com/400x200/${colors[random.nextInt(colors.length)]}/FFFFFF?text=Audio+Entry',
          title: titles[random.nextInt(titles.length)],
          description:
              'A new audio journal entry. Captured my thoughts with voice.',
          date: DateTime.now(),
          audioRecordings: [
            AudioRecording(
              id: 'audio_${DateTime.now().millisecondsSinceEpoch}',
              duration: '00:${random.nextInt(50) + 10}',
              recordedAt: DateTime.now(),
              title: 'Voice recording',
            ),
          ],
        ),
      );
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('New audio entry created')));
  }

  // Method to add new text entry
  void addNewTextEntry() {
    // Simulate adding a new text-only entry
    final random = Random();
    final colors = ['4B86B4', '8A9A5B', 'DB7093', 'DAA520', '708090'];
    final titles = [
      'Daily Reflection',
      'Quick Thought',
      'Note to Self',
      'Journal Note',
      'Today\'s Thoughts',
    ];

    setState(() {
      _entries.insert(
        0,
        JournalEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          imageUrl:
              'https://via.placeholder.com/400x200/${colors[random.nextInt(colors.length)]}/FFFFFF?text=Text+Entry',
          title: titles[random.nextInt(titles.length)],
          description:
              'Sometimes words are enough to capture a moment. This is a text-only journal entry to record my thoughts.',
          date: DateTime.now(),
        ),
      );
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('New text entry created')));
  }
}
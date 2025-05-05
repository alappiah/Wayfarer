import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/journal_entry.dart';
import '../widgets/journal_entry_card.dart';
import '../services/local_auth_service.dart';

class PrivateScreen extends StatefulWidget {
  const PrivateScreen({super.key});

  @override
  State<PrivateScreen> createState() => _PrivateScreenState();
}

class _PrivateScreenState extends State<PrivateScreen> {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _errorMessage;
  List<JournalEntry> _lockedEntries = [];
  final LocalAuthService _authService = LocalAuthService();
  // Stream for listening to journal entries from Firestore
  Stream<QuerySnapshot>? _entriesStream;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Check if biometric authentication is available
    final bool isAvailable = await _authService.isBiometricAvailable();

    if (!isAvailable) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            "Biometric authentication is not available on this device.";
      });
      return;
    }

    // Try to authenticate
    await _authenticate();

    // Only load entries if authentication is successful
    if (_isAuthenticated) {
      _setupEntriesStream();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bool success = await _authService.authenticate(
        reason: 'Authenticate to view your private journal entries',
      );

      setState(() {
        _isAuthenticated = success;
        _isLoading = false;
        if (!success) {
          _errorMessage = "Authentication failed. Please try again.";
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isAuthenticated = false;
        _errorMessage = "Error during authentication: $e";
      });
    }
  }

  void _setupEntriesStream() {
    // Initialize the stream for locked entries
    _entriesStream =
        FirebaseFirestore.instance
            .collection('journals')
            .where('isLocked', isEqualTo: true)
            .orderBy('date', descending: true)
            .snapshots();

    // Listen to the stream
    _loadLockedEntries();
  }

  void _loadLockedEntries() {
    if (_entriesStream == null) return;

    _entriesStream!.listen(
      (snapshot) {
        debugPrint(
          "Received snapshot with ${snapshot.docs.length} locked entries",
        );

        setState(() {
          _lockedEntries =
              snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                debugPrint(
                  "Processing document ID: ${doc.id}, isLocked: ${data['isLocked']}",
                );

                try {
                  return JournalEntry.fromSnapshot(doc);
                } catch (e) {
                  debugPrint("Error parsing document ${doc.id}: $e");
                  // Create a valid placeholder entry if parsing fails
                  return JournalEntry(
                    id: doc.id,
                    imageUrl: data['imageUrl'] ?? '',
                    title: data['title'] ?? 'Error loading entry',
                    description:
                        data['description'] ??
                        'There was an error loading this entry.',
                    date:
                        data['date'] != null
                            ? (data['date'] as Timestamp).toDate()
                            : DateTime.now(),
                    additionalImages: List<String>.from(
                      data['additionalImages'] ?? [],
                    ),
                    hasLocationData: data['hasLocationData'] ?? false,
                    locationName: data['locationName'],
                    location: data['location'],
                    isBookmarked: data['isBookmarked'] ?? false,
                    isLocked: data['isLocked'] ?? false,
                  );
                }
              }).toList();

          _isLoading = false;
        });
      },
      onError: (error) {
        debugPrint("Error loading locked entries: $error");
        setState(() {
          _isLoading = false;
          _errorMessage = "Error loading entries: $error";
        });
      },
    );
  }

  // Handle entry updates from any screen
  void _handleEntryUpdated(JournalEntry updatedEntry) {
    setState(() {
      // If the entry is no longer locked, remove it from our list
      if (!updatedEntry.isLocked) {
        _lockedEntries.removeWhere((entry) => entry.id == updatedEntry.id);
      } else {
        // Find the entry in our list and update it
        final index = _lockedEntries.indexWhere(
          (entry) => entry.id == updatedEntry.id,
        );
        if (index >= 0) {
          _lockedEntries[index] = updatedEntry;
        } else {
          // New locked entry - add it
          _lockedEntries.add(updatedEntry);
          // Sort by date descending
          _lockedEntries.sort((a, b) => b.date.compareTo(a.date));
        }
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Private Entries'),
        foregroundColor: Colors.black,
        actions: [
          if (_isAuthenticated)
            IconButton(
              icon: const Icon(Icons.lock_open),
              onPressed: () {
                // Log out of private section
                setState(() {
                  _isAuthenticated = false;
                  _lockedEntries = [];
                  _entriesStream = null;
                });
              },
              tooltip: 'Lock private section',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_isAuthenticated) {
                _setupEntriesStream();
              } else {
                _authenticate();
              }
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // If loading, show progress indicator
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // If there's an error message, show it
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              "Authentication Error",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Try Again"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: _authenticate,
            ),
          ],
        ),
      );
    }

    // If not authenticated, show authentication prompt
    if (!_isAuthenticated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "Private Entries",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Authentication required to view private entries",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.fingerprint),
              label: const Text("Authenticate"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                await _authenticate();
                if (_isAuthenticated) {
                  _setupEntriesStream();
                }
              },
            ),
          ],
        ),
      );
    }

    // If authenticated but no entries, show empty state
    if (_lockedEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_open, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "No Private Entries",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "You don't have any locked journal entries yet",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Text(
              "Lock entries to keep them private",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            // Debug button to show raw data
            ElevatedButton(
              onPressed: _showDatabaseDebugInfo,
              child: const Text("Debug Database"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // If authenticated and entries exist, show entries list
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Found ${_lockedEntries.length} locked entries",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _lockedEntries.length,
            itemBuilder: (context, index) {
              return JournalEntryCard(
                entry: _lockedEntries[index],
                onEntryUpdated: _handleEntryUpdated,
                onLockToggle: (entry) async {
                  await _updateEntryLockStatus(context, entry, !entry.isLocked);
                },
              );
            },
          ),
        ),
        // Debug button at the bottom
        // Padding(
        //   padding: const EdgeInsets.all(8.0),
        //   child: ElevatedButton(
        //     onPressed: _showDatabaseDebugInfo,
        //     child: const Text("Check Database"),
        //     style: ElevatedButton.styleFrom(
        //       backgroundColor: Colors.grey[300],
        //       foregroundColor: Colors.black87,
        //     ),
        //   ),
        // ),
      ],
    );
  }

  // Enhanced debug method to check raw database data
  Future<void> _showDatabaseDebugInfo() async {
    try {
      final QuerySnapshot allLockedSnapshot =
          await FirebaseFirestore.instance
              .collection('journals')
              .where('isLocked', isEqualTo: true)
              .get();

      final QuerySnapshot allEntriesSnapshot =
          await FirebaseFirestore.instance
              .collection('journals')
              .limit(30)
              .get();

      int totalLockedCount = allLockedSnapshot.docs.length;
      int displayedCount = _lockedEntries.length;
      List<String> entriesInfo = [];

      for (var doc in allEntriesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final isLocked = data['isLocked'] == true;
        final date =
            data['date'] != null
                ? (data['date'] as Timestamp).toDate().toString()
                : 'unknown date';
        entriesInfo.add("ID: ${doc.id}, isLocked: $isLocked, date: $date");
      }

      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Database Debug Info'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total locked entries in database: $totalLockedCount'),
                    Text('Currently displayed locked entries: $displayedCount'),
                    const SizedBox(height: 16),
                    const Text('Sample of recent entries (max 30):'),
                    const SizedBox(height: 8),
                    ...entriesInfo.map(
                      (info) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(info, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    } catch (e) {
      debugPrint("Error in debug info: $e");

      // Show error dialog
      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Debug Error'),
              content: Text('Error fetching debug info: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    }
  }
}

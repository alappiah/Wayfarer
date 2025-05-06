import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/journal_entry.dart';
import '../widgets/journal_entry_card.dart';
import '../services/local_auth_service.dart';
import '../services/journal_security_service.dart';
import '../Screens/edit_journal_screen.dart';

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
  List<JournalEntry> _filteredEntries = []; // For search results
  final LocalAuthService _authService = LocalAuthService();
  final JournalSecurityService _securityService = JournalSecurityService();

  // Stream for listening to journal entries from Firestore
  Stream<QuerySnapshot>? _entriesStream;

  // Get the current user ID
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeScreen();

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
      _filteredEntries = List.from(_lockedEntries);
    } else {
      _filteredEntries =
          _lockedEntries
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

  Future<void> _initializeScreen() async {
    // Ensure we have a valid user ID
    if (_currentUserId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = "You must be logged in to view private entries.";
      });
      return;
    }

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
    // Initialize the stream for locked entries, filtering by current user ID
    // Gets ONLY locked entries for the private screen
    _entriesStream =
        FirebaseFirestore.instance
            .collection('journals')
            .where('userId', isEqualTo: _currentUserId)
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

          // Initialize filtered entries with all entries
          _filterEntries();
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

      // Update filtered entries after modifying the main list
      _filterEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.black,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title:
            _isSearching
                ? TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search private entries...',
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
          if (_isAuthenticated && !_isSearching)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.black87),
              onPressed: _toggleSearch,
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
    // Check if user is logged in first
    if (_currentUserId.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "Not Logged In",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "You must be logged in to view private entries",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              child: const Text("Go to Login"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                // Navigate to login screen
                // Navigator.of(context).pushReplacementNamed('/login');
                // or show login dialog, etc.
              },
            ),
          ],
        ),
      );
    }

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
          ],
        ),
      );
    }

    // Empty search results state
    if (_filteredEntries.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              "No Matching Entries",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
      );
    }

    // If authenticated and entries exist, show entries list
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Found ${_filteredEntries.length} private entries",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _setupEntriesStream();
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
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => EditJournalScreen(
                                entry: entry,
                                onEntryUpdated: _handleEntryUpdated,
                              ),
                        ),
                      );
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
        ),
      ],
    );
  }
}

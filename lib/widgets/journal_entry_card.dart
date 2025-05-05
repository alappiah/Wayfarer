import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/journal_entry.dart';
import '../screens/edit_journal_screen.dart';
import '../services/local_auth_service.dart';

class JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final Function(JournalEntry)? onEntryUpdated;
  final Function()? onEditTap;
  final Function(JournalEntry)? onLockToggle;

  const JournalEntryCard({
    Key? key,
    required this.entry,
    this.onEntryUpdated,
    this.onEditTap,
    this.onLockToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ensure additionalImages is not null
    final additionalImages = entry.additionalImages ?? [];

    // Calculate total media items (main image + additional images + audio recordings)
    final int totalMediaItems =
        1 + additionalImages.length + (entry.audioRecordings?.length ?? 0);

    // Max number of items to display (excluding the main image which is always shown)
    const int maxDisplayItems = 4;

    // Calculate if we need a "+N" tile
    final bool hasMoreItems = totalMediaItems > (maxDisplayItems + 1);
    final int remainingItems =
        hasMoreItems ? totalMediaItems - (maxDisplayItems + 1) : 0;

    // Collect all media items (except main image) to display in the grid
    List<Widget> mediaItems = [];

    // Add additional images
    for (
      int i = 0;
      i < additionalImages.length &&
          mediaItems.length <
              (hasMoreItems ? maxDisplayItems - 1 : maxDisplayItems);
      i++
    ) {
      mediaItems.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            additionalImages[i],
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 100,
                color: Colors.grey[300],
                child: Icon(Icons.image_not_supported, color: Colors.grey[700]),
              );
            },
          ),
        ),
      );
    }

    // Add audio recordings
    if (entry.audioRecordings != null) {
      for (
        int i = 0;
        i < entry.audioRecordings!.length &&
            mediaItems.length <
                (hasMoreItems ? maxDisplayItems - 1 : maxDisplayItems);
        i++
      ) {
        final recording = entry.audioRecordings![i];
        mediaItems.add(
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Audio waveform visualization
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      16,
                      (index) => Container(
                        width: 3,
                        height: 10.0 + (index % 7) * 4.0,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                  ),
                ),
                // Play icon
                const Positioned(
                  left: 10,
                  top: 10,
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Colors.indigo,
                    size: 24,
                  ),
                ),
                // Duration text
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Text(
                    recording.duration,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Add "+N" tile if needed
    if (hasMoreItems) {
      mediaItems.add(
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              "+$remainingItems",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // Open detailed view
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening entry: ${entry.title}')),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main hero image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Hero(
                tag: 'journal_image_${entry.id}',
                child: Stack(
                  children: [
                    Image.network(
                      entry.imageUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 200,
                          color: Colors.grey[300],
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey[700],
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                    // Lock icon overlay if entry is locked
                    if (entry.isLocked)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Media grid (if any additional media items exist)
            if (mediaItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3 / 2,
                  children: mediaItems,
                ),
              ),

            // Title and description
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Show both bookmark and lock status if applicable
                      Row(
                        children: [
                          if (entry.isBookmarked)
                            const Icon(
                              Icons.bookmark,
                              color: Colors.amber,
                              size: 22,
                            ),
                          if (entry.isLocked)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(
                                Icons.lock,
                                color: Colors.blue,
                                size: 22,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Footer with date and actions in TextField-like container
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Date
                    Text(
                      _formatDate(entry.date),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // Action buttons
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: onEditTap ?? () => _handleEditTap(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 20,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.more_horiz),
                          onPressed: () => _showActionSheet(context, entry),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 20,
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Handle edit button tap with authentication check for locked entries
  Future<void> _handleEditTap(BuildContext context) async {
    // Check if entry is locked, if so, authenticate before proceeding
    if (entry.isLocked) {
      final LocalAuthService authService = LocalAuthService();
      bool authenticated = await authService.authenticate(
        reason: 'Authenticate to edit this locked journal entry',
      );
      
      if (!authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed')),
        );
        return; // Stop if authentication fails
      }
    }
    
    // If not locked or successfully authenticated, proceed to edit screen
    _navigateToEditScreen(context);
  }

  // Navigate to edit screen when edit icon is tapped
  void _navigateToEditScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditJournalScreen(
          entry: entry,
          onEntryUpdated: (JournalEntry updatedEntry) {
            if (onEntryUpdated != null) {
              onEntryUpdated!(updatedEntry);
            }
          },
        ),
      ),
    );
    // No need to handle the result as the Firestore stream will catch changes
  }

  void _showActionSheet(BuildContext context, JournalEntry entry) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  entry.isLocked ? Icons.lock_open : Icons.lock,
                  color: entry.isLocked ? Colors.blue : null,
                ),
                title: Text(entry.isLocked ? 'Unlock Entry' : 'Lock Entry'),
                onTap: () {
                  Navigator.pop(context);
                  // Call the onLockToggle callback if provided, otherwise fall back to internal _toggleLock
                  if (onLockToggle != null) {
                    onLockToggle!(entry);
                  } else {
                    _toggleLock(context, entry);
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  entry.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                  color: entry.isBookmarked ? Colors.amber : null,
                ),
                title: Text(
                  entry.isBookmarked ? 'Remove Bookmark' : 'Bookmark Entry',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleBookmark(context, entry);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Entry',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Show confirmation dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete entry ${entry.id}?')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Toggle the locked status of an entry
  void _toggleLock(BuildContext context, JournalEntry entry) async {
    final LocalAuthService authService = LocalAuthService();

    // If we're locking the entry, we don't need authentication
    // But if we're unlocking, we need to verify user identity
    bool proceed = !entry.isLocked;

    if (entry.isLocked) {
      // Try to authenticate before unlocking
      proceed = await authService.authenticate(
        reason: 'Authenticate to unlock this journal entry',
      );

      if (!proceed) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Authentication failed')));
        return;
      }
    }

    if (proceed) {
      // Create updated entry with toggled lock status
      final updatedEntry = entry.copyWith(isLocked: !entry.isLocked);

      try {
        // Update in Firestore
        await FirebaseFirestore.instance
            .collection('journals')
            .doc(entry.id)
            .update({'isLocked': updatedEntry.isLocked});

        // Call the callback if provided
        if (onEntryUpdated != null) {
          onEntryUpdated!(updatedEntry);
        }

        // If we just unlocked an entry, show success message
        // The lock message will be shown by the parent screen that handles removal
        if (!updatedEntry.isLocked) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Entry unlocked')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating entry lock status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleBookmark(BuildContext context, JournalEntry entry) async {
    // Create updated entry with toggled bookmark status
    final updatedEntry = entry.copyWith(isBookmarked: !entry.isBookmarked);

    try {
      // Update in Firestore - this triggers the stream to update the UI
      await FirebaseFirestore.instance
          .collection('journals')
          .doc(entry.id)
          .update({'isBookmarked': updatedEntry.isBookmarked});

      // Still call the callback if provided (for backwards compatibility)
      if (onEntryUpdated != null) {
        onEntryUpdated!(updatedEntry);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedEntry.isBookmarked
                ? 'Entry added to bookmarks'
                : 'Entry removed from bookmarks',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating bookmark: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 2) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return days[date.weekday - 1];
    } else {
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}
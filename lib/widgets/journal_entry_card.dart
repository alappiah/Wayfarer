import 'package:flutter/material.dart';
import '../models/journal_entry.dart';

class JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;

  const JournalEntryCard({Key? key, required this.entry}) : super(key: key);

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
                child: Image.network(
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
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                          icon: const Icon(Icons.bookmark_outline),
                          onPressed: () {},
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
                leading: const Icon(Icons.photo_camera),
                title: const Text('Add Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _addPhotoToEntry(context, entry.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Add Voice Recording'),
                onTap: () {
                  Navigator.pop(context);
                  _addVoiceToEntry(context, entry.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Entry'),
                onTap: () {
                  Navigator.pop(context);
                  _editEntryText(context, entry);
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

  void _addPhotoToEntry(BuildContext context, String entryId) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Adding photo to entry $entryId')));
  }

  void _addVoiceToEntry(BuildContext context, String entryId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Adding voice recording to entry $entryId')),
    );
  }

  void _editEntryText(BuildContext context, JournalEntry entry) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Editing text for entry ${entry.id}')),
    );
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
import 'package:flutter/material.dart';
import '../models/journal_entry.dart';
import 'package:flutter/services.dart'; // For accessing keyboard events

class EditJournalScreen extends StatefulWidget {
  final JournalEntry entry;

  const EditJournalScreen({Key? key, required this.entry}) : super(key: key);

  @override
  State<EditJournalScreen> createState() => _EditJournalScreenState();
}

class _EditJournalScreenState extends State<EditJournalScreen>
    with WidgetsBindingObserver {
  late TextEditingController _descriptionController;
  late TextEditingController _titleController;
  late List<MediaItem> _mediaItems;
  late List<ActivityTracker> _activityTrackers;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry.title);
    _descriptionController = TextEditingController(
      text: widget.entry.description,
    );

    // Initialize media items
    _mediaItems = _initializeMediaItems();

    // Initialize activity trackers
    _activityTrackers = _initializeActivityTrackers();

    // Setup focus listeners to show/hide custom keyboard toolbar
    _titleFocusNode.addListener(_onFocusChange);
    _descriptionFocusNode.addListener(_onFocusChange);

    // Register observer to detect keyboard visibility changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    // This will be called when keyboard appears or disappears
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    final keyboardVisible = bottomInset > 0.0;

    if (_isKeyboardVisible != keyboardVisible) {
      setState(() {
        _isKeyboardVisible = keyboardVisible;
      });
    }
  }

  void _onFocusChange() {
    setState(() {
      _isKeyboardVisible =
          _titleFocusNode.hasFocus || _descriptionFocusNode.hasFocus;
    });
  }

  List<MediaItem> _initializeMediaItems() {
    List<MediaItem> items = [];

    // Add main image
    if (widget.entry.imageUrl.isNotEmpty) {
      items.add(
        MediaItem(
          type: MediaType.image,
          url: widget.entry.imageUrl,
          id: 'main_image',
        ),
      );
    }

    // Add additional images
    if (widget.entry.additionalImages.isNotEmpty) {
      for (int i = 0; i < widget.entry.additionalImages.length; i++) {
        items.add(
          MediaItem(
            type: MediaType.image,
            url: widget.entry.additionalImages[i],
            id: 'additional_image_$i',
          ),
        );
      }
    }

    // Add audio recordings
    if (widget.entry.audioRecordings != null) {
      for (int i = 0; i < widget.entry.audioRecordings!.length; i++) {
        items.add(
          MediaItem(
            type: MediaType.audio,
            audioRecording: widget.entry.audioRecordings![i],
            id: 'audio_recording_$i',
          ),
        );
      }
    }

    return items;
  }

  List<ActivityTracker> _initializeActivityTrackers() {
    // Example activity trackers - you would populate this from widget.entry
    return [
      if (widget.entry.hasLocationData)
        ActivityTracker(
          type: ActivityType.location,
          value: 'Location Data',
          icon: Icons.location_on,
          label: 'Location',
        ),
    ];
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this); // Remove the observer
    super.dispose();
  }

  void _addNewMedia(MediaType type) {
    // Here you would typically show a dialog or navigate to a media picker
    // For demonstration, we'll just add a placeholder
    setState(() {
      if (type == MediaType.image) {
        _mediaItems.add(
          MediaItem(
            type: MediaType.image,
            url: 'https://via.placeholder.com/200',
            id: 'new_image_${DateTime.now().millisecondsSinceEpoch}',
          ),
        );
      } else if (type == MediaType.audio) {
        final now = DateTime.now();
        _mediaItems.add(
          MediaItem(
            type: MediaType.audio,
            audioRecording: AudioRecording(
              id: 'new_audio_${now.millisecondsSinceEpoch}',
              duration: '00:30',
              recordedAt: now,
              title: 'New Recording',
            ),
            id: 'new_audio_${now.millisecondsSinceEpoch}',
          ),
        );
      }
    });
  }

  void _removeMediaItem(String id) {
    setState(() {
      _mediaItems.removeWhere((item) => item.id == id);
    });
  }

  void _removeActivityTracker(ActivityType type) {
    setState(() {
      _activityTrackers.removeWhere((tracker) => tracker.type == type);
    });
  }

  void _addActivityTracker(ActivityType type) {
    // Here you would typically show a dialog to configure the tracker
    // For demonstration, we'll just add a placeholder based on type
    setState(() {
      switch (type) {
        case ActivityType.steps:
          _activityTrackers.add(
            ActivityTracker(
              type: ActivityType.steps,
              value: '0 Steps',
              icon: Icons.directions_walk,
              label: 'Walk',
            ),
          );
          break;
        case ActivityType.audio:
          _activityTrackers.add(
            ActivityTracker(
              type: ActivityType.audio,
              value: '00:00',
              icon: Icons.music_note,
              label: '•••|||||••••',
              isWaveform: true,
            ),
          );
          break;
        case ActivityType.location:
          _activityTrackers.add(
            ActivityTracker(
              type: ActivityType.location,
              value: 'Current Location',
              icon: Icons.location_on,
              label: 'Location',
            ),
          );
          break;
        case ActivityType.mood:
          _activityTrackers.add(
            ActivityTracker(
              type: ActivityType.mood,
              value: 'Happy',
              icon: Icons.mood,
              label: 'Mood',
            ),
          );
          break;
      }
    });
  }

  // Method to dismiss keyboard and hide toolbar
  void _dismissKeyboard() {
    // This will unfocus current focus node and hide keyboard
    FocusScope.of(context).unfocus();

    // Also update keyboard visibility state manually to ensure UI responds correctly
    setState(() {
      _isKeyboardVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Journal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              // Add tap gesture recognizer to dismiss keyboard when tapping outside text fields
              onTap: _dismissKeyboard,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Media section - now using a GridView for better organization
                    _buildMediaGrid(),

                    // Location and activity section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Editable title field
                          TextField(
                            controller: _titleController,
                            focusNode: _titleFocusNode,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Enter title',
                              border: InputBorder.none,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Activity trackers
                          _buildActivityTrackersGrid(),

                          const SizedBox(height: 24),

                          // Journal text area
                          TextField(
                            controller: _descriptionController,
                            focusNode: _descriptionFocusNode,
                            maxLines: 10,
                            decoration: const InputDecoration(
                              hintText: 'Write your journal entry...',
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Custom keyboard toolbar - only visible when keyboard is showing
          if (_isKeyboardVisible) _buildKeyboardToolbar(),
        ],
      ),
      bottomNavigationBar:
          _isKeyboardVisible
              ? null
              : Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saveJournal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Save for Journal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildKeyboardToolbar() {
    return Container(
      color: const Color(0xFF333333),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main toolbar with icons
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolbarIcon(Icons.photo, 'Gallery', () {
                  _addNewMedia(MediaType.image);
                }),
                _buildToolbarIcon(Icons.camera_alt, 'Camera', () {
                  _addNewMedia(MediaType.image);
                }),
                _buildToolbarIcon(Icons.mic, 'Voice', () {
                  _addNewMedia(MediaType.audio);
                }),
                _buildToolbarIcon(Icons.calendar_month, 'Calendar', () {}),
                _buildToolbarIcon(Icons.place, 'Location', () {}),
                // Add a keyboard dismiss button
                _buildToolbarIcon(
                  Icons.keyboard_hide,
                  'Hide Keyboard',
                  _dismissKeyboard,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextOption(String text) {
    return TextButton(
      onPressed: () {},
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 20),
      ),
    );
  }

  Widget _buildToolbarIcon(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Widget _buildMediaGrid() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_mediaItems.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _mediaItems.length,
              itemBuilder: (context, index) {
                return _buildMediaGridItem(_mediaItems[index]);
              },
            ),

          if (_mediaItems.isEmpty)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Center(
                child: Text(
                  'No media items',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaGridItem(MediaItem item) {
    Widget content;

    if (item.type == MediaType.image) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          item.url!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: Icon(Icons.image_not_supported, color: Colors.grey[700]),
            );
          },
        ),
      );
    } else if (item.type == MediaType.audio) {
      content = Container(
        decoration: BoxDecoration(
          color: Colors.blue[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.audiotrack, size: 30, color: Colors.blue[700]),
            const SizedBox(height: 4),
            Text(
              item.audioRecording!.duration,
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '•••|||||••••',
                  style: TextStyle(fontSize: 14, letterSpacing: -1),
                ),
              ],
            ),
            if (item.audioRecording!.title != null)
              Text(
                item.audioRecording!.title!,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      );
    } else {
      content = Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.error, color: Colors.grey[700]),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeMediaItem(item.id),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.5),
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTrackersGrid() {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _activityTrackers.length > 1 ? 2 : 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.5,
          ),
          itemCount: _activityTrackers.length,
          itemBuilder: (context, index) {
            return _buildActivityTrackerItem(_activityTrackers[index]);
          },
        ),
      ],
    );
  }

  Widget _buildActivityTrackerItem(ActivityTracker tracker) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(tracker.icon, size: 24, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!tracker.isWaveform)
                Text(
                  tracker.label,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                )
              else
                Row(
                  children: [
                    Text(
                      tracker.label,
                      style: const TextStyle(fontSize: 14, letterSpacing: -1),
                    ),
                  ],
                ),
              Text(
                tracker.value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _removeActivityTracker(tracker.type),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.5),
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showMediaPickerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Add Photo'),
              onTap: () {
                Navigator.pop(context);
                _addNewMedia(MediaType.image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack),
              title: const Text('Add Audio Recording'),
              onTap: () {
                Navigator.pop(context);
                _addNewMedia(MediaType.audio);
              },
            ),
          ],
        );
      },
    );
  }

  void _showActivityPickerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.directions_walk),
              title: const Text('Add Steps Tracker'),
              onTap: () {
                Navigator.pop(context);
                _addActivityTracker(ActivityType.steps);
              },
            ),
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('Add Audio Tracker'),
              onTap: () {
                Navigator.pop(context);
                _addActivityTracker(ActivityType.audio);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Add Location Tracker'),
              onTap: () {
                Navigator.pop(context);
                _addActivityTracker(ActivityType.location);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mood),
              title: const Text('Add Mood Tracker'),
              onTap: () {
                Navigator.pop(context);
                _addActivityTracker(ActivityType.mood);
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Add Media'),
              onTap: () {
                Navigator.pop(context);
                _showMediaPickerDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_walk),
              title: const Text('Add Activity Tracker'),
              onTap: () {
                Navigator.pop(context);
                _showActivityPickerDialog(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _saveJournal() {
    // Extract images from media items
    List<String> images = [];
    List<AudioRecording> audioRecordings = [];

    for (var item in _mediaItems) {
      if (item.type == MediaType.image && item.url != null) {
        images.add(item.url!);
      } else if (item.type == MediaType.audio && item.audioRecording != null) {
        audioRecordings.add(item.audioRecording!);
      }
    }

    String mainImage = images.isNotEmpty ? images[0] : '';
    List<String> additionalImages = images.length > 1 ? images.sublist(1) : [];

    // Check if we have location data
    bool hasLocationData = _activityTrackers.any(
      (tracker) => tracker.type == ActivityType.location,
    );

    // Update entry with new data
    final updatedEntry = JournalEntry(
      id: widget.entry.id,
      imageUrl: mainImage,
      additionalImages: additionalImages,
      title: _titleController.text,
      description: _descriptionController.text,
      date: widget.entry.date,
      hasLocationData: hasLocationData,
      audioRecordings: audioRecordings.isNotEmpty ? audioRecordings : null,
    );

    // Return updated entry to previous screen
    Navigator.of(context).pop(updatedEntry);

    // Show confirmation
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Journal entry saved')));
  }
}

// Helper classes for UI organization

enum MediaType { image, audio, video }

class MediaItem {
  final MediaType type;
  final String? url;
  final AudioRecording? audioRecording;
  final String id;

  MediaItem({
    required this.type,
    this.url,
    this.audioRecording,
    required this.id,
  });
}

enum ActivityType { steps, audio, location, mood }

class ActivityTracker {
  final ActivityType type;
  final String value;
  final IconData icon;
  final String label;
  final bool isWaveform;

  ActivityTracker({
    required this.type,
    required this.value,
    required this.icon,
    required this.label,
    this.isWaveform = false,
  });
}

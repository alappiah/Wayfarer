import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wayfarer/Screens/audio_recording_screen.dart';
import '../models/journal_entry.dart';
import 'package:flutter/services.dart'; // For accessing keyboard events
import '../widgets/MapLocationPicker.dart';
import '../widgets/LocationSearchDialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditJournalScreen extends StatefulWidget {
  final JournalEntry entry;

  const EditJournalScreen({Key? key, required this.entry}) : super(key: key);

  @override
  State<EditJournalScreen> createState() => _EditJournalScreenState();
}

// A manager class to store and retrieve location data with formatted display options
class JournalLocationManager {
  // Private static map to store locations by entry ID
  static final Map<String, List<dynamic>> _locationsByEntryId = {};

  // Store locations for a specific entry
  static void setLocationsForEntry(String entryId, List<dynamic> locations) {
    _locationsByEntryId[entryId] = locations;
  }

  // Check if an entry has location data
  static bool hasLocationData(String entryId) {
    return _locationsByEntryId.containsKey(entryId) &&
        _locationsByEntryId[entryId]!.isNotEmpty;
  }

  // Get locations for a specific entry
  static List<dynamic>? getLocationsForEntry(String entryId) {
    return _locationsByEntryId[entryId];
  }

  // Get formatted location name for first location in the entry
  static String? getLocationName(String entryId) {
    if (!hasLocationData(entryId)) return null;

    final locations = _locationsByEntryId[entryId]!;
    if (locations.isEmpty) return null;

    // Use the placeName from the first location
    final firstLocation = locations.first;
    return firstLocation['placeName'];
  }

  // Get display location (city) for the first location
  static String getDisplayLocation(String entryId) {
    final locationName = getLocationName(entryId);

    if (locationName == null || locationName.isEmpty) {
      return 'No location'; // Changed from 'Location Data' to 'No location'
    }

    // Parse the location name - expect format like "City, Country"
    final parts = locationName.split(',');
    if (parts.length >= 2) {
      return parts[0].trim(); // Return just the city
    }

    return locationName;
  }

  // Get country for the first location
  static String? getCountry(String entryId) {
    final locationName = getLocationName(entryId);

    if (locationName == null || locationName.isEmpty) {
      return null;
    }

    // Parse the location name - expect format like "City, Country"
    final parts = locationName.split(',');
    if (parts.length >= 2) {
      return parts.last.trim(); // Return just the country
    }

    return null;
  }

  // Get formatted location details string
  static String? getLocationDetails(String entryId) {
    final locationName = getLocationName(entryId);

    if (locationName == null || locationName.isEmpty) {
      return null;
    }

    return locationName;
  }

  // Clear all stored locations
  static void clearAll() {
    _locationsByEntryId.clear();
  }
}

class JournalLocationService {
  // Save a location to Firestore
  static Future<void> saveLocationToJournal(
    String entryId,
    Map<String, dynamic> locationData,
  ) async {
    try {
      // First, update the in-memory manager
      List<dynamic> existingLocations =
          JournalLocationManager.getLocationsForEntry(entryId) ?? [];

      // Replace or add the location data
      bool replaced = false;
      for (int i = 0; i < existingLocations.length; i++) {
        if (existingLocations[i]['id'] == locationData['id']) {
          existingLocations[i] = locationData;
          replaced = true;
          break;
        }
      }

      if (!replaced) {
        existingLocations.add(locationData);
      }

      // Update the in-memory manager
      JournalLocationManager.setLocationsForEntry(entryId, existingLocations);

      // Now update Firestore
      await FirebaseFirestore.instance
          .collection('journals')
          .doc(entryId)
          .update({'location': existingLocations});

      print('Location data saved to Firestore for entry $entryId');
    } catch (e) {
      print('Error saving location data to Firestore: $e');
    }
  }
}

class AudioMediaItemDisplay extends StatefulWidget {
  final MediaItem item;

  const AudioMediaItemDisplay({Key? key, required this.item}) : super(key: key);

  @override
  State<AudioMediaItemDisplay> createState() => _AudioMediaItemDisplayState();
}

class _AudioMediaItemDisplayState extends State<AudioMediaItemDisplay> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();

    // Set up audio player listeners
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      // Reset position if at the end
      if (_position.inSeconds == _duration.inSeconds &&
          _duration.inSeconds > 0) {
        await _audioPlayer.seek(Duration.zero);
      }

      // Play the audio from the file path stored in the item
      // Check if the URL is not null before using it
      if (widget.item.url != null) {
        await _audioPlayer.play(DeviceFileSource(widget.item.url!));
      } else {
        // Handle the case where the URL is null
        print('Cannot play audio: URL is null');
        // Or show an error message to the user
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // Calculate the progress percentage for the waveform display
  double get _progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Play/Pause icon with audio icon
          GestureDetector(
            onTap: _togglePlayback,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.audiotrack, size: 30, color: Colors.blue[700]),
                if (_isPlaying)
                  Icon(
                    Icons.pause_circle,
                    size: 40,
                    color: Colors.blue[700]!.withOpacity(0.5),
                  ),
                if (!_isPlaying)
                  Icon(
                    Icons.play_circle,
                    size: 40,
                    color: Colors.blue[700]!.withOpacity(0.5),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Duration text
          Text(
            _isPlaying
                ? '${_formatDuration(_position)} / ${widget.item.audioRecording!.duration}'
                : widget.item.audioRecording!.duration,
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          // Audio waveform visualization (similar to your dots and lines)
          // We'll make this more interactive with the playback position
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CustomPaint(
              size: const Size(double.infinity, 20),
              painter: WaveformPainter(progress: _progress),
            ),
          ),

          // Recording title if available
          if (widget.item.audioRecording!.title != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.item.audioRecording!.title!,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;

  WaveformPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paintActive =
        Paint()
          ..color = Colors.blue[700]!
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    final paintInactive =
        Paint()
          ..color = Colors.blue[300]!
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    // Define our waveform pattern
    final elements = 15;
    final elementWidth = size.width / elements;

    // Heights for the waveform (you can customize this pattern)
    final heights = [
      0.2,
      0.3,
      0.5,
      0.4,
      0.6,
      0.8,
      0.7,
      0.9,
      0.6,
      0.5,
      0.3,
      0.7,
      0.4,
      0.2,
      0.3,
    ];

    // Calculate where the progress cutoff is
    int activeElements = (elements * progress).floor();

    for (int i = 0; i < elements; i++) {
      final x = i * elementWidth + (elementWidth / 2);
      final height = size.height * heights[i % heights.length];
      final y1 = (size.height - height) / 2;
      final y2 = y1 + height;

      // Use active color for elements before the progress point, inactive for the rest
      final paint = i <= activeElements ? paintActive : paintInactive;

      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _EditJournalScreenState extends State<EditJournalScreen>
    with WidgetsBindingObserver {
  late TextEditingController _descriptionController;
  late TextEditingController _titleController;
  late List<MediaItem> _mediaItems = [];
  bool _isLoadingMedia = true;
  late List<ActivityTracker> _activityTrackers = [];
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  bool _isKeyboardVisible = false;

  void debugLocationData() {
    print("Entry ID: ${widget.entry.id}");
    print(
      "Has location data: ${JournalLocationManager.hasLocationData(widget.entry.id ?? '')}",
    );

    if (JournalLocationManager.hasLocationData(widget.entry.id ?? '')) {
      final locations = JournalLocationManager.getLocationsForEntry(
        widget.entry.id ?? '',
      );
      print("Locations: $locations");
      print(
        "Location name: ${JournalLocationManager.getLocationName(widget.entry.id ?? '')}",
      );
      print(
        "Location details: ${JournalLocationManager.getLocationDetails(widget.entry.id ?? '')}",
      );
    } else {
      print("No location data found for this entry");
    }
  }

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.entry.title);
    _descriptionController = TextEditingController(
      text: widget.entry.description,
    );

    // // Initialize media items
    // _mediaItems = _initializeMediaItems();

    _loadMediaItems();

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

  // Initialize media items from existing entry data
  /// Loads media items from Firestore based on the entry ID
  static Future<List<MediaItem>> initializeMediaItemsFromEntryId(
    String entryId,
  ) async {
    List<MediaItem> items = [];

    try {
      // Fetch the journal entry document from Firestore
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('journals')
              .doc(entryId)
              .get();

      if (!docSnapshot.exists) {
        print('No journal entry found with ID: $entryId');
        return items;
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      await loadLocationDataForEntry(entryId, data);

      // Add main image if it exists
      if (data['imageUrl'] != null && data['imageUrl'].isNotEmpty) {
        items.add(
          MediaItem(
            type: MediaType.image,
            url: data['imageUrl'],
            id: 'main_image',
          ),
        );
      }

      // Add additional images if they exist
      if (data['additionalImages'] != null) {
        List<dynamic> additionalImages = data['additionalImages'];
        for (int i = 0; i < additionalImages.length; i++) {
          final imageUrl = additionalImages[i];
          items.add(
            MediaItem(
              type: MediaType.image,
              url: imageUrl,
              id: 'additional_image_$i',
            ),
          );
        }
      }

      // Add audio recordings if they exist
      if (data['audioRecordings'] != null) {
        List<dynamic> audioRecordings = data['audioRecordings'];
        for (int i = 0; i < audioRecordings.length; i++) {
          final audioData = audioRecordings[i];

          // Convert Firestore Timestamp to DateTime
          DateTime recordedAt;
          if (audioData['recordedAt'] is Timestamp) {
            recordedAt = (audioData['recordedAt'] as Timestamp).toDate();
          } else {
            recordedAt = DateTime.now(); // Default fallback
          }

          // Create an AudioRecording object
          AudioRecording audioRecording = AudioRecording(
            id: audioData['id'] ?? 'recording_$i',
            duration: audioData['duration'] ?? '00:00',
            recordedAt: recordedAt,
            title: audioData['title'] ?? 'Audio Recording ${i + 1}',
            url:
                audioData['url'] ??
                '', // Include the URL in the AudioRecording object
          );

          // Add the MediaItem with the AudioRecording object
          items.add(
            MediaItem(
              type: MediaType.audio,
              url: audioData['url'] ?? '',
              audioRecording: audioRecording,
              id: 'audio_recording_$i',
            ),
          );
        }
      }

      // Store location data if it exists
      if (data['locations'] != null &&
          data['locations'] is List &&
          (data['locations'] as List).isNotEmpty) {
        JournalLocationManager.setLocationsForEntry(entryId, data['locations']);
      }

      return items;
    } catch (e) {
      print('Error initializing media items from Firestore: $e');
      return items;
    }
  }

  static Future<void> loadLocationDataForEntry(
    String entryId,
    Map<String, dynamic> entryData,
  ) async {
    try {
      if (entryData.containsKey('location')) {
        List<dynamic> locationData = [];

        // Handle different potential formats of the location data
        if (entryData['location'] is Map<String, dynamic>) {
          // If location is stored as a single map
          locationData.add(entryData['location']);
        } else if (entryData['location'] is List) {
          // If location is stored as a list of maps
          locationData = List<dynamic>.from(entryData['location']);
        }

        // Store the location data in the manager if we have valid data
        if (locationData.isNotEmpty) {
          JournalLocationManager.setLocationsForEntry(entryId, locationData);
          print('Loaded location data for entry $entryId: $locationData');
        }
      }
    } catch (e) {
      print('Error loading location data from Firestore: $e');
    }
  }

  // static Future<void> loadLocationDataForEntry(
  //   String entryId,
  //   Map<String, dynamic> entryData,
  // ) async {
  //   try {
  //     if (entryData.containsKey('location')) {
  //       List<dynamic> locationData = [];

  //       // Handle different potential formats of the location data
  //       if (entryData['location'] is Map<String, dynamic>) {
  //         // If location is stored as a single map
  //         locationData.add(entryData['location']);
  //       } else if (entryData['location'] is List) {
  //         // If location is stored as a list of maps
  //         locationData = List<dynamic>.from(entryData['location']);
  //       }

  //       // Store the location data in the manager if we have valid data
  //       if (locationData.isNotEmpty) {
  //         JournalLocationManager.setLocationsForEntry(entryId, locationData);
  //         print('Loaded location data for entry $entryId: $locationData');
  //       }
  //     }
  //   } catch (e) {
  //     print('Error loading location data from Firestore: $e');
  //   }
  // }

  /// Load media items from Firestore
  Future<void> _loadMediaItems() async {
    setState(() {
      _isLoadingMedia = true;
    });

    try {
      // Call the FirestoreMediaService to get media items
      _mediaItems = await FirestoreMediaService.initializeMediaItemsFromEntryId(
        widget.entry.id,
      );
    } catch (e) {
      print('Error loading media items: $e');
      // Optional: show an error message to the user
    } finally {
      // Always update the loading state when done
      setState(() {
        _isLoadingMedia = false;
      });
    }
  }

  List<ActivityTracker> _initializeActivityTrackers() {
    // Example activity trackers - you would populate this from widget.entry
    // First, get location data from the manager
    String? locationDetails = JournalLocationManager.getLocationDetails(
      widget.entry.id,
    );
    // List<dynamic>? locations = JournalLocationManager.getLocationsForEntry(
    //   widget.entry.id ?? '',
    // );

    // String locationDetails = JournalLocationManager.getLocationDetails(widget.entry.id);
    return [
      if (widget.entry.hasLocationData ||
          JournalLocationManager.hasLocationData(widget.entry.id))
        ActivityTracker(
          type: ActivityType.location,
          value: locationDetails ?? 'No location',
          icon: Icons.location_on,
          label: 'Location',
          locationName: locationDetails ?? 'Unknown location',
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

  final ImagePicker _picker = ImagePicker();

  Future<void> _addNewMedia(MediaType type, {ImageSource? source}) async {
    if (type == MediaType.image) {
      // Request appropriate permission based on source
      Permission permissionToRequest =
          source == ImageSource.camera ? Permission.camera : Permission.photos;

      final status = await permissionToRequest.request();

      if (status.isGranted) {
        try {
          // Open image picker with the specified source
          final XFile? pickedImage = await _picker.pickImage(
            source:
                source == ImageSource.camera
                    ? ImageSource
                        .camera // This uses the actual ImagePicker's camera source
                    : ImageSource
                        .gallery, // This uses the actual ImagePicker's gallery source
          );

          if (pickedImage != null) {
            setState(() {
              _mediaItems.add(
                MediaItem(
                  type: MediaType.image,
                  url: pickedImage.path,
                  id: 'new_image_${DateTime.now().millisecondsSinceEpoch}',
                  file: File(pickedImage.path),
                ),
              );
            });
          }
        } catch (e) {
          _showErrorDialog("Failed to pick image: $e");
        }
      } else if (status.isPermanentlyDenied) {
        _showPermissionsDialog();
      } else {
        _showErrorDialog(
          source == ImageSource.camera
              ? "Permission to access camera denied"
              : "Permission to access photos denied",
        );
      }
    } else if (type == MediaType.audio) {
      // Request microphone permission
      final micStatus = await Permission.microphone.request();

      if (!micStatus.isGranted) {
        if (micStatus.isPermanentlyDenied) {
          _showPermissionsDialog();
        } else {
          _showErrorDialog(
            "Microphone permission is required for recording audio",
          );
        }
        return;
      }

      // Navigate to audio recording screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AudioRecordingScreen()),
      );

      // Check if we got a recording back
      if (result != null && result is Map<String, dynamic>) {
        setState(() {
          _mediaItems.add(
            MediaItem(
              type: MediaType.audio,
              audioRecording: AudioRecording(
                id: result['id'],
                duration: result['durationFormatted'],
                recordedAt: DateTime.now(),
                title: 'Audio Recording',
              ),
              url: result['filePath'],
              file: File(result['filePath']),
              id: result['id'],
            ),
          );
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showPermissionsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'This app needs permission to access your photos and camera. Please enable it in your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
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

  void _addActivityTracker(
    ActivityType type, {
    String? locationName,
    double? latitude,
    double? longitude,
  }) {
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
          // Format the location name if it's not already in "City, Country" format
          String formattedLocation = locationName ?? 'Unknown Location';

          // If locationName contains city and country information but not in the desired format
          // you could format it here, but your code already formats it correctly as:
          // '${placemarks[0].locality}, ${placemarks[0].country}'

          _activityTrackers.add(
            ActivityTracker(
              type: type,
              value:
                  formattedLocation, // Use the formatted location as the value
              icon: Icons.location_on,
              label: 'Location',
              locationName: formattedLocation,
              latitude: latitude,
              longitude: longitude,
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
                    // Activity trackers
                    _buildActivityTrackersGrid(),
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
                  _addNewMedia(MediaType.image, source: ImageSource.camera);
                }),
                _buildToolbarIcon(Icons.mic, 'Voice', () {
                  _addNewMedia(MediaType.audio);
                }),
                _buildToolbarIcon(Icons.calendar_month, 'Calendar', () {}),
                _buildToolbarIcon(Icons.place, 'Location', () async {
                  // Show a dialog with location options
                  final locationOption = await showDialog<String>(
                    context: context,
                    builder: (BuildContext context) {
                      return SimpleDialog(
                        title: Text('Choose Location Option'),
                        children: <Widget>[
                          SimpleDialogOption(
                            onPressed: () {
                              Navigator.pop(context, 'current');
                            },
                            child: Text('Use Current Location'),
                          ),
                          SimpleDialogOption(
                            onPressed: () {
                              Navigator.pop(context, 'map');
                            },
                            child: Text('Select on Map'),
                          ),
                          SimpleDialogOption(
                            onPressed: () {
                              Navigator.pop(context, 'search');
                            },
                            child: Text('Search Location'),
                          ),
                        ],
                      );
                    },
                  );

                  if (locationOption == 'current') {
                    // Request permission and get current location
                    final permission = await Geolocator.requestPermission();
                    if (permission == LocationPermission.denied ||
                        permission == LocationPermission.deniedForever) {
                      // Handle permission denied
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Location permission is required'),
                        ),
                      );
                      return;
                    }

                    try {
                      final position = await Geolocator.getCurrentPosition();

                      // Get address from coordinates using geocoding package
                      final placemarks = await placemarkFromCoordinates(
                        position.latitude,
                        position.longitude,
                      );

                      final address =
                          placemarks.isNotEmpty
                              ? '${placemarks[0].locality}, ${placemarks[0].country}'
                              : 'Current Location';

                      _addActivityTracker(
                        ActivityType.location,
                        locationName: address,
                        latitude: position.latitude,
                        longitude: position.longitude,
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error getting location: $e')),
                      );
                    }
                  } else if (locationOption == 'map') {
                    // Open map for location selection
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapLocationPicker(),
                      ),
                    );

                    if (result != null) {
                      _addActivityTracker(
                        ActivityType.location,
                        locationName: result['address'],
                        latitude: result['latitude'],
                        longitude: result['longitude'],
                      );
                    }
                  } else if (locationOption == 'search') {
                    // Show search dialog
                    final searchResult = await showDialog(
                      context: context,
                      builder: (context) => LocationSearchDialog(),
                    );

                    if (searchResult != null) {
                      _addActivityTracker(
                        ActivityType.location,
                        locationName: searchResult['address'],
                        latitude: searchResult['latitude'],
                        longitude: searchResult['longitude'],
                      );
                    }
                  }
                }),
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
      // Check if this is a local file or a URL from Firestore
      if (item.file != null) {
        // Local file case
        content = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            item.file!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: Icon(Icons.image_not_supported, color: Colors.grey[700]),
              );
            },
          ),
        );
      } else if (item.url != null && item.url!.isNotEmpty) {
        // URL from Firestore case
        content = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: item.url!,
            fit: BoxFit.cover,
            placeholder:
                (context, url) => Center(child: CircularProgressIndicator()),
            errorWidget:
                (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey[700],
                  ),
                ),
          ),
        );
      } else {
        // Fallback for when neither file nor URL is available
        content = Container(
          color: Colors.grey[300],
          child: Icon(Icons.image_not_supported, color: Colors.grey[700]),
        );
      }
    } else if (item.type == MediaType.audio) {
      // content = Container(
      //   decoration: BoxDecoration(
      //     color: Colors.blue[100],
      //     borderRadius: BorderRadius.circular(12),
      //   ),
      //   child: Column(
      //     mainAxisAlignment: MainAxisAlignment.center,
      //     children: [
      //       Icon(Icons.audiotrack, size: 30, color: Colors.blue[700]),
      //       const SizedBox(height: 4),
      //       Text(
      //         item.audioRecording!.duration,
      //         style: TextStyle(
      //           color: Colors.blue[700],
      //           fontWeight: FontWeight.bold,
      //         ),
      //       ),
      //       const SizedBox(height: 4),
      //       const Row(
      //         mainAxisAlignment: MainAxisAlignment.center,
      //         children: [
      //           Text(
      //             '•••|||||••••',
      //             style: TextStyle(fontSize: 14, letterSpacing: -1),
      //           ),
      //         ],
      //       ),
      //       if (item.audioRecording!.title != null)
      //         Text(
      //           item.audioRecording!.title!,
      //           style: const TextStyle(
      //             fontSize: 10,
      //             fontWeight: FontWeight.w500,
      //           ),
      //           maxLines: 1,
      //           overflow: TextOverflow.ellipsis,
      //         ),
      //     ],
      //   ),
      // );
      content = AudioMediaItemDisplay(item: item);
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
              leading: const Icon(Icons.photo),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _addNewMedia(MediaType.image, source: ImageSource.camera);
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
  final File? file;
  final String? firestorepath;

  MediaItem({
    required this.type,
    this.url,
    this.audioRecording,
    required this.id,
    this.file,
    this.firestorepath,
  });
}

enum ActivityType { steps, audio, location, mood }

class ActivityTracker {
  final ActivityType type;
  final String value;
  final IconData icon;
  final String label;
  final bool isWaveform;
  final String? locationName;
  final double? latitude;
  final double? longitude;

  ActivityTracker({
    required this.type,
    required this.value,
    required this.icon,
    required this.label,
    this.isWaveform = false,
    this.locationName, // Add this parameter
    this.latitude, // Add this parameter
    this.longitude,
  });

  String? get locationDetails {
    if (locationName == null || locationName!.isEmpty) {
      return null;
    }

    return locationName;
  }

  // Add a helper method to get the display name (city)
  String get displayLocation {
    if (locationName == null || locationName!.isEmpty) {
      return value;
    }

    // Parse the location name - expect format like "City, Country"
    final parts = locationName!.split(',');
    if (parts.length >= 2) {
      return parts[0].trim(); // Return just the city
    }

    return locationName!;
  }

  // Add a helper method to get the country
  String? get country {
    if (locationName == null || locationName!.isEmpty) {
      return null;
    }

    // Parse the location name - expect format like "City, Country"
    final parts = locationName!.split(',');
    if (parts.length >= 2) {
      return parts.last.trim(); // Return just the country
    }

    return null;
  }
}

class FirestoreMediaService {
  /// Fetches a journal entry by ID and converts its media content to MediaItem objects
  static Future<List<MediaItem>> initializeMediaItemsFromEntryId(
    String entryId,
  ) async {
    List<MediaItem> items = [];

    try {
      // Fetch the journal entry document from Firestore
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('journals')
              .doc(entryId)
              .get();

      if (!docSnapshot.exists) {
        print('No journal entry found with ID: $entryId');
        return items;
      }

      final data = docSnapshot.data() as Map<String, dynamic>;

      // Process location data if it exists and store it in JournalLocationManager
      if (data['location'] != null) {
        // The format depends on how you store locations, but typically it would be
        // a map or a list of maps with location data
        List<dynamic> locationData = [];

        if (data['location'] is Map<String, dynamic>) {
          // If location is stored as a single map
          locationData.add(data['location']);
        } else if (data['location'] is List) {
          // If location is stored as a list of maps
          locationData = data['location'];
        }

        // Store the location data in the manager
        if (locationData.isNotEmpty) {
          JournalLocationManager.setLocationsForEntry(entryId, locationData);
          print('Loaded location data for entry $entryId: $locationData');
        }
      }

      // Add main image if it exists
      if (data['imageUrl'] != null && data['imageUrl'].isNotEmpty) {
        items.add(
          MediaItem(
            type: MediaType.image,
            url: data['imageUrl'],
            id: 'main_image',
          ),
        );
      }

      // Add additional images if they exist
      if (data['additionalImages'] != null) {
        List<dynamic> additionalImages = data['additionalImages'];
        for (int i = 0; i < additionalImages.length; i++) {
          final imageUrl = additionalImages[i];
          items.add(
            MediaItem(
              type: MediaType.image,
              url: imageUrl,
              id: 'additional_image_$i',
            ),
          );
        }
      }

      // Add audio recordings if they exist
      if (data['audioRecordings'] != null) {
        List<dynamic> audioRecordings = data['audioRecordings'];
        for (int i = 0; i < audioRecordings.length; i++) {
          final audioData = audioRecordings[i];

          // Convert Firestore Timestamp to DateTime
          DateTime recordedAt;
          if (audioData['recordedAt'] is Timestamp) {
            recordedAt = (audioData['recordedAt'] as Timestamp).toDate();
          } else {
            recordedAt = DateTime.now(); // Default fallback
          }

          // Create an AudioRecording object
          AudioRecording audioRecording = AudioRecording(
            id: audioData['id'] ?? 'recording_$i',
            duration: audioData['duration'] ?? '00:00',
            recordedAt: recordedAt,
            title: audioData['title'] ?? 'Audio Recording ${i + 1}',
          );

          // Add the MediaItem with the AudioRecording object
          items.add(
            MediaItem(
              type: MediaType.audio,
              url: audioData['url'] ?? '',
              audioRecording: audioRecording,
              id: 'audio_recording_$i',
            ),
          );
        }
      }

      return items;
    } catch (e) {
      print('Error initializing media items from Firestore: $e');
      return items;
    }
  }
}

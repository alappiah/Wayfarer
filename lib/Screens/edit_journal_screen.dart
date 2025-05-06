import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:wayfarer/Screens/audio_recording_screen.dart';
import '../models/journal_entry.dart';
import 'package:flutter/services.dart'; // For accessing keyboard events
import '../widgets/MapLocationPicker.dart';
import '../widgets/LocationSearchDialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MediaItemsService {
  /// Loads media items from Firestore based on the entry ID
  static Future<List<MediaItem>> initializeMediaItemsFromEntryId(
    String entryId,
  ) async {
    List<MediaItem> items = [];

    try {
      print('⭐ Initializing media items for entry: $entryId');

      // Fetch the journal entry document from Firestore
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('journals')
              .doc(entryId)
              .get();

      if (!docSnapshot.exists) {
        print('❌ No journal entry found with ID: $entryId');
        return items;
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      print('📄 Firestore document retrieved successfully');

      // Debug log for audio recordings in Firestore
      if (data['audioRecordings'] != null) {
        print(
          '🎵 Found ${(data['audioRecordings'] as List).length} audio recordings in Firestore',
        );
        print('Raw audioRecordings data: ${data['audioRecordings']}');
      } else {
        print('❌ No audio recordings found in Firestore document');
      }

      // IMPORTANT: Load audio recordings FIRST to ensure they don't get lost
      if (data['audioRecordings'] != null) {
        List<dynamic> audioRecordings = data['audioRecordings'];

        for (int i = 0; i < audioRecordings.length; i++) {
          final audioData = audioRecordings[i];
          print('Processing audio data $i: $audioData');

          // Skip invalid audio data
          if (audioData == null ||
              audioData['url'] == null ||
              audioData['url'].isEmpty) {
            print('❌ Skipping invalid audio data at index $i');
            continue;
          }

          // Convert recordedAt to DateTime (could be timestamp or millisecondsSinceEpoch)
          DateTime recordedAt;
          if (audioData['recordedAt'] is Timestamp) {
            recordedAt = (audioData['recordedAt'] as Timestamp).toDate();
          } else if (audioData['recordedAt'] is int) {
            recordedAt = DateTime.fromMillisecondsSinceEpoch(
              audioData['recordedAt'],
            );
          } else {
            recordedAt = DateTime.now(); // Default fallback
          }

          // Create an AudioRecording object
          final audioRecording = AudioRecording(
            id: audioData['id'] ?? 'recording_$i',
            duration: audioData['duration'] ?? '00:00',
            recordedAt: recordedAt,
            title: audioData['title'] ?? 'Audio Recording ${i + 1}',
            url: audioData['url'],
            locationName: audioData['locationName'],
          );

          print(
            '✅ Creating MediaItem for audio recording: ${audioData['url']}',
          );

          // Add the MediaItem with the AudioRecording object
          items.add(
            MediaItem(
              type: MediaType.audio,
              url: audioData['url'],
              audioRecording: audioRecording,
              id: audioData['id'] ?? 'audio_recording_$i',
            ),
          );
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
        print('📷 Added main image: ${data['imageUrl']}');
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
          print('📷 Added additional image: $imageUrl');
        }
      }

      // Debug log final count of media items
      print('✅ Total media items loaded: ${items.length}');
      print(
        '🎵 Audio items: ${items.where((item) => item.type == MediaType.audio).length}',
      );
      print(
        '📷 Image items: ${items.where((item) => item.type == MediaType.image).length}',
      );

      return items;
    } catch (e) {
      print('❌ Error initializing media items from Firestore: $e');
      return items;
    }
  }
}

class EditJournalScreen extends StatefulWidget {
  final JournalEntry entry;

  const EditJournalScreen({
    Key? key,
    required this.entry,
    required void Function(JournalEntry updatedEntry) onEntryUpdated,
  }) : super(key: key);

  @override
  State<EditJournalScreen> createState() => _EditJournalScreenState();
}

// A manager class to store and retrieve location data with formatted display options
class JournalLocationManager {
  // Private static map to store locations by entry ID
  static final Map<String, List<dynamic>> _locationsByEntryId = {};
  static bool _isInitializing = false;
  static bool _initialized = false;

  // Add refresh listeners
  static final List<Function()> _refreshListeners = [];

  // Initialize manager by loading all location data from Firestore
  static Future<void> initialize() async {
    if (_initialized && !_isInitializing) {
      print('JournalLocationManager already initialized');
      return;
    }

    if (_isInitializing) {
      print('JournalLocationManager initialization already in progress');
      return;
    }

    _isInitializing = true;
    print('Starting JournalLocationManager initialization');

    try {
      print('Fetching journal entries with location data from Firestore');
      // Fetch all journal entries with location data
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('journals').get();

      print('Fetched ${snapshot.docs.length} journal entries');

      // Clear existing data and load fresh data
      _locationsByEntryId.clear();

      for (var doc in snapshot.docs) {
        String entryId = doc.id;
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        print(
          'Processing entry $entryId: hasLocationData=${data['hasLocationData']}',
        );

        if (data['hasLocationData'] == true && data['locationData'] != null) {
          List<dynamic> locationData = data['locationData'] as List<dynamic>;
          _locationsByEntryId[entryId] = locationData;
          print(
            'Loaded location data for entry $entryId: ${locationData.length} locations',
          );
        }
      }

      _initialized = true;
      _isInitializing = false;
      print(
        'JournalLocationManager initialization complete with ${_locationsByEntryId.length} entries',
      );

      // Notify all refresh listeners
      _notifyRefreshListeners();
    } catch (e) {
      print('Error initializing JournalLocationManager: $e');
      _isInitializing = false;
    }
  }

  // Add a method to refresh the location data
  static Future<bool> refreshLocationData({String? specificEntryId}) async {
    print(
      'Refreshing location data${specificEntryId != null ? " for entry $specificEntryId" : ""}',
    );

    try {
      if (specificEntryId != null) {
        // Refresh only a specific entry
        return await loadLocationDataForEntry(specificEntryId);
      } else {
        // Refresh all entries by re-initializing
        _initialized = false; // Force re-initialization
        await initialize();
        return true;
      }
    } catch (e) {
      print('Error refreshing location data: $e');
      return false;
    }
  }

  // Force load location data for a specific entry
  static Future<bool> loadLocationDataForEntry(String entryId) async {
    print('Force loading location data for entry $entryId');
    try {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance
              .collection('journals')
              .doc(entryId)
              .get();

      if (!doc.exists) {
        print('Entry $entryId does not exist');
        return false;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      if (data['hasLocationData'] != true || data['locationData'] == null) {
        print('Entry $entryId has no location data in Firestore');
        // If entry exists but has no location data, clear any cached data
        _locationsByEntryId.remove(entryId);
        _notifyRefreshListeners();
        return false;
      }

      List<dynamic> locationData = data['locationData'] as List<dynamic>;
      _locationsByEntryId[entryId] = locationData;
      print(
        'Successfully loaded location data for entry $entryId: ${locationData.length} locations',
      );

      // Print the first location for debugging
      if (locationData.isNotEmpty) {
        print('First location data: ${locationData.first}');
      }

      // Notify refresh listeners when a specific entry is updated
      _notifyRefreshListeners();

      return true;
    } catch (e) {
      print('Error loading location data for entry $entryId: $e');
      return false;
    }
  }

  // Store locations for a specific entry
  static void setLocationsForEntry(String entryId, List<dynamic> locations) {
    _locationsByEntryId[entryId] = locations;
    print('Set locations for entry $entryId: ${locations.length} locations');

    // Print the first location for debugging
    if (locations.isNotEmpty) {
      print('First location data: ${locations.first}');
    }

    // Notify refresh listeners when locations are manually set
    _notifyRefreshListeners();
  }

  // Check if an entry has location data
  static bool hasLocationData(String entryId) {
    bool result =
        _locationsByEntryId.containsKey(entryId) &&
        _locationsByEntryId[entryId]!.isNotEmpty;
    print('Checking location data for $entryId: $result');
    return result;
  }

  // Get locations for a specific entry
  static List<dynamic>? getLocationsForEntry(String entryId) {
    var locations = _locationsByEntryId[entryId];
    print(
      'Getting locations for $entryId: ${locations?.length ?? 0} locations',
    );
    return locations;
  }

  // Get location count for a specific entry
  static int getLocationCount(String entryId) {
    if (!hasLocationData(entryId)) return 0;
    return _locationsByEntryId[entryId]!.length;
  }

  // Get formatted location name for a specific location in the entry
  static String? getLocationNameAt(String entryId, int index) {
    if (!hasLocationData(entryId)) {
      print('No location data for $entryId when getting location name');
      return null;
    }

    final locations = _locationsByEntryId[entryId]!;
    if (locations.isEmpty || index >= locations.length) return null;

    // Use the location at the specified index
    final location = locations[index];
    print('Getting location name from: $location');

    // Try different possible location name fields
    if (location is Map<String, dynamic>) {
      if (location.containsKey('placeName')) {
        return location['placeName'];
      } else if (location.containsKey('name')) {
        return location['name'];
      } else if (location.containsKey('address')) {
        return location['address'];
      } else if (location.containsKey('formatted_address')) {
        return location['formatted_address'];
      } else if (location.containsKey('vicinity')) {
        return location['vicinity'];
      }

      // If we can't find a meaningful name, try to construct one
      if (location.containsKey('city') && location.containsKey('country')) {
        return '${location['city']}, ${location['country']}';
      }

      // Print all keys for debugging
      print('Location keys available: ${location.keys.toList()}');
    } else {
      print('Location is not a Map: ${location.runtimeType}');
    }

    // Last resort - try to use any meaningful data
    print('Could not find location name in data: $location');
    return 'Location';
  }

  // Get formatted location name for first location in the entry (for backward compatibility)
  static String? getLocationName(String entryId) {
    return getLocationNameAt(entryId, 0);
  }

  // Get display location (city) for the first location (for backward compatibility)
  static String getDisplayLocation(String entryId) {
    final locationName = getLocationName(entryId);

    if (locationName == null || locationName.isEmpty) {
      return 'No location';
    }

    // Parse the location name - expect format like "City, Country"
    final parts = locationName.split(',');
    if (parts.length >= 2) {
      return parts[0].trim(); // Return just the city
    }

    return locationName;
  }

  // Get country for the first location (for backward compatibility)
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

  // Get formatted location details string for a single location
  static String? getLocationDetails(String entryId) {
    return getLocationName(entryId);
  }

  // Get all location names as a formatted string
  static String? getAllLocationDetails(String entryId) {
    if (!hasLocationData(entryId)) {
      return null;
    }

    final locations = _locationsByEntryId[entryId]!;
    final locationNames = <String>[];

    for (int i = 0; i < locations.length; i++) {
      final name = getLocationNameAt(entryId, i);
      if (name != null && name.isNotEmpty) {
        locationNames.add(name);
      }
    }

    if (locationNames.isEmpty) {
      return null;
    }

    // Join all location names with a bullet separator
    return locationNames.join(' • ');
  }

  // Clear all stored locations
  static void clearAll() {
    _locationsByEntryId.clear();
    _initialized = false;
    print('Cleared all location data');

    // Notify refresh listeners when all data is cleared
    _notifyRefreshListeners();
  }

  // Clear cached location data for a specific entry
  static void clearCache(String entryId) {
    if (_locationsByEntryId.containsKey(entryId)) {
      _locationsByEntryId.remove(entryId);
      print('Cleared cached location data for entry $entryId');

      // Notify refresh listeners when cache is cleared for a specific entry
      _notifyRefreshListeners();
    } else {
      print('No cached location data found for entry $entryId');
    }
  }

  // Add a refresh listener
  static void addRefreshListener(Function() listener) {
    if (!_refreshListeners.contains(listener)) {
      _refreshListeners.add(listener);
      print(
        'Added refresh listener, total listeners: ${_refreshListeners.length}',
      );
    }
  }

  // Remove a refresh listener
  static void removeRefreshListener(Function() listener) {
    _refreshListeners.remove(listener);
    print(
      'Removed refresh listener, remaining listeners: ${_refreshListeners.length}',
    );
  }

  // Notify all refresh listeners
  static void _notifyRefreshListeners() {
    print('Notifying ${_refreshListeners.length} refresh listeners');
    for (var listener in _refreshListeners) {
      listener();
    }
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

class JournalLocationLoader {
  /// Loads location data for a journal entry and updates the JournalLocationManager
  static Future<String?> loadLocationDetailsFromEntryId(String entryId) async {
    String? locationDetails;

    try {
      // Check if location data is already available in the manager
      if (JournalLocationManager.hasLocationData(entryId)) {
        locationDetails = JournalLocationManager.getLocationDetails(entryId);
        print('Using cached location details: $locationDetails');
        return locationDetails;
      } else {
        // Fetch the journal entry document from Firestore
        final docSnapshot =
            await FirebaseFirestore.instance
                .collection('journals')
                .doc(entryId)
                .get();

        if (!docSnapshot.exists) {
          print(
            'No journal entry found with ID: $entryId for location loading',
          );
          return null;
        }

        final data = docSnapshot.data() as Map<String, dynamic>;

        // Debug what data is coming from Firestore
        print('Received Firestore data for location: ${data.keys}');

        // Check for all possible location field names
        List<dynamic>? locationData;

        // Check 'locations' field (matching your media loading code)
        if (data.containsKey('locations') && data['locations'] != null) {
          print('Found locations field in Firestore');
          if (data['locations'] is List) {
            locationData = List<dynamic>.from(data['locations']);
          } else if (data['locations'] is Map<String, dynamic>) {
            locationData = [data['locations']];
          }
        }
        // Check 'location' field (your original code)
        else if (data.containsKey('location') && data['location'] != null) {
          print('Found location field in Firestore');
          if (data['location'] is List) {
            locationData = List<dynamic>.from(data['location']);
          } else if (data['location'] is Map<String, dynamic>) {
            locationData = [data['location']];
          }
        }
        // Check 'locationData' field (mentioned in your initializeTrackers)
        else if (data.containsKey('locationData') &&
            data['locationData'] != null) {
          print('Found locationData field in Firestore');
          if (data['locationData'] is List) {
            locationData = List<dynamic>.from(data['locationData']);
          } else if (data['locationData'] is Map<String, dynamic>) {
            locationData = [data['locationData']];
          }
        }

        if (locationData != null && locationData.isNotEmpty) {
          print('Processing location data: $locationData');

          // Store the location data in the JournalLocationManager
          JournalLocationManager.setLocationsForEntry(entryId, locationData);

          // Get the formatted location details
          locationDetails = JournalLocationManager.getLocationDetails(entryId);

          // Debug the loaded location
          print('Loaded location details: $locationDetails');
          print('Location data loaded: ${locationData.length} locations');
          return locationDetails;
        } else {
          print('No location data found in entry $entryId');
        }
      }

      return null;
    } catch (e) {
      print('Error loading location details from Firestore: $e');
      return null;
    }
  }

  static Future<void> loadLocationDataForEntry(
    String entryId,
    Map<String, dynamic> data,
  ) async {
    try {
      // Check for all possible location field names
      if (data.containsKey('locations') &&
          data['locations'] != null &&
          data['locations'] is List &&
          (data['locations'] as List).isNotEmpty) {
        print('Setting locations from loadLocationDataForEntry');
        JournalLocationManager.setLocationsForEntry(entryId, data['locations']);
      } else if (data.containsKey('location') && data['location'] != null) {
        List<dynamic> locationData = [];
        if (data['location'] is List) {
          locationData = List<dynamic>.from(data['location']);
        } else if (data['location'] is Map<String, dynamic>) {
          locationData = [data['location']];
        }

        if (locationData.isNotEmpty) {
          print('Setting location from loadLocationDataForEntry');
          JournalLocationManager.setLocationsForEntry(entryId, locationData);
        }
      } else if (data.containsKey('locationData') &&
          data['locationData'] != null) {
        print('Setting locationData from loadLocationDataForEntry');
        if (data['locationData'] is List) {
          JournalLocationManager.setLocationsForEntry(
            entryId,
            data['locationData'],
          );
        } else if (data['locationData'] is Map<String, dynamic>) {
          JournalLocationManager.setLocationsForEntry(entryId, [
            data['locationData'],
          ]);
        }
      }
    } catch (e) {
      print('Error loading location data in helper method: $e');
    }
  }
}

class _EditJournalScreenState extends State<EditJournalScreen>
    with WidgetsBindingObserver {
  late TextEditingController _descriptionController;
  late TextEditingController _titleController;
  late List<MediaItem> _mediaItems = [];
  bool _isLoadingMedia = true;
  bool _isLoadingLocation = true;
  bool _isSaving = true;
  bool _isLoadingTrackers = true;
  late List<ActivityTracker> _activityTrackers = [];
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  bool _isKeyboardVisible = false;
  String? _locationDetails;

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
    _loadActivityTrackers();
    _loadLocationData();

    // _refreshActivityTrackers();

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

  void _loadExistingMediaItems() async {
    try {
      print(
        'Loading existing media items for journal entry: ${widget.entry.id}',
      );

      // 1. IMPORTANT: First load ALL media items from Firestore
      List<MediaItem> firestoreItems =
          await MediaItemsService.initializeMediaItemsFromEntryId(
            widget.entry.id,
          );

      print('Loaded ${firestoreItems.length} media items from Firestore');
      print(
        'Audio items from Firestore: ${firestoreItems.where((item) => item.type == MediaType.audio).length}',
      );

      // 2. IMPORTANT: Also explicitly check for audio recordings in the entry object
      if (widget.entry.audioRecordings != null &&
          widget.entry.audioRecordings!.isNotEmpty) {
        print(
          'Entry has ${widget.entry.audioRecordings!.length} audio recordings',
        );

        // Create a set of already loaded audio URLs to avoid duplicates
        final existingAudioUrls =
            firestoreItems
                .where((item) => item.type == MediaType.audio)
                .map((item) => item.url)
                .toSet();

        // Add any recordings from the entry that aren't in firestoreItems yet
        for (var recording in widget.entry.audioRecordings!) {
          if (recording.url != null &&
              recording.url!.isNotEmpty &&
              !existingAudioUrls.contains(recording.url)) {
            firestoreItems.add(
              MediaItem(
                type: MediaType.audio,
                url: recording.url,
                audioRecording: recording,
                id: recording.id,
              ),
            );

            print('Added missing audio recording from entry: ${recording.url}');
          }
        }
      }

      // 3. Update the _mediaItems list with all loaded items
      setState(() {
        _mediaItems = firestoreItems;
      });

      print('Final media items count: ${_mediaItems.length}');
      print(
        'Final audio items: ${_mediaItems.where((item) => item.type == MediaType.audio).length}',
      );
    } catch (e) {
      print('Error loading existing media items: $e');
    }
  }

  // Initialize media items from existing entry data
  /// Loads media items from Firestore based on the entry ID
  static Future<List<MediaItem>> initializeMediaItemsFromEntryId(
    String entryId,
  ) async {
    List<MediaItem> items = [];

    try {
      print('⭐ Initializing media items for entry: $entryId');

      // Fetch the journal entry document from Firestore
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('journals')
              .doc(entryId)
              .get();

      if (!docSnapshot.exists) {
        print('❌ No journal entry found with ID: $entryId');
        return items;
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      print('📄 Firestore document retrieved successfully');

      // Debug log for audio recordings in Firestore
      if (data['audioRecordings'] != null) {
        print(
          '🎵 Found ${(data['audioRecordings'] as List).length} audio recordings in Firestore',
        );
        print('Raw audioRecordings data: ${data['audioRecordings']}');
      } else {
        print('❌ No audio recordings found in Firestore document');
      }

      // IMPORTANT: Load audio recordings FIRST to ensure they don't get lost
      if (data['audioRecordings'] != null) {
        List<dynamic> audioRecordings = data['audioRecordings'];

        for (int i = 0; i < audioRecordings.length; i++) {
          final audioData = audioRecordings[i];
          print('Processing audio data $i: $audioData');

          // Skip invalid audio data
          if (audioData == null ||
              audioData['url'] == null ||
              audioData['url'].isEmpty) {
            print('❌ Skipping invalid audio data at index $i');
            continue;
          }

          // Convert recordedAt to DateTime (could be timestamp or millisecondsSinceEpoch)
          DateTime recordedAt;
          if (audioData['recordedAt'] is Timestamp) {
            recordedAt = (audioData['recordedAt'] as Timestamp).toDate();
          } else if (audioData['recordedAt'] is int) {
            recordedAt = DateTime.fromMillisecondsSinceEpoch(
              audioData['recordedAt'],
            );
          } else {
            recordedAt = DateTime.now(); // Default fallback
          }

          // Create an AudioRecording object
          final audioRecording = AudioRecording(
            id: audioData['id'] ?? 'recording_$i',
            duration: audioData['duration'] ?? '00:00',
            recordedAt: recordedAt,
            title: audioData['title'] ?? 'Audio Recording ${i + 1}',
            url: audioData['url'],
            locationName: audioData['locationName'],
          );

          print(
            '✅ Creating MediaItem for audio recording: ${audioData['url']}',
          );

          // Add the MediaItem with the AudioRecording object
          items.add(
            MediaItem(
              type: MediaType.audio,
              url: audioData['url'],
              audioRecording: audioRecording,
              id: 'audio_recording_$i',
            ),
          );
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
        print('📷 Added main image: ${data['imageUrl']}');
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
          print('📷 Added additional image: $imageUrl');
        }
      }

      // Debug log final count of media items
      print('✅ Total media items loaded: ${items.length}');
      print(
        '🎵 Audio items: ${items.where((item) => item.type == MediaType.audio).length}',
      );
      print(
        '📷 Image items: ${items.where((item) => item.type == MediaType.image).length}',
      );

      return items;
    } catch (e) {
      print('❌ Error initializing media items from Firestore: $e');
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

  Future<void> _loadActivityTrackers() async {
    setState(() {
      _isLoadingTrackers = true;
    });

    try {
      print("Loading activity trackers for entry ID: ${widget.entry.id}");

      // Force refresh location data from Firestore
      if (widget.entry.hasLocationData) {
        print("Refreshing location data from Firestore");

        // This assumes JournalLocationManager has a method to load from Firestore
        // If not, you would need to implement one that directly queries Firestore
        await JournalLocationManager.loadLocationDataForEntry(widget.entry.id);

        // Update location details in state
        String? refreshedLocationDetails =
            JournalLocationManager.getAllLocationDetails(widget.entry.id);

        if (refreshedLocationDetails != null &&
            refreshedLocationDetails.isNotEmpty) {
          setState(() {
            _locationDetails = refreshedLocationDetails;
            print("Updated location details: $_locationDetails");
          });
        }
      }

      // Re-initialize trackers with fresh data
      List<ActivityTracker> freshTrackers = _initializeActivityTrackers();

      // Update state with new trackers
      setState(() {
        _activityTrackers = freshTrackers;
        print(
          "Activity trackers refreshed with ${_activityTrackers.length} items",
        );
      });
    } catch (e) {
      print('Error loading activity trackers: $e');
    } finally {
      setState(() {
        _isLoadingTrackers = false;
      });
    }
  }

  /// Loads location details for the journal entry
  Future<void> _loadLocationDetails() async {
    if (!widget.entry.hasLocationData) return;

    try {
      _locationDetails =
          await JournalLocationLoader.loadLocationDetailsFromEntryId(
            widget.entry.id,
          );
    } catch (e) {
      print('Error loading location details: $e');
    }
  }

  // Add this method to load location data
  Future<void> _loadLocationData() async {
    if (!widget.entry.hasLocationData) {
      print(
        'Entry does not have location data according to widget.entry.hasLocationData',
      );
      return;
    }

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      print('Loading location details for entry: ${widget.entry.id}');

      // Load location details and update state
      final locationDetails =
          await JournalLocationLoader.loadLocationDetailsFromEntryId(
            widget.entry.id,
          );

      print('Loaded location details: $locationDetails');

      if (mounted) {
        setState(() {
          _locationDetails = locationDetails;
          // Reinitialize trackers to include the updated location
          _activityTrackers = _initializeActivityTrackers();
        });
      }
    } catch (e) {
      print('Error loading location data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  List<ActivityTracker> _initializeActivityTrackers() {
    // Debug prints
    print("Entry ID: ${widget.entry.id}");
    print("Has location data: ${widget.entry.hasLocationData}");
    print(
      "Manager has location data: ${JournalLocationManager.hasLocationData(widget.entry.id)}",
    );
    print("Current location details in state: $_locationDetails");

    // Initialize trackers list
    final List<ActivityTracker> trackers = [];

    // Add location tracker if needed
    if (widget.entry.hasLocationData ||
        JournalLocationManager.hasLocationData(widget.entry.id)) {
      // Get location count from manager
      int locationCount = JournalLocationManager.getLocationCount(
        widget.entry.id,
      );
      print("Location count from manager: $locationCount");

      // Check if we need to force load the location data
      if (locationCount == 0 && widget.entry.hasLocationData) {
        print(
          "Entry claims to have location data but manager doesn't have it. Will try to load.",
        );
       
      }

      // Direct approach: Get location data for each index individually
      List<String> locationList = [];

      // First try to get all location names directly from the manager
      for (int i = 0; i < locationCount; i++) {
        String? locationName = JournalLocationManager.getLocationNameAt(
          widget.entry.id,
          i,
        );
        if (locationName != null && locationName.isNotEmpty) {
          locationList.add(locationName);
          print("Added location from manager at index $i: $locationName");
        }
      }

      // If we got no locations from the direct approach, try using getAllLocationDetails
      if (locationList.isEmpty) {
        String? allLocationDetails =
            JournalLocationManager.getAllLocationDetails(widget.entry.id);

        // If still not available, check state variable
        if (allLocationDetails == null || allLocationDetails.isEmpty) {
          allLocationDetails = _locationDetails;
          print("Using location details from state: $allLocationDetails");
        } else {
          print("Using all location details from manager: $allLocationDetails");
        }

        // Parse the location details
        if (allLocationDetails != null && allLocationDetails.isNotEmpty) {
          // Split by bullet separator
          locationList = allLocationDetails.split(' • ');
          print(
            "Parsed ${locationList.length} locations from combined details",
          );
        }
      }

      // Create trackers for each location
      if (locationList.isNotEmpty) {
        print("Creating trackers for ${locationList.length} locations");

        for (int i = 0; i < locationList.length; i++) {
          String locationName = locationList[i].trim();

          // Only add if there's a non-empty location name
          if (locationName.isNotEmpty) {
            trackers.add(
              ActivityTracker(
                type: ActivityType.location,
                value: locationName,
                icon: Icons.location_on,
                label:
                    locationList.length > 1 ? 'Location ${i + 1}' : 'Location',
                locationName: locationName,
              ),
            );
            print("Added tracker for location: '$locationName'");
          }
        }
      } else {
        // Raw approach: try to directly access the location objects
        final rawLocations = JournalLocationManager.getLocationsForEntry(
          widget.entry.id,
        );

        if (rawLocations != null && rawLocations.isNotEmpty) {
          print("Got ${rawLocations.length} raw location objects");

          for (int i = 0; i < rawLocations.length; i++) {
            final location = rawLocations[i];
            String locationName = "Location ${i + 1}";

            // Try to extract a usable name from the location object
            if (location is Map<String, dynamic>) {
              if (location.containsKey('placeName')) {
                locationName = location['placeName'];
              } else if (location.containsKey('name')) {
                locationName = location['name'];
              } else if (location.containsKey('address')) {
                locationName = location['address'];
              } else if (location.containsKey('formatted_address')) {
                locationName = location['formatted_address'];
              }
            }

            trackers.add(
              ActivityTracker(
                type: ActivityType.location,
                value: locationName,
                icon: Icons.location_on,
                label: 'Location ${i + 1}',
                locationName: locationName,
              ),
            );
            print("Added tracker for raw location: '$locationName'");
          }
        } else {
          // Fallback for no locations
          trackers.add(
            ActivityTracker(
              type: ActivityType.location,
              value: 'No location',
              icon: Icons.location_on,
              label: 'Location',
              locationName: 'Unknown location',
            ),
          );
          print("Added fallback tracker for no locations");
        }
      }
    }

    // Add other trackers for mood, weather, etc. if needed
    // ...

    // Final debug
    print("Final tracker count: ${trackers.length}");
    return trackers;
  }

  /// Refreshes activity trackers with the latest data from Firestore
  //   Future<void> _refreshActivityTrackers() async {
  //   if (!mounted) return;

  //   print("Refreshing activity trackers for entry: ${widget.entry.id}");

  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
  //     // First, fetch the latest entry data directly from Firestore
  //     final entryDoc = await FirebaseFirestore.instance
  //         .collection('journals')
  //         .doc(widget.entry.id)
  //         .get();

  //     if (entryDoc.exists) {
  //       Map<String, dynamic> entryData = entryDoc.data() as Map<String, dynamic>;
  //       bool hasLocationData = entryData['hasLocationData'] ?? false;

  //       // Store the current state of location data
  //       print("Firestore location data status: $hasLocationData");

  //       // If Firestore says we have location data, make sure it's loaded
  //       if (hasLocationData && entryData.containsKey('locationData')) {
  //         List<dynamic> locationData = entryData['locationData'] as List<dynamic>;

  //         // Force update the location manager cache with fresh data
  //         JournalLocationManager.setLocationsForEntry(widget.entry.id, locationData);
  //         print("Directly set ${locationData.length} locations in manager");

  //         // Pre-load the location details
  //         _locationDetails = JournalLocationManager.getAllLocationDetails(widget.entry.id);
  //         print("Pre-loaded location details: $_locationDetails");
  //       } else {
  //         // Clear the location cache if no location data exists
  //         if (JournalLocationManager._locationsByEntryId.containsKey(widget.entry.id)) {
  //           JournalLocationManager._locationsByEntryId.remove(widget.entry.id);
  //           print("Cleared location cache for entry: ${widget.entry.id}");
  //         }
  //         _locationDetails = null;
  //         print("Cleared location data - entry has no locations");
  //       }
  //     }

  //     // Reinitialize trackers with fresh data
  //     setState(() {
  //       _activityTrackers = _initializeActivityTrackers();
  //       print("Refreshed activity trackers: ${_activityTrackers.length} items");
  //       _isLoading = false;
  //     });
  //   } catch (e) {
  //     print("Error refreshing activity trackers: $e");
  //     setState(() {
  //       // Attempt to initialize with existing data on error
  //       _activityTrackers = _initializeActivityTrackers();
  //       _isLoading = false;
  //     });
  //   }
  // }

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
    // Debug log before removal
    print('Removing media item with ID: $id');
    print('Media items before removal: ${_mediaItems.length}');
    print(
      'Audio items before removal: ${_mediaItems.where((item) => item.type == MediaType.audio).length}',
    );
    print(
      'Image items before removal: ${_mediaItems.where((item) => item.type == MediaType.image).length}',
    );

    // Find the item to remove
    int indexToRemove = _mediaItems.indexWhere((item) => item.id == id);

    if (indexToRemove != -1) {
      // Get the item to check its type
      MediaItem itemToRemove = _mediaItems[indexToRemove];

      // Handle removal differently based on item type
      if (itemToRemove.type == MediaType.image) {
        // For images, just remove the specific image
        _mediaItems.removeAt(indexToRemove);
        print('Removed image item at index $indexToRemove');
      } else if (itemToRemove.type == MediaType.audio) {
        // For audio, just remove the specific audio
        _mediaItems.removeAt(indexToRemove);
        print('Removed audio item at index $indexToRemove');
      }

      // Debug log after removal
      print('Media items after removal: ${_mediaItems.length}');
      print(
        'Audio items after removal: ${_mediaItems.where((item) => item.type == MediaType.audio).length}',
      );
      print(
        'Image items after removal: ${_mediaItems.where((item) => item.type == MediaType.image).length}',
      );

      // Update the state to rebuild the UI
      setState(() {});
    } else {
      print('Could not find media item with ID: $id');
    }
  }

  void _removeActivityTracker(ActivityTracker tracker) {
    setState(() {
      // Remove the specific tracker instance
      _activityTrackers.remove(tracker);
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

  // Update your _buildActivityTrackersGrid method to better handle multiple items
  Widget _buildActivityTrackersGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _activityTrackers.isNotEmpty
            ? Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
              child: Text(
                "Locations",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            )
            : SizedBox.shrink(),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
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
            onTap: () => _removeActivityTracker(tracker),
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

  Future<void> _saveJournal() async {
    try {
      // Show loading indicator
      _showLoadingDialog();

      // Cloudinary credentials
      const cloudName = 'dgg2rcnqc';
      const uploadPreset = 'ml_default';

      // Lists for storing uploaded media URLs
      List<String> imageUrls = [];
      List<Map<String, dynamic>> audioRecordingsData = [];

      print('🔍 SAVING JOURNAL - DEBUG INFO:');
      print(
        'Original entry audio recordings: ${widget.entry.audioRecordings?.length ?? 0}',
      );
      print('_mediaItems total count: ${_mediaItems.length}');
      print(
        '_mediaItems audio count: ${_mediaItems.where((item) => item.type == MediaType.audio).length}',
      );


      // 1. Get audio recordings from widget.entry
      if (widget.entry.audioRecordings != null) {
        for (var recording in widget.entry.audioRecordings!) {
          if (recording.url != null && recording.url!.isNotEmpty) {
            audioRecordingsData.add({
              'id': recording.id,
              'url': recording.url,
              'duration': recording.duration,
              'recordedAt': recording.recordedAt.millisecondsSinceEpoch,
              'title': recording.title,
              'locationName': recording.locationName,
            });
            print('✅ Added audio from widget.entry: ${recording.url}');
          }
        }
      }

      // 2. Get audio recordings from _mediaItems
      final existingAudioUrls =
          audioRecordingsData.map((data) => data['url'].toString()).toSet();

      for (var item in _mediaItems.where(
        (item) => item.type == MediaType.audio,
      )) {
        if (item.url != null &&
            item.audioRecording != null &&
            !existingAudioUrls.contains(item.url)) {
          audioRecordingsData.add({
            'id': item.audioRecording!.id,
            'url': item.url!,
            'duration': item.audioRecording!.duration ?? '00:00',
            'recordedAt':
                item.audioRecording!.recordedAt.millisecondsSinceEpoch,
            'title': item.audioRecording!.title,
            'locationName': item.audioRecording!.locationName,
          });

          existingAudioUrls.add(item.url!);
          print('✅ Added audio from _mediaItems: ${item.url}');
        }
      }

      print('📊 Total audio recordings found: ${audioRecordingsData.length}');

      // 3. Process and upload images
      for (var item in _mediaItems) {
        if (item.type == MediaType.image && item.url != null) {
          try {
            // If it's a local file path (new image)
            if (item.url!.startsWith('file://') ||
                !item.url!.startsWith('http')) {
              final secureUrl = await _uploadToCloudinary(
                item.url!,
                cloudName,
                uploadPreset,
                'image',
              );

              if (secureUrl.isNotEmpty) {
                imageUrls.add(secureUrl);
                print('📤 Image uploaded successfully: $secureUrl');
              }
            } else {
              // Already a remote URL, just add it (existing image)
              imageUrls.add(item.url!);
              print('📷 Added existing image: ${item.url}');
            }
          } catch (e) {
            print('❌ Error uploading image: $e');
            // Continue with the next image if one fails
          }
        }
      }

      // 4. Upload any new audio recordings
      for (var item in _mediaItems.where(
        (item) => item.type == MediaType.audio,
      )) {
        if (item.url != null &&
            (item.url!.startsWith('file://') ||
                !item.url!.startsWith('http'))) {
          try {
            final secureUrl = await _uploadToCloudinary(
              item.url!,
              cloudName,
              uploadPreset,
              'auto', // Use 'auto' resource type for audio
            );

            if (secureUrl.isNotEmpty &&
                !existingAudioUrls.contains(secureUrl)) {
              // Update the URL in the corresponding audioRecordingsData entry
              bool found = false;
              for (var data in audioRecordingsData) {
                if (data['id'] == item.audioRecording!.id) {
                  data['url'] = secureUrl;
                  found = true;
                  print('📤 Updated audio URL after upload: $secureUrl');
                  break;
                }
              }

              // If not found, add a new entry
              if (!found) {
                audioRecordingsData.add({
                  'id': item.audioRecording!.id,
                  'url': secureUrl,
                  'duration': item.audioRecording!.duration ?? '00:00',
                  'recordedAt':
                      item.audioRecording!.recordedAt.millisecondsSinceEpoch,
                  'title': item.audioRecording!.title,
                  'locationName': item.audioRecording!.locationName,
                });
                print('📤 Added new uploaded audio: $secureUrl');
              }

              existingAudioUrls.add(secureUrl);
            }
          } catch (e) {
            print('❌ Error uploading audio: $e');
          }
        }
      }

      // 5. Prepare location data
      List<Map<String, dynamic>> locationDataList = [];
      for (var tracker in _activityTrackers) {
        if (tracker.type == ActivityType.location) {
          Map<String, dynamic> locationData = {
            'placeName': tracker.locationName ?? 'Unknown location',
            'displayName': tracker.value,
            'timestamp': Timestamp.now(),
          };

          if (tracker.latitude != null && tracker.longitude != null) {
            locationData['latitude'] = tracker.latitude;
            locationData['longitude'] = tracker.longitude;
          }

          locationDataList.add(locationData);
        }
      }

      // 6. Create journal entry data structure
      String mainImage = imageUrls.isNotEmpty ? imageUrls[0] : '';
      List<String> additionalImages =
          imageUrls.length > 1 ? imageUrls.sublist(1) : [];

      final entryId = widget.entry.id;
      print('📝 Updating journal entry with ID: $entryId');
      print('📊 Audio recordings to save: ${audioRecordingsData.length}');

      // Create journal entry update data map
      final journalUpdateData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'imageUrl': mainImage,
        'additionalImages': additionalImages,
        'audioRecordings': audioRecordingsData,
        'locations': locationDataList,
        'hasLocationData': locationDataList.isNotEmpty,
        'updatedAt': Timestamp.now(),
      };

      // 7. Update entry in Firestore
      await FirebaseFirestore.instance
          .collection('journals')
          .doc(entryId)
          .update(journalUpdateData);

      print("✅ Journal updated successfully in Firestore!");

      // 8. Create updated entry object
      final updatedEntry = JournalEntry(
        id: entryId,
        imageUrl: mainImage,
        additionalImages: additionalImages,
        title: _titleController.text,
        description: _descriptionController.text,
        date: widget.entry.date,
        hasLocationData: locationDataList.isNotEmpty,
        audioRecordings:
            audioRecordingsData
                .map(
                  (data) => AudioRecording(
                    id: data['id'] ?? '',
                    duration: data['duration'] ?? '00:00',
                    recordedAt:
                        data['recordedAt'] != null
                            ? DateTime.fromMillisecondsSinceEpoch(
                              data['recordedAt'],
                            )
                            : DateTime.now(),
                    title: data['title'],
                    url: data['url'],
                    locationName: data['locationName'],
                  ),
                )
                .toList(),
      );

      print(
        '✅ Updated entry created with ${updatedEntry.audioRecordings?.length ?? 0} audio recordings',
      );

      // Hide loading indicator
      Navigator.of(context).pop();

      // Return updated entry to previous screen
      Navigator.of(context).pop(updatedEntry);

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal entry updated successfully')),
      );
    } catch (e) {
      print('❌ Error saving journal: $e');

      // Hide loading indicator if showing
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating journal: ${e.toString()}')),
      );
    }
  }

  // Generic upload function for both images and audio
  Future<String> _uploadToCloudinary(
    String filePath,
    String cloudName,
    String uploadPreset,
    String resourceType,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      print('File does not exist: $filePath');
      return '';
    }

    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
    );

    final request =
        http.MultipartRequest('POST', url)
          ..fields['upload_preset'] = uploadPreset
          ..fields['folder'] =
              resourceType == 'image' ? 'journal_images' : 'journal_audio'
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

    print('Uploading file to Cloudinary: $filePath');
    final response = await request.send();

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      print('Upload failed with status ${response.statusCode}: $errorBody');
      throw Exception(
        'Failed to upload file to Cloudinary: ${response.statusCode}',
      );
    }

    final resStr = await response.stream.bytesToString();
    final responseJson = jsonDecode(resStr);
    return responseJson['secure_url'];
  }

  // Helper method to show loading dialog
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Updating journal entry..."),
              ],
            ),
          ),
        );
      },
    );
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

Future<void> processLocationData(
  String entryId,
  Map<String, dynamic> data,
) async {
  try {
    // Check for the standard 'locationData' field first
    if (data['hasLocationData'] == true && data['locationData'] != null) {
      List<dynamic> locationData = data['locationData'] as List<dynamic>;
      JournalLocationManager.setLocationsForEntry(entryId, locationData);
      print(
        'Stored locationData for entry $entryId: ${locationData.length} locations',
      );
    }
    // Also check for the 'location' field as a fallback
    else if (data['location'] != null) {
      List<dynamic> locationData = [];

      // Handle different formats of location data
      if (data['location'] is Map<String, dynamic>) {
        locationData.add(data['location']);
      } else if (data['location'] is List) {
        locationData = List<dynamic>.from(data['location']);
      }

      if (locationData.isNotEmpty) {
        // Debug the structure of location data
        print('Location data structure for entry $entryId:');
        for (var location in locationData) {
          if (location is Map) {
            // Log available fields to help with debugging
            print('Available fields: ${location.keys.toList()}');

            // Ensure each location has a placeName field for consistency
            if (!location.containsKey('placeName')) {
              // Try to find an alternative field to use as placeName
              if (location.containsKey('name')) {
                location['placeName'] = location['name'];
              } else if (location.containsKey('formatted_address')) {
                location['placeName'] = location['formatted_address'];
              } else if (location.containsKey('vicinity')) {
                location['placeName'] = location['vicinity'];
              } else if (location.containsKey('city') &&
                  location.containsKey('country')) {
                location['placeName'] =
                    '${location['city']}, ${location['country']}';
              }
            }
          }
        }

        // Store the processed location data
        JournalLocationManager.setLocationsForEntry(entryId, locationData);
        print(
          'Stored location data for entry $entryId: ${locationData.length} locations',
        );

        // Update Firestore to standardize the location data format
        await FirebaseFirestore.instance
            .collection('journals')
            .doc(entryId)
            .update({'hasLocationData': true, 'locationData': locationData});
        print(
          'Updated Firestore with standardized location data for entry $entryId',
        );
      }
    } else {
      print('No location data found for entry $entryId');
    }
  } catch (e) {
    print('Error processing location data for entry $entryId: $e');
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
          locationData.add(data['location']);
        } else if (data['location'] is List) {
          locationData = data['location'];
        }

        if (locationData.isNotEmpty) {
          // Debug the structure of your location data
          print('Location data structure:');
          for (var location in locationData) {
            print('Location: $location');
            print('Has placeName? ${location.containsKey('placeName')}');

            // If placeName doesn't exist, check what fields do exist
            if (!location.containsKey('placeName') && location is Map) {
              print('Available fields: ${location.keys.toList()}');

              // If there's a name field, consider using that instead
              if (location.containsKey('name')) {
                print('Found name field: ${location['name']}');
              }
            }
          }

          JournalLocationManager.setLocationsForEntry(entryId, locationData);
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

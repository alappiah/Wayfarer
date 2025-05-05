import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntry {
  final String id;
  final String imageUrl; // Main cover image
  final List<String> additionalImages; // Multiple additional images
  final String title;
  final String description;
  final DateTime date;
  final List<AudioRecording>? audioRecordings; // Multiple audio recordings
  final bool hasLocationData;
  final String? locationName; // Display name of the location
  final String? location;
  final bool isBookmarked;
  final bool isLocked; // Added for bookmarking functionality

  JournalEntry({
    required this.id,
    required this.imageUrl,
    this.additionalImages = const [],
    required this.title,
    required this.description,
    required this.date,
    this.audioRecordings,
    this.hasLocationData = false,
    this.locationName,
    this.location,
    this.isBookmarked = false, // Default to not bookmarked
    this.isLocked = false,
  });

  // Create a copy of this JournalEntry with modified fields
  JournalEntry copyWith({
    String? id,
    String? imageUrl,
    List<String>? additionalImages,
    String? title,
    String? description,
    DateTime? date,
    List<AudioRecording>? audioRecordings,
    bool? hasLocationData,
    String? locationName,
    String? location,
    bool? isBookmarked,
    bool? isLocked,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      additionalImages: additionalImages ?? this.additionalImages,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      audioRecordings: audioRecordings ?? this.audioRecordings,
      hasLocationData: hasLocationData ?? this.hasLocationData,
      locationName: locationName ?? this.locationName,
      location: location ?? this.location,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isLocked: isLocked ?? this.isLocked
    );
  }

  // Convert JournalEntry to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'additionalImages': additionalImages,
      'title': title,
      'description': description,
      'date': date,
      'hasLocationData': hasLocationData,
      'locationName': locationName,
      'location': location,
      'isBookmarked': isBookmarked,
      'isLocked' : isLocked,
      'audioRecordings': audioRecordings?.map((recording) => recording.toMap()).toList(),
    };
  }
  
  // Create a JournalEntry from a DocumentSnapshot
  factory JournalEntry.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    
    List<AudioRecording> audioRecordings = [];
    if (data['audioRecordings'] != null) {
      audioRecordings = List<Map<String, dynamic>>.from(data['audioRecordings'])
          .map((map) => AudioRecording.fromMap(map))
          .toList();
    }
    
    return JournalEntry(
      id: snapshot.id,
      imageUrl: data['imageUrl'] ?? '',
      additionalImages: List<String>.from(data['additionalImages'] ?? []),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      audioRecordings: audioRecordings.isEmpty ? null : audioRecordings,
      hasLocationData: data['hasLocationData'] ?? false,
      locationName: data['locationName'],
      location: data['location'],
      isBookmarked: data['isBookmarked'] ?? false,
      isLocked: data['isLocked'] ?? false,
    );
  }
  
  // For use with query snapshots
  factory JournalEntry.fromQueryDocumentSnapshot(QueryDocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    
    List<AudioRecording> audioRecordings = [];
    if (data['audioRecordings'] != null) {
      audioRecordings = List<Map<String, dynamic>>.from(data['audioRecordings'])
          .map((map) => AudioRecording.fromMap(map))
          .toList();
    }
    
    return JournalEntry(
      id: snapshot.id,
      imageUrl: data['imageUrl'] ?? '',
      additionalImages: List<String>.from(data['additionalImages'] ?? []),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      audioRecordings: audioRecordings.isEmpty ? null : audioRecordings,
      hasLocationData: data['hasLocationData'] ?? false,
      locationName: data['locationName'],
      location: data['location'],
      isBookmarked: data['isBookmarked'] ?? false,
      isLocked: data['isLocked'] ?? false,
    );
  }
}

class AudioRecording {
  final String id;
  final String duration; // Format: "MM:SS"
  final DateTime recordedAt;
  final String? title;
  final String? url;
  final String? locationName;

  AudioRecording({
    required this.id,
    required this.duration,
    required this.recordedAt,
    this.title,
    this.url,
    this.locationName,
  });

  // Convert AudioRecording to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'duration': duration,
      'recordedAt': recordedAt,
      'title': title,
      'url': url,
      'locationName': locationName,
    };
  }
  
  // Create an AudioRecording from a Map
  factory AudioRecording.fromMap(Map<String, dynamic> map) {
    return AudioRecording(
      id: map['id'] ?? '',
      duration: map['duration'] ?? '0:00',
      recordedAt: (map['recordedAt'] as Timestamp).toDate(),
      title: map['title'],
      url: map['url'],
      locationName: map['locationName'],
    );
  }
}
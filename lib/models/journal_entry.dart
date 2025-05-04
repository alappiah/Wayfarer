class JournalEntry {
  final String id;
  final String imageUrl; // Main cover image
  final List<String> additionalImages; // Multiple additional images
  final String title;
  final String description;
  final DateTime date;
  final List<AudioRecording>? audioRecordings; // Multiple audio recordings
  final bool hasLocationData;

  JournalEntry({
    required this.id,
    required this.imageUrl,
    this.additionalImages = const [],
    required this.title,
    required this.description,
    required this.date,
    this.audioRecordings,
    this.hasLocationData = false,
  });
}

class AudioRecording {
  final String id;
  final String duration; // Format: "MM:SS"
  final DateTime recordedAt;
  final String? title;
  final String? url; // Add this

  final String? locationName; // Add this field

  AudioRecording({
    required this.id,
    required this.duration,
    required this.recordedAt,
    this.title,
    this.url,
    this.locationName,
  });
}

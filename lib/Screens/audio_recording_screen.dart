import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioRecordingScreen extends StatefulWidget {
  const AudioRecordingScreen({Key? key}) : super(key: key);

  @override
  State<AudioRecordingScreen> createState() => _AudioRecordingScreenState();
}

class _AudioRecordingScreenState extends State<AudioRecordingScreen> {
  // Use the recorder instance correctly
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  bool _isPaused = false;
  bool _hasRecording = false;
  
  String? _recordingPath;
  String _recordId = const Uuid().v4();
  
  Duration _recordingDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  
  Timer? _recordingTimer;
  StreamSubscription<Duration>? _positionSubscription;
  
  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }
  
  Future<void> _initializeRecorder() async {
    final dir = await getApplicationDocumentsDirectory();
    _recordingPath = '${dir.path}/recordings/$_recordId.m4a';
    
    // Create the directory if it doesn't exist
    final recordingDir = Directory('${dir.path}/recordings');
    if (!await recordingDir.exists()) {
      await recordingDir.create(recursive: true);
    }
  }
  
  Future<void> _startRecording() async {
    try {
      // Check for permission
      if (await Permission.microphone.request().isGranted) {
        // Make sure the directory exists and path is valid
        if (_recordingPath == null) {
          await _initializeRecorder();
        }
        
        // Now we can safely use non-null recording path
        final path = _recordingPath!;
        
        // Make sure the recorder is initialized
        await _audioRecorder.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );
        
        // Start a timer to track recording duration
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() {
            _recordingDuration = _recordingDuration + const Duration(seconds: 1);
          });
        });
        
        setState(() {
          _isRecording = true;
          _isPaused = false;
          _hasRecording = false;
          _recordingDuration = Duration.zero;
        });
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }
  
  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pause();
      _recordingTimer?.cancel();
      
      setState(() {
        _isPaused = true;
      });
    } catch (e) {
      print('Error pausing recording: $e');
    }
  }
  
  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();
      
      // Resume the timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _recordingDuration = _recordingDuration + const Duration(seconds: 1);
        });
      });
      
      setState(() {
        _isPaused = false;
      });
    } catch (e) {
      print('Error resuming recording: $e');
    }
  }
  
  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _hasRecording = true;
      });
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }
  
  Future<void> _playRecording() async {
    try {
      if (_recordingPath != null) {
        // Setup position stream listener
        _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
          setState(() {
            _playbackPosition = position;
          });
        });
        
        // Setup completion listener
        _audioPlayer.onPlayerComplete.listen((_) {
          setState(() {
            _playbackPosition = Duration.zero;
          });
        });
        
        await _audioPlayer.play(DeviceFileSource(_recordingPath!));
      }
    } catch (e) {
      print('Error playing recording: $e');
    }
  }
  
  Future<void> _stopPlayback() async {
    try {
      await _audioPlayer.stop();
      _positionSubscription?.cancel();
      setState(() {
        _playbackPosition = Duration.zero;
      });
    } catch (e) {
      print('Error stopping playback: $e');
    }
  }
  
  void _saveRecording() {
    if (_recordingPath != null && _hasRecording) {
      Navigator.pop(context, {
        'id': _recordId,
        'filePath': _recordingPath,
        'durationSeconds': _recordingDuration.inSeconds,
        'durationFormatted': _formatDuration(_recordingDuration),
      });
    } else {
      Navigator.pop(context);
    }
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_hasRecording)
            TextButton(
              onPressed: _saveRecording,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Timer display
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Center(
                child: Text(
                  _formatDuration(_isRecording || _hasRecording ? _recordingDuration : _playbackPosition),
                  style: const TextStyle(
                    fontSize: 70,
                    color: Colors.white,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
            
            // Controls
            if (_hasRecording && !_isRecording)
              // Playback controls
              Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _playbackPosition.inSeconds > 0 ? Icons.stop : Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                      onPressed: _playbackPosition.inSeconds > 0 ? _stopPlayback : _playRecording,
                    ),
                    const SizedBox(width: 40),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        setState(() {
                          _hasRecording = false;
                          _recordingDuration = Duration.zero;
                        });
                      },
                    ),
                  ],
                ),
              )
            else
              // Recording controls
              Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      if (_isRecording) {
                        _stopRecording();
                      } else {
                        _startRecording();
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.grey.shade700,
                          width: 4,
                        ),
                      ),
                      child: _isRecording
                        ? const Icon(Icons.stop, color: Colors.white, size: 40)
                        : const SizedBox(),
                    ),
                  ),
                ),
              ),
            
            // Bottom progress bar
            Container(
              height: 4,
              width: double.infinity,
              color: Colors.grey.shade800,
              child: _isRecording || _hasRecording
                ? LinearProgressIndicator(
                    value: _hasRecording && !_isRecording && _recordingDuration.inSeconds > 0
                        ? _playbackPosition.inSeconds / _recordingDuration.inSeconds
                        : null,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : null,
            ),
          ],
        ),
      ),
    );
  }
}
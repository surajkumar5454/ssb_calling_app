import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/face_detection_service.dart';
import '../helpers/database_helper.dart';

class FaceSearchScreen extends StatefulWidget {
  @override
  _FaceSearchScreenState createState() => _FaceSearchScreenState();
}

class _FaceSearchScreenState extends State<FaceSearchScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _isSearching = false;
  Map<String, dynamic>? _matchedContact;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  Future<void> _captureAndSearch() async {
    if (_isSearching) return;

    try {
      setState(() {
        _isSearching = true;
        _matchedContact = null;
      });

      // Capture image
      final image = await _controller.takePicture();
      
      // Get all contacts with images
      // Note: You'll need to implement this method in DatabaseHelper
      final contacts = await _databaseHelper.getAllContactsWithImages();
      
      double highestSimilarity = 0.0;
      Map<String, dynamic>? bestMatch;

      // Compare with each contact's image
      for (var contact in contacts) {
        double similarity = await _faceDetectionService.compareFaces(
          image.path,
          contact['image_path'],
        );

        if (similarity > highestSimilarity && similarity > 0.7) { // Threshold of 70%
          highestSimilarity = similarity;
          bestMatch = contact;
        }
      }

      setState(() {
        _matchedContact = bestMatch;
        _isSearching = false;
      });

    } catch (e) {
      print('Error during face search: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Search'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Searching for matches...'),
                  ],
                ),
              ),
            ),
          if (_matchedContact != null)
            Expanded(
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Match Found!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Text('Name: ${_matchedContact!['name']}'),
                    Text('Rank: ${_matchedContact!['rank']}'),
                    Text('Unit: ${_matchedContact!['unit']}'),
                    // Add more contact details as needed
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSearching ? null : _captureAndSearch,
        child: Icon(_isSearching ? Icons.hourglass_empty : Icons.camera),
      ),
    );
  }
}

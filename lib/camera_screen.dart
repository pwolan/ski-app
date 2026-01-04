import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'video_preview_screen.dart';

class CameraScreen extends StatefulWidget {
  final MLModel model;

  const CameraScreen({super.key, required this.model});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isRecording = false;
  bool _isUploading = false;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _logger.e("No cameras available");
      return;
    }

    // Select the first camera (usually back camera)
    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
    );

    _initializeControllerFuture = _controller!.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _recordVideo() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (_isRecording) {
      // STOP RECORDING
      final file = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      await _uploadVideo(file);
    } else {
      // START RECORDING
      await _controller!.prepareForVideoRecording();
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    }
  }

  Future<void> _uploadVideo(XFile file) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final String fileName = 'videos/${DateTime.now().millisecondsSinceEpoch}.mp4';
      final Reference ref = FirebaseStorage.instance.ref().child(fileName);
      final File videoFile = File(file.path);

      _logger.i("Starting upload to $fileName...");

      final UploadTask uploadTask = ref.putFile(videoFile);

      // Optional: Listen to progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        _logger.d("Upload progress: ${(progress * 100).toStringAsFixed(2)}%");
      });

      await uploadTask.whenComplete(() => null);

      final String downloadUrl = await ref.getDownloadURL();
      _logger.i("Upload complete! URL: $downloadUrl");

      // Wait for Cloud Function to process and create document
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Wideo wysłane! Oczekiwanie na przetworzenie...')),
         );
      }

      String docId = fileName.split('/').last;

      // Poll or listener for document creation
      // Using snapshots().firstWhere simplifies waiting for existence
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('video_results')
          .doc(docId)
          .snapshots()
          .firstWhere((snapshot) => snapshot.exists && (snapshot.data() as Map<String, dynamic>).containsKey('frames'));

      if (mounted) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<List<double>> sequence = MLModel.parseFrames(data);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPreviewScreen(
              docId: docId,
              sequence: sequence,
              model: widget.model,
            ),
          ),
        );
      }

    } catch (e) {
      _logger.e("Error uploading/processing video: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nagrywanie Wideo')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                // Camera Preview
                Positioned.fill(
                  child: CameraPreview(_controller!),
                ),

                // Upload Indicator
                if (_isUploading)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            "Przetwarzanie...",
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          )
                        ],
                      ),
                    ),
                  ),

                // Record Button
                if (!_isUploading)
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FloatingActionButton.large(
                        backgroundColor: _isRecording ? Colors.red : Colors.white,
                        onPressed: _recordVideo,
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.circle,
                          color: _isRecording ? Colors.white : Colors.red,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

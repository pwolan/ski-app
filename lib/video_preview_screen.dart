import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'models.dart';

class VideoPreviewScreen extends StatefulWidget {
  final String docId;
  final List<List<double>> sequence;
  final MLModel model;

  const VideoPreviewScreen({
    super.key,
    required this.docId,
    required this.sequence,
    required this.model,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoadingFn = true;
  final Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final ref = FirebaseStorage.instance.ref().child('videos/${widget.docId}');
      final url = await ref.getDownloadURL();

      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: true,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        overlay: SkeletonOverlay(
          controller: _videoPlayerController!,
          sequence: widget.sequence,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      setState(() {
        _isLoadingFn = false;
      });
    } catch (e) {
      logger.e("Error initializing video: $e");
      setState(() {
        _isLoadingFn = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania wideo: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _runInference() async {
    _videoPlayerController?.pause();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Prepare data for model: Truncate to 12 features per frame
      List<List<double>> modelInput = widget.sequence.map((frame) {
        if (frame.length > 12) {
          return frame.sublist(0, 12);
        }
        return frame;
      }).toList();

      String result = await widget.model.runInferenceOnSequence(modelInput);

      if (mounted) {
        Navigator.of(context).pop();
        _showResultDialog(result);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd modelu: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
  }

  void _showResultDialog(String result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Wynik modelu"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.docId, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            Text(
              result,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Podgląd nagrania")),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Center(
              child: _isLoadingFn
                  ? const CircularProgressIndicator()
                  : _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                      ? Chewie(
                          controller: _chewieController!,
                        )
                      : const Text("Nie udało się załadować wideo."),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _runInference,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                icon: const Icon(Icons.analytics),
                label: const Text("Uruchom model", style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final List<List<double>> sequence;

  const SkeletonOverlay({super.key, required this.controller, required this.sequence});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return CustomPaint(
                painter: SkeletonPainter(
                  currentTime: controller.value.position,
                  totalDuration: controller.value.duration,
                  sequence: sequence,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
      ),
    );
  }
}

class SkeletonPainter extends CustomPainter {
  final Duration currentTime;
  final Duration totalDuration;
  final List<List<double>> sequence;

  SkeletonPainter({required this.currentTime, required this.totalDuration, required this.sequence});

  @override
  void paint(Canvas canvas, Size size) {
    if (totalDuration.inMilliseconds == 0 || sequence.isEmpty) return;

    final double progress = currentTime.inMilliseconds / totalDuration.inMilliseconds;
    int frameIndex = (progress * (sequence.length - 1)).round();
    
    if (frameIndex < 0) frameIndex = 0;
    if (frameIndex >= sequence.length) frameIndex = sequence.length - 1;

    final List<double> frameData = sequence[frameIndex];
    final Paint paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // frameData contains 34 floats -> 17 points (x, y)
    for (int i = 0; i < frameData.length - 1; i += 2) {
      if (i + 1 < frameData.length) {
        // Warning: Coordinates must be normalized 0..1 to work with * size
        double x = frameData[i];
        double y = frameData[i+1];
        
        canvas.drawCircle(Offset(x * size.width, y * size.height), 4.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime;
  }
}

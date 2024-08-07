import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';

class Compress extends StatefulWidget {
  final String? title;

  const Compress({super.key, this.title});

  @override
  State<Compress> createState() => _CompressState();
}

class _CompressState extends State<Compress> {
  String _outputPath = '';
  String originalSize = '';
  String compressedSize = '';
  double _progress = 0.0;
  bool _isCompressing = false;
  Subscription? _subscription;
  Future<void> _compressVideo() async {
    final picker = ImagePicker();
    var pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile == null) return;
    File file = File(pickedFile.path);

    // Get original file size
    int originalFileSize = file.lengthSync();
    originalSize = formatBytes(originalFileSize);

    log('FileSize Previous: $originalSize');

    // Set compression state
    setState(() {
      _isCompressing = true;
      _progress = 0.0;
    });

    // Listen to compression progress
    _subscription = VideoCompress.compressProgress$.subscribe((progress) {
      setState(() {
        _progress = progress / 100;
      });
    });

    await VideoCompress.setLogLevel(0);
    final MediaInfo? info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.LowQuality,
      deleteOrigin: false,
      includeAudio: true,
    );

    // Cancel the subscription
    _subscription?.unsubscribe();

    if (info == null || info.path == null) {
      log('Compression failed');
      setState(() {
        _isCompressing = false;
      });
      return;
    }

    // Get the output directory
    final directory = Directory('/storage/emulated/0/Download');
    final String outputPath =
        '${directory.path}/compressed_video${DateTime.now().millisecondsSinceEpoch}.mp4';

    // Copy the file to the output path
    final File outputFile = File(info.path!);
    final File savedFile = await outputFile.copy(outputPath);

    // Get compressed file size
    int compressedFileSize = savedFile.lengthSync();
    compressedSize = formatBytes(compressedFileSize);

    log('Compressed File Path: ${savedFile.path}');
    log('Compressed File Size: $compressedSize');

    setState(() {
      _outputPath = savedFile.path;
      _isCompressing = false;
    });
  }

  void _cancelCompression() {
    VideoCompress.cancelCompression();
    _subscription?.unsubscribe();
    setState(() {
      _isCompressing = false;
    });
  }

  String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  @override
  void dispose() {
    VideoCompress.cancelCompression();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Compressor'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isCompressing) ...[
              const Text('Compressing...'),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _cancelCompression,
                child: const Text('Cancel'),
              ),
            ] else ...[
              Text('Original Size: $originalSize'),
              Text('Compressed Size: $compressedSize'),
              Text('Compressed Video Path: $_outputPath'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _compressVideo,
                child: const Text('Compress Video'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

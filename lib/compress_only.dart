import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

class CompressOnly extends StatefulWidget {
  const CompressOnly({super.key});

  @override
  State<CompressOnly> createState() => _CompressOnlyState();
}

class _CompressOnlyState extends State<CompressOnly> {
  String _status = 'No video selected';
  XFile? _selectedVideo;
  File? _convertedVideo;
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _originalController;
  VideoPlayerController? _convertedController;
  MediaInfo? _mediaInfo;
  int? _originalFileSize;

  // @override
  // void initState() {
  //   super.initState();
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     if (_selectedVideo != null) {
  //       _initializeOriginalPlayer();
  //     }
  //   });
  // }

  Future<void> _selectVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        final File videoFile = File(video.path);
        _originalFileSize = await videoFile.length();
        setState(() {
          _selectedVideo = video;
          _status = 'Selected: ${video.name}';
          _convertedVideo = null;
          _mediaInfo = null;
        });
        _initializeOriginalPlayer();
      } else {
        setState(() {
          _status = 'No video selected';
          _selectedVideo = null;
          _convertedVideo = null;
          _mediaInfo = null;
          _originalFileSize = null;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _initializeOriginalPlayer() async {
    if (_selectedVideo != null) {
      _originalController =
          VideoPlayerController.file(File(_selectedVideo!.path));
      await _originalController!.initialize();
      setState(() {});
    }
  }

  Future<void> _initializeConvertedPlayer() async {
    if (_convertedVideo != null) {
      _convertedController = VideoPlayerController.file(_convertedVideo!);
      await _convertedController!.initialize();
      setState(() {});
    }
  }

  Future<void> _convertAndCompressVideo() async {
    if (_selectedVideo == null) {
      setState(() {
        _status = 'Please select a video first';
      });
      return;
    }

    setState(() {
      _status = 'Compressing...';
    });

    try {
      final info = await VideoCompress.compressVideo(
        _selectedVideo!.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 24,
      );

      if (info != null && info.path != null) {
        final String outputFileName =
            '${_selectedVideo!.name.split('.').first}_${DateTime.now().millisecondsSinceEpoch}_compressed.mp4';
        final String outputPath =
            '/storage/emulated/0/Download/$outputFileName';

        _convertedVideo = await File(info.path!).copy(outputPath);
        await File(info.path!).delete();

        _mediaInfo = info;

        await _initializeConvertedPlayer();

        setState(() {
          _status = 'Compression successful!\nOutput saved to: $outputPath';
        });
      } else {
        setState(() {
          _status = 'Compression failed: No output file generated';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error during compression: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _originalController?.dispose();
    _convertedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _selectVideo,
              child: const Text('Select Video from Gallery'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _convertAndCompressVideo,
              child: const Text('Compress Video'),
            ),
            const SizedBox(height: 20),
            Text(
              _status,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_originalController != null)
              SizedBox(
                width: 300,
                height: 200,
                child: _buildVideoPlayer(_originalController),
              ),
            const SizedBox(height: 20),
            if (_mediaInfo != null && _originalFileSize != null)
              Column(
                children: [
                  Text(
                      'Original Size: ${(_originalFileSize! / (1024 * 1024)).toStringAsFixed(2)} MB'),
                  Text(
                      'Compressed Size: ${(_mediaInfo!.filesize! / (1024 * 1024)).toStringAsFixed(2)} MB'),
                  Text(
                      'Compression Ratio: ${((_mediaInfo!.filesize! / _originalFileSize!) * 100).toStringAsFixed(2)}%'),
                  if (_mediaInfo!.duration != null)
                    Text(
                        'Duration: ${_mediaInfo!.duration!.toStringAsFixed(2)} seconds'),
                  if (_mediaInfo!.width != null)
                    Text('Width: ${_mediaInfo!.width}'),
                  if (_mediaInfo!.height != null)
                    Text('Height: ${_mediaInfo!.height}'),
                ],
              ),
            const SizedBox(height: 20),
            if (_convertedController != null)
              SizedBox(
                width: 300,
                height: 200,
                child: _buildVideoPlayer(_convertedController),
              ),
            const SizedBox(height: 20),
            if (_convertedVideo != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Compressed video path: ${_convertedVideo!.path}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(VideoPlayerController? controller) {
    if (controller != null && controller.value.isInitialized) {
      return Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                });
              },
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: Icon(
                    controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 50.0,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return const SizedBox(
        width: 300,
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
  }
}

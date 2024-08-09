import 'dart:io';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

class CompressAndConvert extends StatefulWidget {
  const CompressAndConvert({super.key});

  @override
  State<CompressAndConvert> createState() => _CompressAndConvertState();
}

class _CompressAndConvertState extends State<CompressAndConvert> {
  String _status = 'No video selected';
  XFile? _selectedVideo;
  File? _convertedVideo;
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _originalController;
  VideoPlayerController? _convertedController;
  MediaInfo? _mediaInfo;
  int? _originalFileSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedVideo != null) {
        _initializeOriginalPlayer();
      }
    });
  }

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
      _status = 'Converting and compressing...';
    });

    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String outputFileName =
          '${_selectedVideo!.name.split('.').first}_compressed.webm';
      final String outputPath = '${appDocDir.path}/$outputFileName';

      // FFmpeg command to convert to WebM and compress
      String ffmpegCommand =
          '-i ${_selectedVideo!.path} -c:v libvpx-vp9 -crf 30 -b:v 0 -b:a 128k -c:a libopus $outputPath';

      final session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        _convertedVideo = File(outputPath);

        final MediaInfo info = await VideoCompress.getMediaInfo(outputPath);
        _mediaInfo = info;

        await _initializeConvertedPlayer();

        setState(() {
          _status =
              'Conversion and compression successful!\nOutput saved to: $outputPath';
        });
      } else {
        setState(() {
          _status = 'Conversion and compression failed';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error during conversion and compression: ${e.toString()}';
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
    return Scaffold(
      body: SingleChildScrollView(
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
              if (_originalController != null &&
                  _originalController!.value.isInitialized)
                SizedBox(
                  width: 300,
                  height: 200,
                  child: VideoPlayer(_originalController!),
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
              if (_convertedController != null &&
                  _convertedController!.value.isInitialized)
                SizedBox(
                  width: 300,
                  height: 200,
                  child: VideoPlayer(_convertedController!),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_originalController != null &&
              _originalController!.value.isInitialized)
            FloatingActionButton(
              onPressed: () {
                setState(() {
                  _originalController!.value.isPlaying
                      ? _originalController!.pause()
                      : _originalController!.play();
                });
              },
              child: Icon(
                _originalController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            ),
          const SizedBox(width: 10),
          if (_convertedController != null &&
              _convertedController!.value.isInitialized)
            FloatingActionButton(
              onPressed: () {
                setState(() {
                  _convertedController!.value.isPlaying
                      ? _convertedController!.pause()
                      : _convertedController!.play();
                });
              },
              child: Icon(
                _convertedController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            ),
        ],
      ),
    );
  }
}

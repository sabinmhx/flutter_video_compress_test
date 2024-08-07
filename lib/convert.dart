import 'dart:io';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/log.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class Convert extends StatefulWidget {
  const Convert({super.key});

  @override
  State<Convert> createState() => _ConvertState();
}

class _ConvertState extends State<Convert> {
  final ImagePicker _picker = ImagePicker();
  XFile? _videoFile;
  String? _outputPath;
  bool _isConverting = false;
  String _conversionStatus = '';
  String _selectedFormat = 'mp4';

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _videoFile = video;
        _conversionStatus = 'Video selected: ${video.path}';
      });
    }
  }

  Future<void> _convertVideo() async {
    if (_videoFile == null) {
      setState(() {
        _conversionStatus = 'Please select a video first.';
      });
      return;
    }

    setState(() {
      _isConverting = true;
      _conversionStatus = 'Converting...';
    });

    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      _outputPath = '${appDocDir.path}/converted_video.$_selectedFormat';

      String ffmpegCommand;
      if (_selectedFormat == 'webp') {
        ffmpegCommand =
            '-i ${_videoFile!.path} -vf "fps=10,scale=320:-1:flags=lanczos" -c:v libwebp -lossless 0 -compression_level 6 -q:v 50 -loop 0 -preset picture -an -vsync 0 $_outputPath';
      } else {
        ffmpegCommand =
            '-i ${_videoFile!.path} -c:v libx264 -crf 23 -preset medium -c:a aac -b:a 128k $_outputPath';
      }

      setState(() {
        _conversionStatus += '\nExecuting command: $ffmpegCommand';
      });

      final session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();
      final output = await session.getOutput();
      final logs = await session.getLogs();

      setState(() {
        _conversionStatus += '\nFFmpeg output: $output';
        _conversionStatus += '\nFFmpeg logs:';
        for (Log log in logs) {
          _conversionStatus += '\n${log.getMessage()}';
        }
      });

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(_outputPath!);
        final inputFile = File(_videoFile!.path);
        final compressionRatio =
            (await outputFile.length()) / (await inputFile.length()) * 100;

        setState(() {
          _conversionStatus +=
              '\nVideo converted successfully to $_selectedFormat\n'
              'New path: $_outputPath\n'
              'Original size: ${inputFile.lengthSync()} bytes\n'
              'Converted size: ${outputFile.lengthSync()} bytes\n'
              'Compression ratio: ${compressionRatio.toStringAsFixed(2)}%';
        });
      } else if (ReturnCode.isCancel(returnCode)) {
        setState(() {
          _conversionStatus += '\nVideo conversion cancelled';
        });
      } else {
        setState(() {
          _conversionStatus +=
              '\nVideo conversion failed with return code: ${returnCode?.getValue()}';
        });
      }
    } catch (e) {
      setState(() {
        _conversionStatus += '\nError during video conversion: $e';
      });
    } finally {
      setState(() {
        _isConverting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Converter'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _pickVideo,
              child: const Text('Select Video'),
            ),
            const SizedBox(height: 16),
            Text(_videoFile?.path ?? 'No video selected'),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedFormat,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedFormat = newValue!;
                });
              },
              items: <String>['mp4', 'webp']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isConverting ? null : _convertVideo,
              child: const Text('Convert Video'),
            ),
            const SizedBox(height: 16),
            Text(_conversionStatus),
          ],
        ),
      ),
    );
  }
}

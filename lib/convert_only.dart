import 'dart:developer';
import 'dart:io';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter/log.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ConvertOnly extends StatefulWidget {
  const ConvertOnly({super.key});

  @override
  State<ConvertOnly> createState() => _ConvertOnlyState();
}

class _ConvertOnlyState extends State<ConvertOnly> {
  String _status = 'No video selected';
  XFile? _selectedVideo;
  final ImagePicker _picker = ImagePicker();

  Future<void> _selectVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _selectedVideo = video;
          _status = 'Selected: ${video.name}';
        });
      } else {
        setState(() {
          _status = 'No video selected';
          _selectedVideo = null;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _convertToWebM() async {
    if (_selectedVideo == null) {
      setState(() {
        _status = 'Please select a video first';
      });
      return;
    }

    setState(() {
      _status = 'Converting...';
    });

    String inputPath = _selectedVideo!.path;

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String outputFileName = '${_selectedVideo!.name.split('.').first}.webm';
    String outputPath = '${appDocDir.path}/$outputFileName';

    String ffmpegCommand =
        '-i "$inputPath" -c:v libvpx-vp9 -b:v 0 -b:a 128k realtime -cpu-used 8 -c:a libopus "$outputPath"';

    try {
      FFmpegSession session = await FFmpegKit.execute(ffmpegCommand);

      ReturnCode? returnCode = await session.getReturnCode();
      String? output = await session.getOutput();

      if (ReturnCode.isSuccess(returnCode)) {
        setState(() {
          _status = 'Conversion successful!\nOutput saved to: $outputPath';
        });
      } else {
        String? failStackTrace = await session.getFailStackTrace();
        List<Log> logs = await session.getLogs();
        String logOutput = logs.map((log) => log.getMessage()).join('\n');

        setState(() {
          _status = 'Conversion failed.\n'
              'Return code: ${returnCode?.getValue()}\n'
              'Failure stack trace: $failStackTrace\n'
              'Command output: $output\n'
              'Logs:\n$logOutput';
        });

        log('FFmpeg command: $ffmpegCommand');
        log('Input file exists: ${await File(inputPath).exists()}');
        log('Input file size: ${await File(inputPath).length()} bytes');
        log('Output directory exists: ${await Directory(appDocDir.path).exists()}');
        log('Free space in output directory: ${await _getFreeDiskSpace(appDocDir.path)} bytes');
      }
    } catch (e) {
      setState(() {
        _status = 'Error during conversion: ${e.toString()}';
      });
    }
  }

  Future<int> _getFreeDiskSpace(String path) async {
    try {
      final result = await Process.run('df', ['-k', path]);
      final lines = result.stdout.split('\n');
      if (lines.length > 1) {
        final values = lines[1].split(RegExp(r'\s+'));
        if (values.length > 3) {
          return int.parse(values[3]) * 1024; // Convert KB to bytes
        }
      }
    } catch (e) {
      log('Error getting free disk space: $e');
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () => _selectVideo(),
              child: const Text('Select Video from Gallery'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _convertToWebM,
              child: const Text('Convert to WebM'),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _status,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

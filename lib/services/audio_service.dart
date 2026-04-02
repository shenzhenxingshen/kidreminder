import 'dart:io';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioService {
  AudioService();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  /// 将 asset 音频复制到应用文档目录，返回本地路径
  static Future<String> copyAssetAudio(String assetName) async {
    final dir = await getApplicationDocumentsDirectory();
    final localPath = p.join(dir.path, assetName);
    final file = File(localPath);
    if (!await file.exists()) {
      final data = await rootBundle.load('assets/audio/$assetName');
      await file.writeAsBytes(data.buffer.asUint8List());
    }
    return localPath;
  }

  Future<bool> checkPermission() async {
    return _recorder.hasPermission();
  }

  Future<void> startRecording({required String fileName}) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, fileName);
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
  }

  Future<String?> stopRecording() async {
    return _recorder.stop();
  }

  Future<void> play(String path) async {
    await _player.stop();
    await _player.setFilePath(path);
    await _player.play();
  }

  Future<void> stopPlay() async {
    await _player.stop();
  }

  Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
  }
}
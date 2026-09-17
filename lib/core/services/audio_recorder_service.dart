import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// ============================================================
/// خدمة التسجيل الصوتي
/// تُسجّل بصيغة AAC/M4A (خفيفة وجودة جيدة للصوت البشري)
/// ============================================================
class AudioRecorderService {
  // ============================================
  // === Singleton ===
  // ============================================
  AudioRecorderService._internal();
  static final AudioRecorderService instance =
      AudioRecorderService._internal();

  final AudioRecorder _recorder = AudioRecorder();

  String? _currentPath;
  DateTime? _startedAt;
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  String? get currentPath => _currentPath;

  // ============================================
  // === الأذونات ===
  // ============================================

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('[Recorder] permission error: $e');
      return false;
    }
  }

  // ============================================
  // === بدء التسجيل ===
  // ============================================

  Future<String?> start() async {
    try {
      // أوقف أي تسجيل جارٍ
      if (_isRecording) {
        await _recorder.stop();
      }

      // تحقق من الإذن
      final ok = await _recorder.hasPermission();
      if (!ok) {
        debugPrint('[Recorder] No permission');
        return null;
      }

      // مجلد الصوت
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory(p.join(dir.path, 'audio'));
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      // اسم الملف
      final fileName =
          'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentPath = p.join(audioDir.path, fileName);
      _startedAt = DateTime.now();

      // إعدادات التسجيل (مناسبة للصوت البشري)
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 48000, // 48 kbps
        sampleRate: 16000, // 16 kHz (يكفي للصوت)
        numChannels: 1, // mono
      );

      await _recorder.start(config, path: _currentPath!);
      _isRecording = true;

      debugPrint('[Recorder] Started: $_currentPath');
      return _currentPath;
    } catch (e) {
      debugPrint('[Recorder] start error: $e');
      _reset();
      return null;
    }
  }

  // ============================================
  // === إيقاف التسجيل (مع الحفظ) ===
  // ============================================

  Future<RecordingResult?> stop() async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();
      final started = _startedAt;
      _isRecording = false;
      _startedAt = null;

      if (path == null || started == null) {
        _reset();
        return null;
      }

      final durationMs = DateTime.now().difference(started).inMilliseconds;

      // تحقق من وجود الملف
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('[Recorder] File not found after stop');
        _reset();
        return null;
      }

      final size = await file.length();

      // إذا كان التسجيل قصيرًا جدًا (< 1 ثانية) → تجاهل
      if (durationMs < 1000 || size < 1000) {
        debugPrint('[Recorder] Too short — discarding');
        await file.delete();
        _reset();
        return null;
      }

      debugPrint(
        '[Recorder] Stopped: $path '
        '(${durationMs}ms, ${size}B)',
      );

      _currentPath = null;

      return RecordingResult(
        path: path,
        durationMs: durationMs,
        sizeBytes: size,
      );
    } catch (e) {
      debugPrint('[Recorder] stop error: $e');
      _reset();
      return null;
    }
  }

  // ============================================
  // === إلغاء التسجيل ===
  // ============================================

  Future<void> cancel() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
      }
      _isRecording = false;

      // احذف الملف
      if (_currentPath != null) {
        final file = File(_currentPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('[Recorder] cancel error: $e');
    } finally {
      _reset();
    }
  }

  // ============================================
  // === المستوى الصوتي (للتغذية البصرية) ===
  // ============================================

  Stream<Amplitude> getAmplitudeStream() {
    return _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 150));
  }

  // ============================================
  // === أدوات داخلية ===
  // ============================================

  void _reset() {
    _currentPath = null;
    _startedAt = null;
    _isRecording = false;
  }

  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {}
  }
}

// ============================================================
// === نموذج نتيجة التسجيل ===
// ============================================================
class RecordingResult {
  final String path;
  final int durationMs;
  final int sizeBytes;

  const RecordingResult({
    required this.path,
    required this.durationMs,
    required this.sizeBytes,
  });

  String get formattedDuration {
    final s = (durationMs / 1000).round();
    final m = s ~/ 60;
    final rem = s % 60;
    return '$m:${rem.toString().padLeft(2, '0')}';
  }
}

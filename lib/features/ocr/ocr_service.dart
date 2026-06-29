import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class OcrResult {
  final double? suggestedAmount;
  final DateTime? suggestedDateTime;
  final List<double> candidates;
  final String rawText;

  const OcrResult({
    this.suggestedAmount,
    this.suggestedDateTime,
    required this.candidates,
    required this.rawText,
  });
}

class OcrService {
  static final _picker = ImagePicker();
  static final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // Prices always have exactly 2 decimal digits — eliminates op numbers, dates, phones
  static final _priceRegex = RegExp(r'\d{1,3}(?:[.,]\d{3})*[.,]\d{2}(?!\d)');

  static Future<OcrResult?> scanFromCamera() => _scan(ImageSource.camera);
  static Future<OcrResult?> scanFromGallery() => _scan(ImageSource.gallery);

  static Future<OcrResult?> _scan(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (photo == null) return null;

    final inputImage = InputImage.fromFile(File(photo.path));
    final RecognizedText recognized = await _recognizer.processImage(inputImage);

    final rawText = recognized.text;
    // Remove fill characters (* # -) used to pad amounts on receipts (e.g. ****188.00)
    final cleanText = rawText.replaceAll(RegExp(r'[*#]{2,}'), '');
    final candidates = _extractCandidates(cleanText);
    final suggested = _suggestTotal(cleanText, candidates);
    final dateTime = _extractDateTime(rawText);

    return OcrResult(
      suggestedAmount: suggested,
      suggestedDateTime: dateTime,
      candidates: candidates,
      rawText: rawText,
    );
  }

  // ── Amount extraction ─────────────────────────────────────────────────────

  static List<double> _extractCandidates(String text) {
    final seen = <String>{};
    final candidates = <double>[];

    for (final match in _priceRegex.allMatches(text)) {
      final value = _parsePrice(match.group(0)!);
      if (value != null && value > 0 && value < 100000) {
        final key = value.toStringAsFixed(2);
        if (!seen.contains(key)) {
          seen.add(key);
          candidates.add(value);
        }
      }
    }

    candidates.sort((a, b) => b.compareTo(a));
    return candidates.take(6).toList();
  }

  static double? _suggestTotal(String text, List<double> candidates) {
    if (candidates.isEmpty) return null;

    // Receipts always place the payable total LAST.
    // Collect every price in document order and return the last one.
    // This beats keyword matching which breaks on OCR artifacts and masked chars.
    final allInOrder = <double>[];
    for (final match in _priceRegex.allMatches(text)) {
      final n = _parsePrice(match.group(0)!);
      if (n != null && n > 0 && n < 100000) allInOrder.add(n);
    }

    return allInOrder.lastOrNull ?? candidates.firstOrNull;
  }

  static double? _parsePrice(String raw) {
    if (raw.contains(',') && raw.contains('.')) {
      final String normalized;
      if (raw.lastIndexOf(',') > raw.lastIndexOf('.')) {
        normalized = raw.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = raw.replaceAll(',', '');
      }
      return double.tryParse(normalized);
    }
    if (raw.contains(',')) {
      final parts = raw.split(',');
      if (parts.last.length == 2) {
        return double.tryParse(raw.replaceAll(',', '.'));
      }
      return double.tryParse(raw.replaceAll(',', ''));
    }
    return double.tryParse(raw);
  }

  // ── DateTime extraction ───────────────────────────────────────────────────

  static DateTime? _extractDateTime(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();

    DateTime? date;
    TimeOfDay? time;

    // 1. Look for FECHA/DATE keyword line first (highest confidence)
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('fecha') || lower.contains('date') || lower.contains('emision')) {
        date ??= _parseDate(line);
        time ??= _parseTime(line);
      }
      if (lower.contains('hora') || lower.contains('hour')) {
        time ??= _parseTime(line);
        date ??= _parseDate(line);
      }
    }

    // 2. Fallback: scan all lines for dates
    if (date == null) {
      for (final line in lines) {
        date = _parseDate(line);
        if (date != null) break;
      }
    }

    // 3. Fallback: scan all lines for time (skip lines that clearly have no time)
    if (time == null) {
      for (final line in lines) {
        time = _parseTime(line);
        if (time != null) break;
      }
    }

    if (date == null) return null;

    return DateTime(
      date.year, date.month, date.day,
      time?.hour ?? 0, time?.minute ?? 0,
    );
  }

  // Parses DD/MM/YY, DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD
  static DateTime? _parseDate(String text) {
    // DD/MM/YY or DD/MM/YYYY
    final slash = RegExp(r'\b(\d{1,2})/(\d{1,2})/(\d{2,4})\b').firstMatch(text);
    if (slash != null) {
      final d = int.tryParse(slash.group(1)!);
      final m = int.tryParse(slash.group(2)!);
      int? y = int.tryParse(slash.group(3)!);
      if (d != null && m != null && y != null && d >= 1 && d <= 31 && m >= 1 && m <= 12) {
        if (y < 100) y += 2000;
        try { return DateTime(y, m, d); } catch (_) {}
      }
    }

    // DD-MM-YYYY or YYYY-MM-DD
    final dash = RegExp(r'\b(\d{1,4})-(\d{1,2})-(\d{2,4})\b').firstMatch(text);
    if (dash != null) {
      final a = int.tryParse(dash.group(1)!);
      final b = int.tryParse(dash.group(2)!);
      int? c = int.tryParse(dash.group(3)!);
      if (a != null && b != null && c != null) {
        // Detect YYYY-MM-DD vs DD-MM-YYYY
        if (a > 31) {
          // YYYY-MM-DD
          try { return DateTime(a, b, c); } catch (_) {}
        } else if (c >= 1000) {
          // DD-MM-YYYY (Peruvian)
          try { return DateTime(c, b, a); } catch (_) {}
        } else {
          int year = c < 100 ? c + 2000 : c;
          try { return DateTime(year, b, a); } catch (_) {}
        }
      }
    }

    return null;
  }

  // Parses HH:MM or HH:MM:SS
  static TimeOfDay? _parseTime(String text) {
    final match = RegExp(r'\b(\d{1,2}):(\d{2})(?::\d{2})?\b').firstMatch(text);
    if (match != null) {
      final h = int.tryParse(match.group(1)!);
      final m = int.tryParse(match.group(2)!);
      if (h != null && m != null && h < 24 && m < 60) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return null;
  }

  static void dispose() => _recognizer.close();
}

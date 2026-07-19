import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'storage_service.dart';
import 'notification_service.dart';

/// Service that generates an end-of-day AI health summary using:
///   1. Today's ECG recordings (from StorageService)
///   2. Today's ML inference results (from StorageService)
///   3. Google Gemini to produce a human-readable health narrative
///
/// Call [checkAndSendDailySummary] once per app launch.
/// The service prevents duplicate notifications by storing the last
/// summary date in preferences.
class AiSummaryService {
  final StorageService  _storageService;
  final NotificationService _notificationService;

  static const String _geminiApiKey = 'AQ.Ab8RN6JIJX7tb9rkbpW-bKK4-onOXK25U4XtIj9LIOvu4e7Ulg';
  static const String _model = 'gemini-1.5-flash';

  AiSummaryService(this._storageService, this._notificationService);

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Checks if a summary has already been sent today; if not, generates and
  /// fires one. Safe to call multiple times — idempotent within the same day.
  Future<void> checkAndSendDailySummary() async {
    try {
      final today     = _todayString();
      final lastSent  = _storageService.getLastDailySummaryDate();
      if (lastSent == today) return; // already sent today

      // Only send if there is at least some data to summarize
      final recordings = _storageService.getECGRecordings();
      final inferenceResults = _storageService.getTodayInferenceResults();

      final todayRecordings = recordings.where((r) {
        final now = DateTime.now();
        return r.recordedAt.year  == now.year &&
               r.recordedAt.month == now.month &&
               r.recordedAt.day   == now.day;
      }).toList();

      if (todayRecordings.isEmpty && inferenceResults.isEmpty) return;

      final summary = await generateDailySummary(
        recordings: todayRecordings.map((r) => {
          'deviceName'     : r.deviceName,
          'durationSeconds': r.durationSeconds,
          'heartRate'      : r.getHeartRate(),
          'quality'        : r.healthMetrics['quality'] ?? 'N/A',
          'recordedAt'     : r.getFormattedDate(),
        }).toList(),
        inferenceResults: inferenceResults,
      );

      await _notificationService.showDailyHealthSummary(summaryText: summary);
      await _storageService.setLastDailySummaryDate(today);
      debugPrint('[AiSummaryService] Daily summary sent: $summary');
    } catch (e) {
      debugPrint('[AiSummaryService] Failed to send daily summary: $e');
    }
  }

  /// Generate a daily health summary string from ECG recordings and inference
  /// results. Uses Gemini to produce a concise, friendly health narrative.
  Future<String> generateDailySummary({
    required List<Map<String, dynamic>> recordings,
    required List<Map<String, dynamic>> inferenceResults,
  }) async {
    // Build data context for Gemini
    final recordingCount    = recordings.length;
    final anomalyCount      = inferenceResults.where((r) => r['isAbnormal'] == true).length;
    final normalCount       = inferenceResults.where((r) => r['isAbnormal'] == false).length;
    final labels            = inferenceResults.map((r) => r['label'] as String).toList();
    final uniqueAnomalies   = labels.where((l) => l != 'Normal').toSet().toList();

    // Average heart rate from recordings
    final heartRates = recordings
        .map((r) => r['heartRate'] as int? ?? 0)
        .where((hr) => hr > 0)
        .toList();
    final avgHR = heartRates.isNotEmpty
        ? (heartRates.reduce((a, b) => a + b) / heartRates.length).round()
        : 0;

    // Fallback summary in case Gemini call fails
    String fallbackSummary = recordingCount == 0
        ? 'No ECG recordings today.'
        : '$recordingCount ECG recording${recordingCount > 1 ? 's' : ''} today. '
          '${anomalyCount > 0 ? "$anomalyCount anomaly${anomalyCount > 1 ? 'ies' : ''} detected: ${uniqueAnomalies.join(', ')}. Please consult a doctor." : 'All readings appear normal.'}';

    try {
      final model = GenerativeModel(model: _model, apiKey: _geminiApiKey);

      final prompt = '''
You are a friendly cardiac personal health service assistant for the IntelliWave app. 
Generate a concise (2-3 sentence) daily health summary for a user based on their ECG data.
Keep the tone warm, informative, and reassuring. End with a brief recommendation.

Data for today:
- ECG recordings taken: $recordingCount
- Average heart rate: ${avgHR > 0 ? '$avgHR bpm' : 'not measured'}
- AI analysis windows — Normal: $normalCount, Abnormal: $anomalyCount
- Anomaly types detected: ${uniqueAnomalies.isEmpty ? 'none' : uniqueAnomalies.join(', ')}

Write ONLY the summary text (no headings, no bullet points). Maximum 180 characters for notification.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';
      if (text.isNotEmpty) return text.length > 200 ? '${text.substring(0, 197)}...' : text;
    } catch (e) {
      debugPrint('[AiSummaryService] Gemini summary error: $e');
    }

    return fallbackSummary;
  }

  /// Generate a Gemini-powered summary for the AI bot "Today's Summary" feature.
  /// Returns a longer, richer narrative suitable for in-app display.
  Future<String> generateChatSummary({
    required List<Map<String, dynamic>> recordings,
    required List<Map<String, dynamic>> inferenceResults,
  }) async {
    final recordingCount  = recordings.length;
    final anomalyCount    = inferenceResults.where((r) => r['isAbnormal'] == true).length;
    final labels          = inferenceResults.map((r) => r['label'] as String).toList();
    final uniqueAnomalies = labels.where((l) => l != 'Normal').toSet().toList();

    final heartRates = recordings
        .map((r) => r['heartRate'] as int? ?? 0)
        .where((hr) => hr > 0)
        .toList();
    final avgHR = heartRates.isNotEmpty
        ? (heartRates.reduce((a, b) => a + b) / heartRates.length).round()
        : 0;

    final fallback = recordingCount == 0
        ? "You haven't taken any ECG recordings today. Start recording on the Dashboard to get your daily health insights! 💙"
        : "Today you completed $recordingCount ECG recording${recordingCount > 1 ? 's' : ''}."
          "${avgHR > 0 ? ' Average heart rate: $avgHR bpm.' : ''}"
          " ${anomalyCount == 0 ? 'All AI analysis windows came back Normal ✅ — great news!' : 'AI detected $anomalyCount anomaly window${anomalyCount > 1 ? 's' : ''} (${uniqueAnomalies.join(', ')}) ⚠️ — please consult your doctor.'}";

    try {
      final model = GenerativeModel(model: _model, apiKey: _geminiApiKey);
      final prompt = '''
You are a friendly cardiac personal health service assistant in the IntelliWave mobile app.
Provide a detailed but concise daily ECG health summary for the user (4-6 sentences).
Use plain language, include emojis where appropriate, and end with a personalized tip.

Today's data:
- ECG recordings: $recordingCount
- Average heart rate: ${avgHR > 0 ? '$avgHR bpm' : 'not measured'}
- AI windows analyzed — Normal: ${labels.where((l) => l == 'Normal').length}, Abnormal: $anomalyCount
- Anomalies: ${uniqueAnomalies.isEmpty ? 'none' : uniqueAnomalies.join(', ')}

Write a friendly paragraph. Do not use markdown headings or bullet lists.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';
      if (text.isNotEmpty) return text;
    } catch (e) {
      debugPrint('[AiSummaryService] Gemini chat summary error: $e');
    }

    return fallback;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

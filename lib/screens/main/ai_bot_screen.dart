import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../constants/app_theme.dart';
import '../../widgets/app_bar_profile_avatar.dart';
import '../../providers/ecg_provider.dart';
import '../../providers/bluetooth_provider.dart';
import '../../utils/service_locator.dart';

class AIBotScreen extends StatefulWidget {
  final bool isActive;
  const AIBotScreen({super.key, this.isActive = true});

  @override
  State<AIBotScreen> createState() => _AIBotScreenState();
}

class _AIBotScreenState extends State<AIBotScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  late String _sessionId;

  // Gemini model
  static const String _geminiApiKey =
      'AQ.Ab8RN6JIJX7tb9rkbpW-bKK4-onOXK25U4XtIj9LIOvu4e7Ulg';
  GenerativeModel? _geminiModel;
  ChatSession? _chatSession;

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4();
    _initGemini();
    _addBotMessage(
      'Hello! I\'m your IntelIWave Personal Health Service Assistant 🩺\n\n'
      'I can help you understand your ECG data, explain AI analysis results, '
      'give you a daily health summary, and answer questions about heart health. '
      'How can I help you today?',
    );
  }

  void _initGemini() {
    try {
      _geminiModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _geminiApiKey,
        systemInstruction: Content.system(
          'You are a friendly, knowledgeable cardiac health and personal health service assistant for the IntelIWave ECG monitoring app. '
          'Your role is to help users understand their ECG data, explain AI analysis results, '
          'provide heart health education, and give daily summaries. '
          'Always remind users to consult a doctor for medical advice. '
          'Keep responses concise (under 200 words) and use emojis sparingly to be friendly. '
          'You know about ECG terminology: P-wave, QRS complex, T-wave, heart rate, arrhythmias, '
          'NORM (Normal Sinus Rhythm), MI (Myocardial Infarction), STTC (ST/T Segment Change), CD (Conduction Disturbance), HYP (Hypertrophy).',
        ),
      );
      _chatSession = _geminiModel!.startChat();
    } catch (e) {
      debugPrint('[AIBotScreen] Gemini init failed: $e');
    }
  }

  void _initGeminiWithHistory() {
    try {
      _geminiModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _geminiApiKey,
        systemInstruction: Content.system(
          'You are a friendly, knowledgeable cardiac health and personal health service assistant for the IntelIWave ECG monitoring app. '
          'Your role is to help users understand their ECG data, explain AI analysis results, '
          'provide heart health education, and give daily summaries. '
          'Always remind users to consult a doctor for medical advice. '
          'Keep responses concise (under 200 words) and use emojis sparingly to be friendly. '
          'You know about ECG terminology: P-wave, QRS complex, T-wave, heart rate, arrhythmias, '
          'NORM (Normal Sinus Rhythm), MI (Myocardial Infarction), STTC (ST/T Segment Change), CD (Conduction Disturbance), HYP (Hypertrophy).',
        ),
      );

      // Convert messages to Content history for Gemini
      final history = <Content>[];
      for (final msg in _messages) {
        history.add(Content(
          msg.isUser ? 'user' : 'model',
          [TextPart(msg.text)],
        ));
      }

      _chatSession = _geminiModel!.startChat(history: history);
    } catch (e) {
      debugPrint('[AIBotScreen] Gemini init with history failed: $e');
    }
  }

  @override
  void didUpdateWidget(covariant AIBotScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // User navigated away from the AI Chat tab
    if (oldWidget.isActive && !widget.isActive) {
      _saveCurrentSession();
    }

    // User navigated back to the AI Chat tab
    if (!oldWidget.isActive && widget.isActive) {
      _startNewChat();
    }
  }

  @override
  void dispose() {
    _saveCurrentSession();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Session Management ──────────────────────────────────────────────────────

  void _startNewChat() {
    // Only generate a new ID if current has messages
    final hasUserMsg = _messages.any((m) => m.isUser);
    if (hasUserMsg) {
      _saveCurrentSession();
    }

    _sessionId = const Uuid().v4();

    setState(() {
      _messages.clear();
      _isTyping = false;
      _messageController.clear();
      _initGemini();
      _addBotMessage(
        'Hello! I\'m your IntelIWave Personal Health Service Assistant 🩺\n\n'
        'I can help you understand your ECG data, explain AI analysis results, '
        'give you a daily health summary, and answer questions about heart health. '
        'How can I help you today?',
      );
    });
  }

  void _saveCurrentSession() {
    final hasUserMsg = _messages.any((m) => m.isUser);
    if (!hasUserMsg) return;

    final savedChats = storageService.getSavedChats();

    // Use the first user message as the title snippet
    final firstUserMsg = _messages.firstWhere((m) => m.isUser).text;
    final snippet = firstUserMsg.length > 30 ? '${firstUserMsg.substring(0, 27)}...' : firstUserMsg;
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(now);
    final title = 'Chat: "$snippet" ($dateStr)';

    final sessionMap = {
      'id': _sessionId,
      'title': title,
      'lastActive': now.toIso8601String(),
      'messages': _messages.map((m) => {
        'text': m.text,
        'isUser': m.isUser,
        'time': m.time.toIso8601String(),
        'isAnalysis': m.isAnalysis,
        'isError': m.isError,
      }).toList(),
    };

    final idx = savedChats.indexWhere((c) => c['id'] == _sessionId);
    if (idx != -1) {
      savedChats[idx] = sessionMap;
    } else {
      savedChats.insert(0, sessionMap);
    }

    // Keep only last 50 chats
    if (savedChats.length > 50) {
      savedChats.removeRange(50, savedChats.length);
    }

    storageService.saveChats(savedChats);
    debugPrint('[AIBotScreen] Saved chat session: $_sessionId');
  }

  void _loadPastChat(Map<String, dynamic> chatData) {
    // Save current before loading new one
    _saveCurrentSession();

    _sessionId = chatData['id'] as String;
    final List<dynamic> rawMsgs = chatData['messages'] as List;

    setState(() {
      _messages.clear();
      _isTyping = false;
      _messageController.clear();

      for (final item in rawMsgs) {
        _messages.add(_ChatMessage(
          text: item['text'] as String,
          isUser: item['isUser'] as bool,
          time: DateTime.parse(item['time'] as String),
          isAnalysis: item['isAnalysis'] as bool? ?? false,
          isError: item['isError'] as bool? ?? false,
        ));
      }

      _initGeminiWithHistory();
    });

    _scrollToBottom();
  }

  void _deleteChatSession(String id) {
    final savedChats = storageService.getSavedChats();
    savedChats.removeWhere((c) => c['id'] == id);
    storageService.saveChats(savedChats);

    // If we deleted the active session, start a new one
    if (id == _sessionId) {
      _startNewChat();
    }
  }

  // ── Bot Layout Helpers ──────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addBotMessage(String text, {bool isAnalysis = false, bool isError = false}) {
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: false,
        time: DateTime.now(),
        isAnalysis: isAnalysis,
        isError: isError,
      ));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        time: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  // ── Gemini Response ──────────────────────────────────────────────────────────

  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty || _isTyping) return;

    final lower = text.toLowerCase();
    final btProvider = Provider.of<BluetoothProvider>(context, listen: false);
    final isConnected = btProvider.isConnected;
    final isEcgReportQuestion = lower.contains('current ecg') ||
        lower.contains('ecg report') ||
        lower.contains('current report') ||
        lower.contains('live ecg') ||
        lower.contains('live') ||
        lower.contains('waveform') ||
        lower.contains('realtime') ||
        lower.contains('real-time');

    if (isEcgReportQuestion && !isConnected) {
      _addUserMessage(text);
      _messageController.clear();
      _addBotMessage('device not connected');
      return;
    }

    _addUserMessage(text);
    _messageController.clear();
    setState(() => _isTyping = true);

    try {
      if (_isSummaryRequest(lower)) {
        await _handleSummaryRequest();
      } else if (_isAnalysisRequest(lower)) {
        await _handleAnalysisRequest();
      } else {
        await _handleGeminiRequest(text);
      }
    } catch (e) {
      _addBotMessage(
        'Sorry, I encountered an error. Please check your connection and try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  bool _isSummaryRequest(String lower) =>
      lower.contains('summary') ||
      lower.contains('today') ||
      lower.contains('daily') ||
      lower.contains('this day') ||
      lower.contains('today\'s');

  bool _isAnalysisRequest(String lower) =>
      lower.contains('latest analysis') ||
      lower.contains('last result') ||
      lower.contains('ai result') ||
      lower.contains('my ecg result') ||
      lower.contains('latest ecg');

  Future<void> _handleSummaryRequest() async {
    final recordings = storageService.getECGRecordings();
    final inferenceResults = storageService.getTodayInferenceResults();

    final now = DateTime.now();
    final todayRecordings = recordings.where((r) =>
        r.recordedAt.year  == now.year &&
        r.recordedAt.month == now.month &&
        r.recordedAt.day   == now.day).toList();

    final summary = await aiSummaryService.generateChatSummary(
      recordings: todayRecordings.map((r) => {
        'deviceName'     : r.deviceName,
        'durationSeconds': r.durationSeconds,
        'heartRate'      : r.getHeartRate(),
        'quality'        : r.healthMetrics['quality'] ?? 'N/A',
      }).toList(),
      inferenceResults: inferenceResults,
    );

    _addBotMessage(summary, isAnalysis: true);
  }

  Future<void> _handleAnalysisRequest() async {
    final ecgProvider = Provider.of<ECGProvider>(context, listen: false);
    final latest = ecgProvider.latestInferenceResult;

    if (latest == null) {
      _addBotMessage(
        'No AI analysis has been performed yet in this session. '
        'Connect your ECG device to start live monitoring, or go to '
        'ECG Recordings and tap "Analyze with AI" on a saved recording. 📊',
      );
      return;
    }

    if (latest.isError) {
      _addBotMessage(
        'The last AI analysis encountered an error: ${latest.errorMessage}',
        isError: true,
      );
      return;
    }

    final statusIcon = latest.isAbnormal ? '⚠️' : '✅';
    final confidencePct = (latest.confidence * 100).toStringAsFixed(1);

    final explanation = await _askGemini(
      'The user\'s ECG was classified as "${latest.label}" with $confidencePct% confidence. '
      'Please explain what this means in simple terms and what they should do next.',
    );

    _addBotMessage(
      '$statusIcon Latest AI Result: ${latest.label} ($confidencePct%)\n\n$explanation',
      isAnalysis: true,
    );
  }

  Future<void> _handleGeminiRequest(String userText) async {
    final context = _buildEcgContext();
    final enrichedPrompt = context.isNotEmpty
        ? '$userText\n\n[User context: $context]'
        : userText;

    final reply = await _askGemini(enrichedPrompt);
    _addBotMessage(reply);
  }

  Future<String> _askGemini(String prompt) async {
    if (_chatSession == null) {
      return _localFallback(prompt);
    }
    try {
      final response = await _chatSession!.sendMessage(Content.text(prompt));
      return response.text?.trim() ?? _localFallback(prompt);
    } catch (e) {
      debugPrint('[AIBotScreen] Gemini error: $e');
      return _localFallback(prompt);
    }
  }

  String _buildEcgContext() {
    final recordings = storageService.getECGRecordings();
    final todayResults = storageService.getTodayInferenceResults();
    final ecgProvider = Provider.of<ECGProvider>(context, listen: false);
    final latest = ecgProvider.latestInferenceResult;

    final parts = <String>[];
    if (recordings.isNotEmpty) {
      parts.add('${recordings.length} total ECG recordings saved');
    }
    if (todayResults.isNotEmpty) {
      final anomalies = todayResults.where((r) => r['isAbnormal'] == true).length;
      parts.add('${todayResults.length} AI windows analyzed today, $anomalies abnormal');
    }
    if (latest != null && !latest.isError) {
      parts.add('Latest live AI result: ${latest.label} (${(latest.confidence * 100).toStringAsFixed(0)}%)');
    }
    if (ecgProvider.isConnected) {
      parts.add('Device is currently connected');
    }

    return parts.join('; ');
  }

  String _localFallback(String query) {
    final lower = query.toLowerCase();
    final btProvider = Provider.of<BluetoothProvider>(context, listen: false);
    final isConnected = btProvider.isConnected;

    final isEcgReportQuestion = lower.contains('current ecg') ||
        lower.contains('ecg report') ||
        lower.contains('current report') ||
        lower.contains('live ecg') ||
        lower.contains('live') ||
        lower.contains('waveform') ||
        lower.contains('realtime') ||
        lower.contains('real-time');

    if (isEcgReportQuestion) {
      if (isConnected) {
        final ecgProvider = Provider.of<ECGProvider>(context, listen: false);
        final latest = ecgProvider.latestInferenceResult;
        final hr = btProvider.currentHeartRate;
        final latestAnalysisStr = latest != null && !latest.isError
            ? ' The latest AI classification is "${latest.label}" with ${(latest.confidence * 100).toStringAsFixed(0)}% confidence.'
            : ' No anomalies have been detected yet.';
        return 'Your ECG device is connected and transmitting live data. Real-time heart rate is $hr bpm.$latestAnalysisStr You can view the live waveform graph on the Dashboard screen.';
      } else {
        return 'device not connected';
      }
    }

    if (lower.contains('connect') || lower.contains('pair') || lower.contains('bluetooth')) {
      if (isConnected) {
        return 'Your ECG device is already connected and active! You can view the live ECG graph and real-time heart rate on the Dashboard.';
      } else {
        return 'To connect your device:\n\n'
            '1. Enable Bluetooth on your phone\n'
            '2. Power on your BLE ECG device\n'
            '3. Go to the Device tab → tap Scan → tap Connect\n\n'
            'If the device doesn\'t appear, try restarting Bluetooth or moving closer.';
      }
    }
    if (lower.contains('atrial fibrillation') || lower.contains('afib')) {
      return 'Atrial Fibrillation (AFib) is an irregular heart rhythm where the upper '
          'chambers (atria) beat chaotically. ⚠️ If our AI detected this, please consult '
          'a cardiologist promptly. AFib can increase stroke risk if untreated.';
    }
    if (lower.contains('premature') || lower.contains('ectopic')) {
      return 'Premature beats are extra heartbeats that disrupt the normal rhythm. '
          'They\'re common and often harmless, but frequent occurrences should be '
          'evaluated by a doctor. Common triggers include caffeine, stress, and fatigue.';
    }
    if (lower.contains('bbb') || lower.contains('bundle branch')) {
      return 'Bundle Branch Block (BBB) means one of the electrical pathways in your '
          'heart is delayed. Left BBB and Right BBB look different on an ECG. '
          'RBBB is often benign; LBBB may indicate heart disease — both should be '
          'assessed by a cardiologist.';
    }
    if (lower.contains('normal') && lower.contains('ecg')) {
      return 'A normal ECG shows:\n• P wave — atrial depolarization\n'
          '• QRS complex — ventricular depolarization (the main spike)\n'
          '• T wave — ventricular repolarization\n\n'
          'Normal resting heart rate: 60–100 bpm with regular rhythm. ✅';
    }
    if (lower.contains('heart rate') || lower.contains('bpm')) {
      return 'Normal resting heart rate is 60–100 bpm.\n'
          '• < 60 bpm = Bradycardia (slow)\n'
          '• > 100 bpm = Tachycardia (fast)\n'
          '• Athletes may naturally have rates in the 40–60 range.\n\n'
          'Check the Dashboard for your live heart rate readings.';
    }
    if (lower.contains('tip') || lower.contains('health') || lower.contains('improve')) {
      return 'Heart health tips 💙\n\n'
          '1. Exercise: 150 min/week of moderate activity\n'
          '2. Diet: More fruits, vegetables, whole grains\n'
          '3. Sleep: 7–9 hours per night\n'
          '4. Monitor: Use Timed Check for regular ECG recordings\n'
          '5. Stress: Practice mindfulness or yoga';
    }

    return 'I can help with ECG interpretation, AI analysis results, device setup, '
        'and heart health questions. Could you rephrase your question? '
        'You can also try the quick prompts below! 😊';
  }

  List<String> _getQuickPrompts() {
    final ecgProvider = Provider.of<ECGProvider>(context, listen: false);
    final hasResult = ecgProvider.latestInferenceResult != null;
    final isConnected = ecgProvider.isConnected;

    final prompts = <String>[
      "Today's health summary",
      "What is a normal ECG?",
      "Tips for heart health",
    ];

    if (hasResult) {
      prompts.insert(0, 'Explain my latest AI result');
    }
    if (!isConnected) {
      prompts.add('How do I connect my device?');
    }
    if (prompts.length > 4) prompts.removeRange(4, prompts.length);
    return prompts;
  }

  // ── Past Chats Sheet ─────────────────────────────────────────────────────────

  void _showPastChatsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allChats = storageService.getSavedChats();
            final chats = allChats.where((chat) {
              final title = (chat['title'] as String? ?? '').toLowerCase();
              final msgs = chat['messages'] as List? ?? [];
              final lastMsg = msgs.isNotEmpty ? (msgs.last['text'] as String? ?? '').toLowerCase() : '';
              return title.contains(searchQuery.toLowerCase()) || lastMsg.contains(searchQuery.toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Past Conversations',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _startNewChat();
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New Chat', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Sleek Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface3 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : Colors.grey[300]!,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (val) {
                              setModalState(() {
                                searchQuery = val;
                              });
                            },
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search chats...',
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        if (searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setModalState(() {
                                searchQuery = '';
                              });
                            },
                            child: Icon(Icons.close, size: 16, color: Colors.grey[500]),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (chats.isEmpty)
                    Container(
                      height: 150,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 36, color: Colors.grey[500]),
                          const SizedBox(height: 8),
                          Text(
                            searchQuery.isEmpty ? 'No saved chats yet.' : 'No matching chats found.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.45,
                      child: ListView.builder(
                        itemCount: chats.length,
                        itemBuilder: (context, idx) {
                          final chat = chats[idx];
                          final id = chat['id'] as String;
                          final isActiveChat = id == _sessionId;
                          final msgs = chat['messages'] as List;
                          final lastMsg = msgs.isNotEmpty ? msgs.last['text'] as String : '';
                          final snippet = lastMsg.length > 50 ? '${lastMsg.substring(0, 47)}...' : lastMsg;

                          return Dismissible(
                            key: Key(id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.red[700],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete_sweep, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Chat'),
                                  content: const Text('Are you sure you want to delete this chat session?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (direction) {
                              _deleteChatSession(id);
                              setModalState(() {});
                            },
                            child: Card(
                              color: isActiveChat
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : isDark
                                      ? AppColors.darkSurface3
                                      : Colors.grey[50],
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isActiveChat
                                      ? AppColors.primary.withValues(alpha: 0.4)
                                      : isDark
                                          ? AppColors.darkBorder
                                          : Colors.grey[300]!,
                                ),
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                title: Text(
                                  chat['title'] as String? ?? 'Conversation',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isActiveChat ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  snippet,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isActiveChat)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Active',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.chevron_right, size: 16, color: Colors.grey[500]),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _loadPastChat(chat);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Personal Health Service', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('Powered by Gemini', style: TextStyle(fontSize: 10, color: AppColors.primaryLight)),
              ],
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Past Chats',
            onPressed: _showPastChatsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_rounded),
            tooltip: 'New Chat',
            onPressed: _startNewChat,
          ),
          const AppBarProfileAvatar(),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Consumer2<BluetoothProvider, ECGProvider>(
            builder: (ctx, btProvider, ecgProvider, _) {
              if (!btProvider.isConnected) return const SizedBox.shrink();
              final result = ecgProvider.latestInferenceResult;
              if (result == null || result.isError) return const SizedBox.shrink();
              final isAbnormal = result.isAbnormal;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isAbnormal
                    ? Colors.orange.withValues(alpha: 0.15)
                    : Colors.green.withValues(alpha: 0.12),
                child: Row(
                  children: [
                    Icon(
                      isAbnormal ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      color: isAbnormal ? Colors.orange[700] : Colors.green[600],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Live AI: ${result.displayLabel} (${(result.confidence * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isAbnormal ? Colors.orange[700] : Colors.green[600],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _handleSendMessage('Explain my latest AI result'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Explain',
                        style: TextStyle(fontSize: 11, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(msg, isDark);
                    },
                  ),
          ),

          // Typing indicator
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.grey[200],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: _TypingDots(isDark: isDark),
                ),
              ),
            ),

          // Quick prompt chips
          if (_messages.length <= 2 && !_isTyping)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: SizedBox(
                height: 44,
                child: Builder(builder: (_) {
                  final prompts = _getQuickPrompts();
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: prompts.length,
                    itemBuilder: (_, idx) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(prompts[idx], style: const TextStyle(fontSize: 12)),
                        onPressed: () => _handleSendMessage(prompts[idx]),
                        backgroundColor: isDark
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.08),
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  );
                }),
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface3 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : Colors.grey[300]!,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      onSubmitted: _handleSendMessage,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Ask about ECG, heart health...',
                        hintStyle: TextStyle(fontSize: 13),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    onPressed: _isTyping
                        ? null
                        : () => _handleSendMessage(_messageController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, bool isDark) {
    final isUser = msg.isUser;
    final bubbleColor = isUser
        ? AppColors.primary
        : msg.isAnalysis
            ? (isDark ? const Color(0xFF1A2035) : const Color(0xFFEEF2FF))
            : isDark
                ? AppColors.darkSurface
                : Colors.grey[100]!;

    final textColor = isUser
        ? Colors.white
        : isDark
            ? Colors.white
            : Colors.black87;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: msg.isAnalysis && !isUser
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.isAnalysis)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'AI Analysis',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              msg.text,
              style: TextStyle(
                color: msg.isError ? Colors.red[300] : textColor,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(msg.time),
              style: TextStyle(
                fontSize: 10,
                color: isUser
                    ? Colors.white54
                    : isDark
                        ? Colors.grey[600]
                        : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Data model ───────────────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isAnalysis;
  final bool isError;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.isAnalysis = false,
    this.isError = false,
  });
}

// ── Typing indicator ─────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  final bool isDark;
  const _TypingDots({required this.isDark});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
        ..repeat(reverse: true),
    );
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].forward();
      });
    }
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0.4, end: 1.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (ctx, child) => Container(
            margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (widget.isDark ? Colors.grey[400] : Colors.grey[500])!
                  .withValues(alpha: _animations[i].value),
            ),
          ),
        );
      }),
    );
  }
}

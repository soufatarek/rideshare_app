import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

class AiChatService {
  static const String _apiKey = 'AIzaSyAfu42WYHJeECRRjZa2QkBRPGJI79XmhDY';

  static const String _systemInstruction = '''
You are RideBot, the official AI customer service assistant for RideShare — a premium ride-hailing app.

Your personality:
- Friendly, professional, and empathetic
- Concise — keep answers under 150 words unless the user asks for details
- Use emoji sparingly (1-2 per response max) for warmth

You can help with:
1. **Ride Issues**: Delays, cancellations, driver problems, route disputes
2. **Payment & Billing**: Fare questions, refunds, payment methods, wallet balance
3. **Account**: Profile updates, password resets, saved places, verification
4. **Safety**: Reporting incidents, emergency contacts, trip sharing
5. **App Usage**: How to book rides, schedule trips, apply promo codes, rate drivers
6. **General Info**: Coverage areas, vehicle types, surge pricing explanation

Guidelines:
- If a user reports a safety emergency, immediately advise them to call local emergency services and use the in-app emergency button.
- For refund requests, explain that refunds are reviewed within 24-48 hours and processed to the original payment method.
- Never share personal driver or rider information.
- If you cannot resolve an issue, offer to escalate to a human support agent.
- Always end with asking if there's anything else you can help with.
- Never make up information about specific ride details, charges, or policies you're unsure about.
''';

  late final GenerativeModel _model;
  late ChatSession _chat;
  bool _isInitialized = false;

  AiChatService() {
    _initialize();
  }

  void _initialize() {
    try {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          maxOutputTokens: 1024,
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
        ),
        systemInstruction: Content.system(_systemInstruction),
      );
      _chat = _model.startChat();
      _isInitialized = true;
    } catch (e) {
      debugPrint('AiChatService: Failed to initialize Gemini: $e');
      _isInitialized = false;
    }
  }

  /// Send a message and get a complete response
  Future<String> sendMessage(String message) async {
    if (!_isInitialized) {
      _initialize();
      if (!_isInitialized) {
        return 'I\'m having trouble connecting right now. Please try again in a moment or contact us at support@rideshare.com.';
      }
    }

    try {
      final response = await _chat.sendMessage(Content.text(message));
      final text = response.text;
      if (text == null || text.isEmpty) {
        return 'I didn\'t quite catch that. Could you rephrase your question?';
      }
      return text;
    } on GenerativeAIException catch (e) {
      debugPrint('AiChatService: Gemini API error: $e');
      return 'I\'m experiencing a temporary issue. Please try again shortly or reach out to our support team.';
    } catch (e) {
      debugPrint('AiChatService: Unexpected error: $e');
      return 'Something went wrong on my end. Please try again or contact support.';
    }
  }

  /// Send a message and stream the response token by token
  Stream<String> sendMessageStream(String message) async* {
    if (!_isInitialized) {
      _initialize();
      if (!_isInitialized) {
        yield 'I\'m having trouble connecting right now. Please try again in a moment.';
        return;
      }
    }

    try {
      final response = _chat.sendMessageStream(Content.text(message));
      await for (final chunk in response) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }
    } on GenerativeAIException catch (e) {
      debugPrint('AiChatService: Stream error: $e');
      yield 'I\'m experiencing a temporary issue. Please try again shortly.';
    } catch (e) {
      debugPrint('AiChatService: Unexpected stream error: $e');
      yield 'Something went wrong. Please try again.';
    }
  }

  /// Reset the conversation (start fresh)
  void resetConversation() {
    _chat = _model.startChat();
  }

  /// Dispose resources
  void dispose() {
    // No explicit dispose needed for the Gemini client
  }
}

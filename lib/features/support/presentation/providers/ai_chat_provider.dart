import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_chat_service.dart';
import '../../domain/models/chat_message.dart';

// State class
class AiChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Notifier
class AiChatNotifier extends StateNotifier<AiChatState> {
  final AiChatService _chatService;
  final _uuid = const Uuid();
  StreamSubscription<String>? _streamSubscription;

  AiChatNotifier(this._chatService) : super(const AiChatState()) {
    // Add initial welcome message
    final welcome = ChatMessage(
      id: _uuid.v4(),
      text:
          'Hi there! 👋 I\'m RideBot, your RideShare assistant. How can I help you today?',
      role: ChatMessageRole.assistant,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [welcome]);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isLoading) return;

    // Add user message
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      text: text.trim(),
      role: ChatMessageRole.user,
      timestamp: DateTime.now(),
    );

    // Create placeholder for assistant response
    final assistantId = _uuid.v4();
    final assistantMessage = ChatMessage(
      id: assistantId,
      text: '',
      role: ChatMessageRole.assistant,
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage, assistantMessage],
      isLoading: true,
      error: null,
    );

    // Stream the response
    String fullText = '';
    try {
      final stream = _chatService.sendMessageStream(text.trim());
      _streamSubscription = stream.listen(
        (chunk) {
          fullText += chunk;
          _updateAssistantMessage(assistantId, fullText, true);
        },
        onDone: () {
          _updateAssistantMessage(assistantId, fullText, false);
          state = state.copyWith(isLoading: false);
        },
        onError: (error) {
          _updateAssistantMessage(
            assistantId,
            fullText.isNotEmpty
                ? fullText
                : 'Sorry, something went wrong. Please try again.',
            false,
          );
          state = state.copyWith(isLoading: false, error: error.toString());
        },
      );
    } catch (e) {
      _updateAssistantMessage(
        assistantId,
        'Sorry, I couldn\'t process your request. Please try again.',
        false,
      );
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _updateAssistantMessage(String id, String text, bool isStreaming) {
    final updatedMessages = state.messages.map((msg) {
      if (msg.id == id) {
        return msg.copyWith(text: text, isStreaming: isStreaming);
      }
      return msg;
    }).toList();
    state = state.copyWith(messages: updatedMessages);
  }

  void clearChat() {
    _streamSubscription?.cancel();
    _chatService.resetConversation();
    final welcome = ChatMessage(
      id: _uuid.v4(),
      text:
          'Hi there! 👋 I\'m RideBot, your RideShare assistant. How can I help you today?',
      role: ChatMessageRole.assistant,
      timestamp: DateTime.now(),
    );
    state = AiChatState(messages: [welcome]);
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _chatService.dispose();
    super.dispose();
  }
}

// Providers
final aiChatServiceProvider = Provider<AiChatService>((ref) {
  final service = AiChatService();
  ref.onDispose(() => service.dispose());
  return service;
});

final aiChatProvider =
    StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  final service = ref.watch(aiChatServiceProvider);
  return AiChatNotifier(service);
});

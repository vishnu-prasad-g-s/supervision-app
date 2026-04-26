// lib/chat_page/widgets/chat_ui_builder.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message_models.dart';
import 'chat_bubble.dart';
import 'prompt_bar.dart';
import 'semantic_material_button.dart';

/// Static UI builder for chat interface components with accessibility integration
class ChatUIBuilder {
  /// Clean modern app bar with settings button and proper system overlay
  static PreferredSizeWidget buildCleanAppBar({
    required VoidCallback onNewChat,
    required VoidCallback onToggleSettings,
    required bool isResetting,
  }) {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF07070F),
      systemOverlayStyle: SystemUiOverlayStyle.light, // Dark status bar content
      title: const Text(
        'SuperVision',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      actions: [
        // Settings button with accessibility support
        SemanticMaterialButton(
          label: 'Settings',
          hint: 'Double-tap to open settings page',
          onPressed: onToggleSettings,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 18, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  /// Toggle buttons for New Chat and Show/Hide Messages with proper focus traversal
  static Widget buildViewToggleButtons({
    required bool showMessages,
    required VoidCallback onToggleMessages,
    required VoidCallback onNewChat,
    required bool isResetting,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Row(
          children: [
            Expanded(
              child: _buildToggleButton(
                icon: Icons.refresh_rounded,
                label: 'New Chat',
                hint: isResetting
                    ? 'New chat is currently processing'
                    : 'Double-tap to start a new chat conversation',
                isActive: true,
                activeColor: Colors.white,
                inactiveColor: const Color(0xFF1E1E2E),
                onPressed: isResetting ? null : onNewChat,
                disabled: isResetting,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildToggleButton(
                icon: showMessages
                    ? Icons.chat_bubble_rounded
                    : Icons.chat_bubble_outline_rounded,
                label: showMessages ? 'Hide Messages' : 'Show Messages',
                hint: showMessages
                    ? 'Double-tap to hide the conversation messages'
                    : 'Double-tap to show the conversation messages',
                isActive: showMessages,
                activeColor: const Color(0xFFBDBDBD),
                inactiveColor: const Color(0xFF1E1E2E),
                onPressed: onToggleMessages,
                disabled: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reusable toggle button with state-based styling and accessibility
  static Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback? onPressed,
    required String hint,
    bool disabled = false,
  }) {
    Color backgroundColor;
    Color textColor;
    Color iconColor;

    // State-based color scheme
    if (disabled) {
      backgroundColor = const Color(0xFF141420);
      textColor = Colors.white30;
      iconColor = Colors.white30;
    } else if (isActive) {
      backgroundColor = activeColor;
      textColor = const Color(0xFF111111);
      iconColor = const Color(0xFF111111);
    } else {
      backgroundColor = inactiveColor;
      textColor = Colors.white60;
      iconColor = Colors.white60;
    }

    return SemanticMaterialButton(
      label: label,
      hint: hint,
      onPressed: disabled ? null : onPressed,
      disabled: disabled,
      child: SizedBox(
        height: 40,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: null, // Handled by semantic wrapper
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Scrollable message list with accessibility labels and semantic child counting
  static Widget buildMessagesContainer(
    List<ChatMessage> messages,
    ScrollController scrollController,
  ) {
    return Expanded(
      child: Semantics(
        label: 'Chat messages',
        hint: 'Swipe to scroll through conversation history',
        child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: messages.length,
          semanticChildCount: messages.length, // For screen readers
          itemBuilder: (_, i) => Semantics(
            // Descriptive labels for each message
            label: messages[i].isUser
                ? 'Your message ${i + 1} of ${messages.length}'
                : 'AI response ${i + 1} of ${messages.length}',
            child: ChatBubble(msg: messages[i]),
          ),
        ),
      ),
    );
  }

  /// Container for prompt bar that shows status during AI processing
  static Widget buildPromptBarContainer({
    required GlobalKey<PromptBarState> promptBarKey,
    required Future<void> Function(String) onPromptWithPhoto,
    required Future<void> Function(String) onPromptTextOnly,
    required bool disabled,
    required bool speechEnabled,
    required bool listening,
    required VoidCallback onToggleListening,
    required bool isGenerating,
    required bool isSpeaking,
    Future<void> Function()? onStopTts,
  }) {
    // Show status widget when AI is busy, otherwise show input bar
    if (isGenerating || isSpeaking) {
      return _buildStatusWidget(
        isGenerating: isGenerating,
        isSpeaking: isSpeaking,
      );
    }

    return Container(
      color: const Color(0xFF0E0E1A),
      padding: const EdgeInsets.all(16),
      child: PromptBar(
        key: promptBarKey,
        onPromptWithPhoto: onPromptWithPhoto,
        onPromptTextOnly: onPromptTextOnly,
        disabled: disabled,
        speechEnabled: speechEnabled,
        listening: listening,
        onToggleListening: onToggleListening,
        onStopTts: onStopTts,
      ),
    );
  }

  /// Visual status indicator during AI processing with accessibility announcements
  static Widget _buildStatusWidget({
    required bool isGenerating,
    required bool isSpeaking,
  }) {
    return Container(
      height: 80,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Semantics(
        label: isGenerating
            ? (isSpeaking
                  ? 'Generating response and speaking'
                  : 'Generating response')
            : 'Speaking response',
        hint: 'Please wait while the AI processes your request',
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                isGenerating
                    ? (isSpeaking
                          ? 'Generating and Speaking…'
                          : 'Generating Response…')
                    : 'Speaking…',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Loading screen shown during app initialization
  static Widget buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Silver glowing eye icon
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.10),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.remove_red_eye_outlined,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            // Silver spinner
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // App name
            const Text(
              'SuperVision',
              style: TextStyle(
                fontSize: 26,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),

            // Status text
            Text(
              'Initializing AI Engine…',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.40),
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

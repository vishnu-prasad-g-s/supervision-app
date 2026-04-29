import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'chat_page/widgets/semantic_material_button.dart';
import 'chat_page/widgets/semantic_button_registry.dart';

class SettingsPage extends StatefulWidget {
  final String systemContext;
  final PreferredBackend backend;
  const SettingsPage({Key? key, required this.systemContext, required this.backend}) : super(key: key);
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _systemContextController;
  late PreferredBackend _selectedBackend;
  bool _hasChanges = false;
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  final FocusScopeNode _pageScope = FocusScopeNode();

  // Quick action labels - editable
  final List<TextEditingController> _quickActionControllers = [];
  final List<String> _defaultQuickActions = [
    'What is this?',
    'Describe the room',
    'Read this text',
    'Tell me what you see',
  ];

  @override
  void initState() {
    super.initState();
    _systemContextController = TextEditingController(text: widget.systemContext);
    _selectedBackend = widget.backend;
    _systemContextController.addListener(_onChanged);
    for (final action in _defaultQuickActions) {
      _quickActionControllers.add(TextEditingController(text: action));
    }
  }

  void _onChanged() {
    setState(() {
      _hasChanges =
          _systemContextController.text.trim() != widget.systemContext.trim() ||
              _selectedBackend != widget.backend;
    });
  }

  void _onBackendChanged(PreferredBackend? b) {
    if (b != null) setState(() { _selectedBackend = b; _onChanged(); });
  }

  void _save() {
    Navigator.of(context).pop({
      'systemContext': _systemContextController.text.trim(),
      'backend': _selectedBackend,
    });
  }

  void _cancel() => Navigator.of(context).pop();

  @override
  void dispose() {
    _systemContextController.dispose();
    for (final c in _quickActionControllers) c.dispose();
    _pageScope.dispose();
    SemanticButtonRegistry.clear();
    super.dispose();
  }

  /// Handles controller arrow key presses to go back to the message interface.
  /// Any arrow key (up/down/left/right) from the gamepad dismisses settings.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      final isArrow = key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight;

      if (isArrow) {
        // Arrow key pressed in settings → go back to message interface
        debugPrint('SettingsPage: Arrow key pressed, navigating back');
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Intercept arrow keys at the top level so they always navigate back
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF07070F),
        appBar: _buildAppBar(),
        body: FocusScope(
          node: _pageScope,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Arrow key hint banner
                _buildArrowKeyHint(),
                const SizedBox(height: 20),
                _section(
                  icon: Icons.psychology_outlined,
                  title: 'AI Configuration',
                  children: [
                    _buildSystemContext(),
                    _divider(),
                    _buildBackendSelector(),
                  ],
                ),
                const SizedBox(height: 24),
                _section(
                  icon: Icons.bolt_rounded,
                  title: 'Quick Actions',
                  children: [
                    _buildQuickActionsInfo(),
                    const SizedBox(height: 8),
                    ..._quickActionControllers.asMap().entries.map(
                          (e) => Column(
                        children: [
                          if (e.key != 0) _divider(),
                          _buildQuickActionRow(e.key, e.value),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
                const SizedBox(height: 24),
                _section(
                  icon: Icons.sports_esports_outlined,
                  title: 'Controller Layout',
                  children: [_buildShortcutsTable()],
                ),
                const SizedBox(height: 24),
                if (_isAndroid) ...[
                  _section(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Accessibility',
                    children: [_buildAccessibilityTip()],
                  ),
                  const SizedBox(height: 24),
                ],
                _buildActionRow(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Arrow key hint ─────────────────────────────────────────────────────────
  Widget _buildArrowKeyHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(children: [
        const Icon(Icons.arrow_back_rounded, color: Colors.white38, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Press any arrow button on the controller to go back to messages.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ]),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF07070F),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
        onPressed: _cancel,
      ),
      title: const Text(
        'Settings',
        style: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      actions: [
        if (_hasChanges)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _save,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
      ),
    );
  }

  // ── Section wrapper ────────────────────────────────────────────────────────
  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(children: [
            Icon(icon, color: Colors.white38, size: 13),
            const SizedBox(width: 6),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ]),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
    height: 1,
    color: Colors.white.withOpacity(0.05),
  );

  // ── AI Configuration ───────────────────────────────────────────────────────
  Widget _buildSystemContext() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Context',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Guides how the AI responds to you',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _systemContextController,
            maxLines: 4,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              height: 1.6,
              letterSpacing: 0.1,
            ),
            decoration: InputDecoration(
              hintText: 'Enter AI instructions…',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.memory_rounded, color: Colors.white38, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Processing Backend',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'CPU is more compatible · GPU is faster',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildBackendToggle(),
        ],
      ),
    );
  }

  Widget _buildBackendToggle() {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _backendChip(PreferredBackend.cpu, 'CPU'),
          _backendChip(PreferredBackend.gpu, 'GPU'),
        ],
      ),
    );
  }

  Widget _backendChip(PreferredBackend b, String label) {
    final selected = _selectedBackend == b;
    return GestureDetector(
      onTap: () => _onBackendChanged(b),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // ── Quick Actions ──────────────────────────────────────────────────────────
  Widget _buildQuickActionsInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Text(
        'Triggered by controller buttons X · A · Y · B — tap any label to rename.',
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildQuickActionRow(int index, TextEditingController ctrl) {
    final icons = [
      Icons.help_outline_rounded,
      Icons.meeting_room_outlined,
      Icons.text_fields_rounded,
      Icons.visibility_outlined,
    ];
    final buttons = ['X', 'A', 'Y', 'B'];
    final buttonColors = [
      Colors.blue.shade300,
      Colors.green.shade300,
      Colors.amber.shade300,
      Colors.red.shade300,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icons[index], color: Colors.white38, size: 16),
        ),
        const SizedBox(width: 10),
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: buttonColors[index].withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: buttonColors[index].withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              buttons[index],
              style: TextStyle(
                color: buttonColors[index],
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: ctrl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Action label…',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
            onChanged: (_) => setState(() => _hasChanges = true),
          ),
        ),
        Icon(Icons.edit_rounded, color: Colors.white.withOpacity(0.15), size: 14),
      ]),
    );
  }

  // ── Controller Table ───────────────────────────────────────────────────────
  Widget _buildShortcutsTable() {
    const data = [
      ('R1',     'Send with photo'),
      ('R2',     'Toggle voice input'),
      ('Start',  'New chat'),
      ('X',      'What is this?'),
      ('A',      'Describe room'),
      ('Y',      'Read text'),
      ('B',      'Tell me what you see'),
      ('Select', 'Toggle settings'),
      ('L1',     'Send text only'),
      ('L2',     'Hide / show messages'),
      ('↑↓←→',  'Go back to messages'),
      ('−',      'Activate focused button'),
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white.withOpacity(0.03),
          child: Row(children: [
            Expanded(
              flex: 2,
              child: Text(
                'BUTTON',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'ACTION',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ]),
        ),
        ...data.map((row) => Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.04))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  row.$1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                row.$2,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ),
          ]),
        )),
      ],
    );
  }

  // ── Accessibility tip ──────────────────────────────────────────────────────
  Widget _buildAccessibilityTip() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'For the best controller experience, temporarily disable Android TalkBack in Accessibility settings.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action Row ─────────────────────────────────────────────────────────────
  Widget _buildActionRow() {
    return Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: _cancel,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: GestureDetector(
          onTap: _hasChanges ? _save : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52,
            decoration: BoxDecoration(
              color: _hasChanges ? Colors.white : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                'Save Changes',
                style: TextStyle(
                  color: _hasChanges ? Colors.black : Colors.white.withOpacity(0.2),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
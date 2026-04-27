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
  double _fontSize = 15.0;
  String _selectedLanguage = 'English';
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  final FocusScopeNode _pageScope = FocusScopeNode();

  final List<String> _languages = [
    'English', 'Tamil', 'Hindi', 'Telugu', 'Malayalam',
    'Kannada', 'Bengali', 'Marathi', 'Gujarati', 'Punjabi',
  ];

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
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('font_size') ?? 15.0;
      _selectedLanguage = prefs.getString('language') ?? 'English';
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', _fontSize);
    await prefs.setString('language', _selectedLanguage);
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
    _savePrefs();
    Navigator.of(context).pop({
      'systemContext': _systemContextController.text.trim(),
      'backend': _selectedBackend,
      'fontSize': _fontSize,
      'language': _selectedLanguage,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      appBar: _buildAppBar(),
      body: FocusScope(
        node: _pageScope,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section('AI Configuration', [
                _buildSystemContext(),
                const SizedBox(height: 12),
                _buildBackendSelector(),
              ]),
              const SizedBox(height: 28),
              _section('Appearance', [
                _buildFontSizeSlider(),
                const SizedBox(height: 12),
                _buildLanguageSelector(),
              ]),
              const SizedBox(height: 28),
              _section('Quick Actions', [
                _buildQuickActionsInfo(),
                const SizedBox(height: 12),
                ..._quickActionControllers.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildQuickActionRow(e.key, e.value),
                  ),
                ),
              ]),
              const SizedBox(height: 28),
              _section('Controller Layout', [_buildShortcutsTable()]),
              const SizedBox(height: 28),
              if (_isAndroid) ...[
                _section('Accessibility', [_buildAccessibilityTip()]),
                const SizedBox(height: 28),
              ],
              _buildActionRow(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

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
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
      actions: [
        if (_hasChanges)
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withOpacity(0.07)),
      ),
    );
  }

  // ── Section wrapper ────────────────────────────────────────────────────────
  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111118),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  // ── AI Configuration ───────────────────────────────────────────────────────
  Widget _buildSystemContext() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.psychology_outlined, color: Colors.white54, size: 16),
            const SizedBox(width: 8),
            const Text('System Context', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          Text('Guides how the AI responds to you', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: _systemContextController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Enter AI instructions…',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 14),
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
                borderSide: const BorderSide(color: Colors.white30),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendSelector() {
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07)))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.memory_rounded, color: Colors.white54, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Processing Backend', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                Text('CPU is more compatible, GPU is faster', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
              ],
            ),
          ),
          _buildBackendToggle(),
        ],
      ),
    );
  }

  Widget _buildBackendToggle() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.black : Colors.white54,
          fontSize: 13, fontWeight: FontWeight.w600,
        )),
      ),
    );
  }

  // ── Appearance ─────────────────────────────────────────────────────────────
  Widget _buildFontSizeSlider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.text_fields_rounded, color: Colors.white54, size: 16),
            const SizedBox(width: 8),
            const Text('Font Size', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _fontSize == 13 ? 'Small' : _fontSize == 15 ? 'Medium' : _fontSize == 18 ? 'Large' : 'Custom',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Text('A', style: TextStyle(color: Colors.white38, fontSize: 12)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white10,
                  trackHeight: 2,
                ),
                child: Slider(
                  value: _fontSize,
                  min: 13, max: 20, divisions: 7,
                  onChanged: (v) => setState(() { _fontSize = v; _hasChanges = true; }),
                ),
              ),
            ),
            Text('A', style: TextStyle(color: Colors.white38, fontSize: 20)),
          ]),
          // Preview text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Text(
              'This is how your chat text will look.',
              style: TextStyle(color: Colors.white70, fontSize: _fontSize, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07)))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.language_rounded, color: Colors.white54, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Response Language', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                Text('AI will respond in this language', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLanguage,
                dropdownColor: const Color(0xFF1A1A2E),
                isDense: true,
                icon: const Icon(Icons.expand_more_rounded, color: Colors.white54, size: 16),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                items: _languages.map((l) => DropdownMenuItem(
                  value: l,
                  child: Text(l, style: const TextStyle(color: Colors.white, fontSize: 13)),
                )).toList(),
                onChanged: (v) { if (v != null) setState(() { _selectedLanguage = v; _hasChanges = true; }); },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ──────────────────────────────────────────────────────────
  Widget _buildQuickActionsInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        const Icon(Icons.bolt_rounded, color: Colors.white54, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(
          'Shortcuts triggered by controller buttons F4–F7. Tap to rename.',
          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, height: 1.4),
        )),
      ]),
    );
  }

  Widget _buildQuickActionRow(int index, TextEditingController ctrl) {
    final icons = [Icons.help_outline_rounded, Icons.meeting_room_outlined, Icons.text_fields_rounded, Icons.visibility_outlined];
    final keys = ['F4', 'F5', 'F6', 'F7'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icons[index], color: Colors.white54, size: 15),
        ),
        const SizedBox(width: 10),
        Container(
          width: 32, height: 20,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Center(child: Text(keys[index], style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Action label…',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (_) => setState(() => _hasChanges = true),
          ),
        ),
      ]),
    );
  }

  // ── Controller Table ───────────────────────────────────────────────────────
  Widget _buildShortcutsTable() {
    const data = [
      ('Right Bumper', 'F1', 'Send with photo'),
      ('Right Trigger', 'F2', 'Toggle voice input'),
      ('Plus button', 'F3', 'New chat'),
      ('X button', 'F4', 'Quick action 1'),
      ('A button', 'F5', 'Quick action 2'),
      ('Y button', 'F6', 'Quick action 3'),
      ('B button', 'F7', 'Quick action 4'),
      ('Heart button', 'F8', 'Toggle settings'),
      ('Left Bumper', 'F9', 'Send text only'),
      ('Star button', 'F10', 'Toggle messages'),
      ('Minus button', 'Enter', 'Activate'),
    ];

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white.withOpacity(0.04),
          child: Row(children: [
            Expanded(flex: 3, child: Text('Button', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
            SizedBox(width: 40, child: Text('Key', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
            Expanded(flex: 2, child: Text('Action', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
          ]),
        ),
        ...data.map((row) => Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(flex: 3, child: Text(row.$1, style: const TextStyle(color: Colors.white70, fontSize: 13))),
            SizedBox(width: 40, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(row.$2, style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            )),
            Expanded(flex: 2, child: Text(row.$3, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13))),
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
          const Icon(Icons.lightbulb_outline_rounded, color: Colors.white38, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'For best controller experience, temporarily disable Android TalkBack in Accessibility settings.',
              style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13, height: 1.5),
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
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: Text('Cancel', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w500, fontSize: 15))),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: GestureDetector(
          onTap: _hasChanges ? _save : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 50,
            decoration: BoxDecoration(
              color: _hasChanges ? Colors.white : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(
              'Save Changes',
              style: TextStyle(
                color: _hasChanges ? Colors.black : Colors.white30,
                fontWeight: FontWeight.w600, fontSize: 15,
              ),
            )),
          ),
        ),
      ),
    ]);
  }
}

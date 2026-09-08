import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/random_emoji.dart';
import '../widgets/emoji_picker_dialog.dart';
import '../widgets/palette_picker.dart';
import '../widgets/user_avatar.dart';
import 'settings_screen.dart';

/// Overview: summary stats and recent history. Not built yet — for now it
/// demonstrates the member avatar and the two pickers behind it.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  // Demo state only, and deliberately local: a real member's emoji and colour
  // come from their row, and writing the *global* seed here would re-theme the
  // whole app instead of just this avatar.
  String _emoji = randomAvatarEmoji();
  Color _seedColor = Colors.green;

  Future<void> _pickEmoji() async {
    final picked = await showEmojiPickerDialog(context);
    if (picked != null && mounted) setState(() => _emoji = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navStart),
        actions: [
          // Settings hang off the Start page only.
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: l10n.settings,
            onPressed: () => openSettings(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 32,
          children: [
            Tooltip(
              message: l10n.chooseEmoji,
              child: UserAvatar(
                emoji: _emoji,
                seedColorArgb: _seedColor.toARGB32(),
                size: 128,
                onTap: () => unawaited(_pickEmoji()),
              ),
            ),
            ColorPicker(
              selected: _seedColor,
              onSelected: (color) => setState(() => _seedColor = color),
            ),
          ],
        ),
      ),
    );
  }
}

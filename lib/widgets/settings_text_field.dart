import 'package:flutter/material.dart';

/// A text field backed by one setting, committing on blur or submit rather
/// than per keystroke.
///
/// Stateful because every settings write rebuilds whoever is showing it. A
/// controller rebuilt from that value each frame would fight the cursor, so it
/// is owned here and re-synced only while unfocused.
class SettingsTextField extends StatefulWidget {
  const SettingsTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onCommit,
    this.validator,
    this.uppercase = false,
    this.maxLength,
  });

  final String label;

  /// The stored value; null and empty are the same thing to this widget.
  final String? value;

  /// Called with the trimmed text, or null when it was emptied.
  final ValueChanged<String?> onCommit;

  /// Returns an error message, or null when the value is acceptable. A failing
  /// value is shown as an error and **not** written.
  final String? Function(String value)? validator;

  final bool uppercase;
  final int? maxLength;

  @override
  State<SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<SettingsTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value ?? '',
  );
  final FocusNode _focusNode = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(SettingsTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.value ?? '';
    if (!_focusNode.hasFocus && incoming != _controller.text) {
      _controller.text = incoming;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    var text = _controller.text.trim();
    if (widget.uppercase) text = text.toUpperCase();

    final error = widget.validator?.call(text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() => _error = null);
    if (text != (widget.value ?? '')) {
      widget.onCommit(text.isEmpty ? null : text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLength: widget.maxLength,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _commit(),
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: _error,
        // A validation message is a sentence, and these fields can be narrow;
        // one line would ellipsize it away. The character counter would also
        // sit in that same row, taking width from it — and a three-character
        // code does not need counting.
        errorMaxLines: 3,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
    );
  }
}

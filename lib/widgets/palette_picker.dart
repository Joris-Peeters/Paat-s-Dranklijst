import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

// Used for small inline color picker
const seedColorPaletteSmall = <Color>[
  Colors.red,
  Colors.green,
  Colors.blue,
  Colors.purple,
];

// Used for color picker dialog
const seedColorPalette = <Color>[
  Colors.pink,
  Colors.deepOrange,
  Colors.orange,
  Colors.amber,
  Colors.lime,
  Colors.green,
  Colors.teal,
  Colors.cyan,
  Colors.lightBlue,
  Colors.indigo,
  Colors.deepPurple,
  Colors.purple,
];

/// The small palette inline, plus an icon button opening [ColorPickerDialog].
///
/// Nothing is highlighted when [selected] is not one of the four — same as the
/// dialog, which highlights only what it can show.
class ColorPicker extends StatelessWidget {
  const ColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Color selected;
  final ValueChanged<Color> onSelected;

  Future<void> _openDialog(BuildContext context) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => ColorPickerDialog(selected: selected),
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        for (final swatch in seedColorPaletteSmall)
          _Swatch(
            color: swatch,
            size: 40,
            isSelected: swatch.toARGB32() == selected.toARGB32(),
            onTap: () => onSelected(swatch),
          ),
        IconButton(
          icon: const Icon(Icons.palette_outlined),
          tooltip: l10n.chooseColor,
          onPressed: () => unawaited(_openDialog(context)),
        ),
      ],
    );
  }
}

const _swatchSpacing = 12.0;
const _swatchColumns = 4;

/// The curated palette as a grid of circular swatches. Pops with the tapped
/// colour — there is no confirm button.
class ColorPickerDialog extends StatelessWidget {
  const ColorPickerDialog({super.key, required this.selected});

  final Color selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Fixed columns, rows following the palette length. `mainAxisSize.min` on
    // both axes shrinks the dialog to exactly the swatches plus their gaps.
    return AlertDialog(
      title: Text(l10n.chooseColor),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: _swatchSpacing,
        children: [
          for (var i = 0; i < seedColorPalette.length; i += _swatchColumns)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: _swatchSpacing,
              children: [
                for (final color
                    in seedColorPalette.skip(i).take(_swatchColumns))
                  _Swatch(
                    color: color,
                    isSelected: color.toARGB32() == selected.toARGB32(),
                    onTap: () => Navigator.pop(context, color),
                  ),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.size = 56,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.onSurface;
    final checkMarkColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: borderColor, width: 3) : null,
        ),
        // The check needs to read against the swatch itself, not the page.
        child: isSelected ? Icon(Icons.check, color: checkMarkColor) : null,
      ),
    );
  }
}

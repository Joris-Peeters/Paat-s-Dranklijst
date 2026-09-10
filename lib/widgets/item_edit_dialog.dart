import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/database_provider.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../settings/settings_data.dart';
import 'emoji_picker_dialog.dart';
import 'full_screen_editor.dart';

/// Creates or edits one item. Closes on save; the caller's stream updates.
Future<void> showItemEditDialog(
  BuildContext context, {
  ItemRow? item,
  ItemGroupRow? presetGroup,
}) => showDialog<void>(
  context: context,
  builder: (_) => ItemEditDialog(item: item, presetGroup: presetGroup),
);

class ItemEditDialog extends StatefulWidget {
  const ItemEditDialog({super.key, this.item, this.presetGroup});

  /// Null creates a new item.
  final ItemRow? item;

  /// The category a new item starts in. Taken whole rather than by id so the
  /// new item can also start on the category's own emoji.
  final ItemGroupRow? presetGroup;

  @override
  State<ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<ItemEditDialog> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _price = TextEditingController();

  // A new item starts on its category's emoji, which is a better guess than
  // nothing and often right — a drink in "🥤 Frisdrank" is a soft drink. Null
  // when the category has none: the column is non-null with no default, so Save
  // stays disabled rather than inventing a glyph. Unlike a user, whose face is
  // arbitrary and assigned at random, an item's emoji is what people tap to
  // pick their drink.
  late String? _emoji = widget.item?.emoji ?? widget.presetGroup?.emoji;
  late int? _groupId = widget.item?.groupId ?? widget.presetGroup?.id;

  /// Only after the first build: the amount has to be written in the language
  /// and currency the settings say, which needs an inherited widget.
  bool _priceFilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final item = widget.item;
    if (!_priceFilled && item != null) {
      _price.text = AppSettings.of(context).formatAmount(item.priceMinorUnits);
      _priceFilled = true;
    }
  }

  int? get _parsedPrice => AppSettings.of(context).parseMoney(_price.text);

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      _emoji != null &&
      _groupId != null &&
      _parsedPrice != null;

  Future<void> _save() async {
    final dao = Database.of(context).itemsDao;
    final name = _name.text.trim();
    final price = _parsedPrice!;
    final emoji = _emoji!;
    final groupId = _groupId!;
    final item = widget.item;
    final navigator = Navigator.of(context);

    if (item == null) {
      await dao.createItem(
        name: name,
        groupId: groupId,
        priceMinorUnits: price,
        emoji: emoji,
      );
    } else {
      await dao.updateItemDetails(
        id: item.id,
        name: name,
        emoji: emoji,
        priceMinorUnits: price,
        groupId: groupId,
      );
    }
    navigator.pop();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppSettings.of(context);
    final typed = _price.text.trim();

    return FullScreenEditor(
      title: widget.item == null ? l10n.newItem : l10n.editItem,
      onSave: _canSave ? () => unawaited(_save()) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: [
          Center(
            child: EmojiPickerButton(
              emoji: _emoji,
              size: 96,
              onPicked: (emoji) => setState(() => _emoji = emoji),
            ),
          ),
          TextField(
            controller: _name,
            autofocus: widget.item == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.nameLabel,
              border: const OutlineInputBorder(),
            ),
            // Save is enabled off these two, so every keystroke has to be seen.
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.priceLabel,
              prefixText: '${settings.currencySymbol} ',
              border: const OutlineInputBorder(),
              // Only once something unreadable has been typed: an empty field
              // is incomplete, not wrong.
              errorText: typed.isNotEmpty && _parsedPrice == null
                  ? l10n.priceInvalid
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          _CategoryField(
            selected: _groupId,
            onSelected: (id) => setState(() => _groupId = id),
          ),
        ],
      ),
    );
  }
}

class _CategoryField extends StatefulWidget {
  const _CategoryField({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  State<_CategoryField> createState() => _CategoryFieldState();
}

class _CategoryFieldState extends State<_CategoryField> {
  late final _groups = Database.of(context).itemsDao.watchItemGroups();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<List<ItemGroupRow>>(
      stream: _groups,
      builder: (context, snapshot) {
        final groups = snapshot.data ?? const <ItemGroupRow>[];
        // The value has to be one of the items or the dropdown asserts, which
        // it is not on the first frame before the query resolves.
        final selected = groups.any((g) => g.id == widget.selected)
            ? widget.selected
            : null;

        return DropdownButtonFormField<int>(
          initialValue: selected,
          decoration: InputDecoration(
            labelText: l10n.categoryLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final group in groups)
              DropdownMenuItem(
                value: group.id,
                child: Text(
                  group.emoji == null
                      ? group.name
                      : '${group.emoji}  ${group.name}',
                ),
              ),
          ],
          onChanged: (id) {
            if (id != null) widget.onSelected(id);
          },
        );
      },
    );
  }
}

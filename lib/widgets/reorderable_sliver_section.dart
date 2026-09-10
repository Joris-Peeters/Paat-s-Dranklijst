import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/reorder.dart';

/// A reorderable list that holds the dropped order until the write lands.
///
/// The list rebuilds from its stream the moment the finger lifts, and the
/// stream is still carrying the old order until the transaction commits, so
/// without the local copy the row visibly snaps back before jumping forward
/// again. The stream stays the source of truth — the next value replaces this,
/// whether it confirms the move or, if the write failed, undoes it.
///
/// A sliver rather than a whole list: a screen that also shows archived rows
/// puts them in a second, non-reorderable sliver below, which is what keeps an
/// active row from being dropped among them.
class ReorderableSliverSection<T> extends StatefulWidget {
  const ReorderableSliverSection({
    super.key,
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    required this.onReorder,
  });

  final List<T> items;

  /// `SliverReorderableList` needs a stable key per row to animate the move.
  final Key Function(T item) keyOf;

  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Called with the whole list in its new order.
  final void Function(List<T> ordered) onReorder;

  @override
  State<ReorderableSliverSection<T>> createState() =>
      _ReorderableSliverSectionState<T>();
}

class _ReorderableSliverSectionState<T>
    extends State<ReorderableSliverSection<T>> {
  late List<T> _items = widget.items;

  @override
  void didUpdateWidget(ReorderableSliverSection<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _items = widget.items;
  }

  void _reorder(int oldIndex, int newIndex) {
    final moved = reordered(_items, oldIndex, newIndex);
    setState(() => _items = moved);
    widget.onReorder(moved);
  }

  @override
  Widget build(BuildContext context) => SliverReorderableList(
    itemCount: _items.length,
    onReorderItem: _reorder,
    itemBuilder: (context, index) => KeyedSubtree(
      key: widget.keyOf(_items[index]),
      child: widget.itemBuilder(context, _items[index], index),
    ),
  );
}

/// The grip that starts a drag, for a list built with
/// `buildDefaultDragHandles: false`.
///
/// On the left of every row, so a long-press anywhere else does not fight the
/// tap that opens it.
class DragHandle extends StatelessWidget {
  const DragHandle({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) => ReorderableDragStartListener(
    index: index,
    child: Tooltip(
      message: AppLocalizations.of(context).dragToReorder,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.drag_handle),
      ),
    ),
  );
}

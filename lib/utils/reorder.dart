/// Applies one `ReorderableListView` drag to a list.
///
/// Takes the indices from `onReorderItem`, which reports [newIndex] already
/// adjusted for the item being lifted out — the older `onReorder` callback did
/// not, and needed the caller to subtract one when dragging downwards. Kept as
/// a pure function so the DAOs only ever see a finished order and the screens
/// only ever pass one along.
List<T> reordered<T>(List<T> items, int oldIndex, int newIndex) {
  final result = List<T>.of(items);
  result.insert(newIndex, result.removeAt(oldIndex));
  return result;
}

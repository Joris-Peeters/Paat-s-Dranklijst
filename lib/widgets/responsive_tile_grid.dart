import 'dart:math';

import 'package:flutter/material.dart';

/// A scrolling grid that takes as many columns as fit at [minTileWidth].
///
/// The kiosk runs portrait on a tablet but has to stay usable on a phone, so
/// the column count is measured rather than chosen per breakpoint.
class ResponsiveTileGrid extends StatelessWidget {
  const ResponsiveTileGrid({
    super.key,
    required this.minTileWidth,
    required this.children,
    this.spacing = 12,
    this.padding = const EdgeInsets.all(16),
    this.tileAspectRatio = 1,
    this.tileHeight,
    this.shrinkWrap = false,
  });

  /// No tile is ever drawn narrower than this; they stretch to fill instead.
  final double minTileWidth;

  final List<Widget> children;
  final double spacing;
  final EdgeInsets padding;

  /// Width over height of one tile. Ignored when [tileHeight] is given.
  final double tileAspectRatio;

  /// A fixed height, for a tile whose content does not grow with its width —
  /// a row of avatar, name and amount stays the same height however wide the
  /// window gets, which a ratio cannot express.
  final double? tileHeight;

  /// Sizes to its content and stops scrolling, for a grid that is one section
  /// of a larger scroll view rather than the whole page.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      assert(
        constraints.maxWidth.isFinite,
        'ResponsiveTileGrid measures its width, so it cannot sit in a '
        'horizontally unbounded parent such as a Row or a horizontal '
        'ListView.',
      );

      // The gaps have to come out of the budget before dividing, or n columns
      // at minTileWidth plus n-1 gaps overflows and every tile ends up narrower
      // than asked for.
      final available = constraints.maxWidth - padding.horizontal;
      final columns = max(
        1,
        ((available + spacing) / (minTileWidth + spacing)).floor(),
      );

      return GridView.builder(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: tileAspectRatio,
          // Takes precedence over the ratio when set, which is why the two are
          // documented as exclusive rather than combined.
          mainAxisExtent: tileHeight,
        ),
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
      );
    },
  );
}

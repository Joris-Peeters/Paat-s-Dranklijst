import 'package:flutter/material.dart';

/// The curated seed colors offered to admins and users.
///
/// Material baseline colors, so every tonal palette `ColorScheme.fromSeed`
/// derives from one is a combination Material's own designers checked. Stored
/// as the resolved ARGB int, never as an index into this list — retiring or
/// reordering an entry must not silently recolor anything. See CLAUDE.md rule 4.
const seedColorPalette = <Color>[
  Colors.red,
  Colors.deepOrange,
  Colors.amber,
  Colors.green,
  Colors.teal,
  Colors.lightBlue,
  Colors.indigo,
  Colors.purple,
  Colors.pink,
  Colors.brown,
  Colors.blueGrey,
  Colors.grey,
];

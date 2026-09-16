import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// A QR code on its white quiet zone, drawn by hand.
///
/// Every dark module goes into one path, filled with anti-aliasing off. Drawn
/// as separate anti-aliased squares, as `qr_flutter` does, edges that fall
/// between physical pixels blend with the white and leave faint lines between
/// neighbouring modules.
class QrMatrix extends StatelessWidget {
  const QrMatrix({super.key, required this.image, required this.size});

  final QrImage image;

  /// The whole square, quiet zone included.
  final double size;

  /// The margin the QR standard requires around the code; not decorative.
  static const _quietZone = 16.0;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(_quietZone),
    decoration: BoxDecoration(
      // Scanners expect dark modules on light, whatever the theme.
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: CustomPaint(
      painter: _QrPainter(
        image: image,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      ),
    ),
  );
}

class _QrPainter extends CustomPainter {
  _QrPainter({required this.image, required this.devicePixelRatio});

  final QrImage image;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount;

    // Whole physical pixels per module where there is room for at least one,
    // so every module comes out the same width; the grid is centred in what
    // is left over.
    final available = size.shortestSide;
    final physical = (available * devicePixelRatio / count).floorToDouble();
    final module = physical >= 1
        ? physical / devicePixelRatio
        : available / count;
    final origin = (available - module * count) / 2;

    final path = Path();
    for (var row = 0; row < count; row++) {
      // Runs of dark modules become one rectangle each.
      var col = 0;
      while (col < count) {
        if (!image.isDark(row, col)) {
          col++;
          continue;
        }
        final start = col;
        while (col < count && image.isDark(row, col)) {
          col++;
        }
        path.addRect(
          Rect.fromLTRB(
            origin + start * module,
            origin + row * module,
            origin + col * module,
            origin + (row + 1) * module,
          ),
        );
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) =>
      image != oldDelegate.image ||
      devicePixelRatio != oldDelegate.devicePixelRatio;
}

import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const size = 1024;

  final image = img.Image(width: size, height: size);

  final black = img.ColorRgb8(11, 11, 11);

  final deepBlack = img.ColorRgb8(20, 17, 12);

  final gold = img.ColorRgb8(214, 179, 90);

  final brightGold = img.ColorRgb8(242, 213, 126);

  img.fill(image, color: black);

  // Outer Golden Finds medallion.
  img.fillCircle(
    image,
    x: 512,
    y: 512,
    radius: 405,
    color: gold,
    antialias: true,
  );

  img.fillCircle(
    image,
    x: 512,
    y: 512,
    radius: 355,
    color: deepBlack,
    antialias: true,
  );

  // Shopping bag body.
  img.fillRect(
    image,
    x1: 290,
    y1: 445,
    x2: 734,
    y2: 735,
    radius: 65,
    color: gold,
  );

  img.fillRect(
    image,
    x1: 340,
    y1: 495,
    x2: 684,
    y2: 685,
    radius: 35,
    color: deepBlack,
  );

  // Shopping bag handle.
  img.fillRect(
    image,
    x1: 380,
    y1: 300,
    x2: 644,
    y2: 505,
    radius: 125,
    color: gold,
  );

  img.fillRect(
    image,
    x1: 425,
    y1: 345,
    x2: 599,
    y2: 505,
    radius: 85,
    color: deepBlack,
  );

  // Golden horizontal detail.
  img.fillRect(
    image,
    x1: 370,
    y1: 555,
    x2: 654,
    y2: 600,
    radius: 22,
    color: brightGold,
  );

  // Left sparkle.
  img.fillRect(
    image,
    x1: 205,
    y1: 250,
    x2: 235,
    y2: 360,
    radius: 15,
    color: brightGold,
  );

  img.fillRect(
    image,
    x1: 165,
    y1: 290,
    x2: 275,
    y2: 320,
    radius: 15,
    color: brightGold,
  );

  // Right smaller sparkle.
  img.fillRect(
    image,
    x1: 785,
    y1: 650,
    x2: 805,
    y2: 725,
    radius: 10,
    color: gold,
  );

  img.fillRect(
    image,
    x1: 758,
    y1: 677,
    x2: 832,
    y2: 697,
    radius: 10,
    color: gold,
  );

  final directory = Directory('assets/icon');

  directory.createSync(recursive: true);

  final file = File('assets/icon/golden_finds.png');

  file.writeAsBytesSync(img.encodePng(image, level: 9));

  stdout.writeln('GoldenFinds icon generated: ${file.path}');
}

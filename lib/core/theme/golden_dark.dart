import 'package:flutter/material.dart';

class GoldenDark {
  GoldenDark._();

  static bool enabled(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color page(BuildContext context, {required Color light}) {
    return enabled(context) ? const Color(0xFF0E1116) : light;
  }

  static Color surface(BuildContext context, {Color light = Colors.white}) {
    return enabled(context) ? const Color(0xFF181D24) : light;
  }

  static Color surfaceAlt(BuildContext context, {required Color light}) {
    return enabled(context) ? const Color(0xFF222933) : light;
  }

  static Color field(BuildContext context, {Color light = Colors.white}) {
    return enabled(context) ? const Color(0xFF20262F) : light;
  }

  static Color text(
    BuildContext context, {
    Color light = const Color(0xFF111111),
  }) {
    return enabled(context) ? const Color(0xFFF7F8FA) : light;
  }

  static Color muted(BuildContext context, {Color light = Colors.black54}) {
    return enabled(context) ? const Color(0xFFB6BEC8) : light;
  }

  static Color subtle(BuildContext context, {Color light = Colors.black38}) {
    return enabled(context) ? const Color(0xFF88939F) : light;
  }

  static Color border(
    BuildContext context, {
    Color light = const Color(0xFFE4DED2),
  }) {
    return enabled(context) ? const Color(0xFF313A45) : light;
  }

  static Color visitorSoft(BuildContext context, {required Color light}) {
    return enabled(context) ? const Color(0xFF25241F) : light;
  }

  static Color clientSoft(BuildContext context, {required Color light}) {
    return enabled(context) ? const Color(0xFF153237) : light;
  }

  static Color sellerSoft(BuildContext context, {required Color light}) {
    return enabled(context) ? const Color(0xFF34232A) : light;
  }

  static Color visitorInk(BuildContext context) {
    return enabled(context) ? const Color(0xFFF7F8FA) : const Color(0xFF0B0B0B);
  }

  static Color clientInk(BuildContext context) {
    return enabled(context) ? const Color(0xFFE9FCFA) : const Color(0xFF0B2638);
  }

  static Color clientAccent(BuildContext context) {
    return enabled(context) ? const Color(0xFF69E1D5) : const Color(0xFF17A99A);
  }

  static Color sellerInk(BuildContext context) {
    return enabled(context) ? const Color(0xFFFFF3E2) : const Color(0xFF5A1E2B);
  }

  static Color sellerAccent(BuildContext context) {
    return enabled(context) ? const Color(0xFFFFD889) : const Color(0xFFF4B64A);
  }
}

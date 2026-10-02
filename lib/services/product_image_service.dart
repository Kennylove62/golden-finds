import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class PreparedProductImage {
  const PreparedProductImage({
    required this.bytes,
    required this.base64Data,
    required this.width,
    required this.height,
    required this.originalBytes,
  });

  final Uint8List bytes;
  final String base64Data;
  final int width;
  final int height;
  final int originalBytes;

  int get compressedBytes => bytes.length;

  String get compressedSizeLabel =>
      '${(compressedBytes / 1024).toStringAsFixed(0)} KB';
}

class ProductImageService {
  static const int _maxSourceBytes = 12 * 1024 * 1024;
  static const int _targetBytes = 240 * 1024;

  Future<PreparedProductImage> prepareProductImage(
    Uint8List sourceBytes,
  ) async {
    if (sourceBytes.isEmpty) {
      throw Exception('The selected image is empty.');
    }

    if (sourceBytes.length > _maxSourceBytes) {
      throw Exception(
        'The selected image is too large. Choose an image under 12 MB.',
      );
    }

    final decoded = img.decodeImage(sourceBytes);

    if (decoded == null) {
      throw Exception('Unable to read this image.');
    }

    var working = _resizeWithin(decoded, 1200);

    Uint8List encoded = _encodeJpeg(working, quality: 82);

    const qualities = [72, 62, 52, 42];

    for (final quality in qualities) {
      if (encoded.length <= _targetBytes) {
        break;
      }

      encoded = _encodeJpeg(working, quality: quality);
    }

    if (encoded.length > _targetBytes) {
      working = _resizeWithin(working, 900);

      encoded = _encodeJpeg(working, quality: 68);
    }

    if (encoded.length > _targetBytes) {
      working = _resizeWithin(working, 720);

      encoded = _encodeJpeg(working, quality: 58);
    }

    if (encoded.length > _targetBytes) {
      working = _resizeWithin(working, 600);

      encoded = _encodeJpeg(working, quality: 50);
    }

    if (encoded.length > _targetBytes) {
      throw Exception(
        'The image cannot be compressed enough for Firestore. '
        'Choose another image.',
      );
    }

    return PreparedProductImage(
      bytes: encoded,
      base64Data: base64Encode(encoded),
      width: working.width,
      height: working.height,
      originalBytes: sourceBytes.length,
    );
  }

  Uint8List _encodeJpeg(img.Image image, {required int quality}) {
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  img.Image _resizeWithin(img.Image source, int maxSide) {
    if (source.width <= maxSide && source.height <= maxSide) {
      return source;
    }

    if (source.width >= source.height) {
      final height = (source.height * maxSide / source.width).round();

      return img.copyResize(source, width: maxSide, height: height);
    }

    final width = (source.width * maxSide / source.height).round();

    return img.copyResize(source, width: width, height: maxSide);
  }
}

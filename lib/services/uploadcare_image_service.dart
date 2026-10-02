import 'dart:convert';

import 'package:http/http.dart' as http;

class UploadcareImageService {
  UploadcareImageService({http.Client? client})
    : _client = client ?? http.Client();

  static const String publicKey = '718f4e0655ef0dc699b9';
  static const String cdnBaseUrl = 'https://3oraq6nmcv.ucarecd.net';
  static final Uri _uploadEndpoint = Uri.parse(
    'https://upload.uploadcare.com/base/',
  );

  final http.Client _client;

  Future<String> uploadProductImage({
    required String sellerId,
    required String productId,
    required String imageBase64,
  }) async {
    final cleanBase64 = imageBase64.trim();

    if (cleanBase64.isEmpty) {
      throw Exception('No product image was provided.');
    }

    late final List<int> bytes;

    try {
      bytes = base64Decode(cleanBase64);
    } on FormatException {
      throw Exception('The selected product image is invalid.');
    }

    if (bytes.isEmpty) {
      throw Exception('The selected product image is empty.');
    }

    final request = http.MultipartRequest('POST', _uploadEndpoint)
      ..fields['UPLOADCARE_PUB_KEY'] = publicKey
      ..fields['UPLOADCARE_STORE'] = '1'
      ..fields['metadata[sellerId]'] = sellerId
      ..fields['metadata[productId]'] = productId
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: '${sellerId}_$productId.jpg',
        ),
      );

    late final http.StreamedResponse streamedResponse;

    try {
      streamedResponse = await _client.send(request);
    } catch (_) {
      throw Exception(
        'Image upload failed. Check your internet connection and try again.',
      );
    }

    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      throw Exception('Image upload failed (${streamedResponse.statusCode}).');
    }

    late final Object? decoded;

    try {
      decoded = jsonDecode(responseBody);
    } on FormatException {
      throw Exception('Uploadcare returned an invalid response.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Uploadcare returned an unexpected response.');
    }

    final uuid = (decoded['file'] ?? '').toString().trim();

    if (uuid.isEmpty) {
      throw Exception('Uploadcare did not return a file identifier.');
    }

    return '$cdnBaseUrl/$uuid/';
  }

  void close() {
    _client.close();
  }
}

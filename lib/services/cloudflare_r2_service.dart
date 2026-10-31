import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../core/config/app_config.dart';
import '../core/errors/error_handler.dart';

class CloudflareR2Service {
  static final CloudflareR2Service instance = CloudflareR2Service._();
  CloudflareR2Service._();

  static const _uuid = Uuid();

  /// Uploads raw bytes (e.g. image bytes) to Cloudflare R2 using AWS Signature v4
  /// and returns the public CDN URL.
  Future<String?> uploadBytes({
    required Uint8List bytes,
    required String path,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final accountId = AppConfig.r2AccountId;
      final bucket = AppConfig.r2BucketName;
      final accessKey = AppConfig.r2AccessKeyId;
      final secretKey = AppConfig.r2SecretAccessKey;
      final publicBase = AppConfig.r2PublicBaseUrl;

      // Clean the key path
      final cleanKey = path.startsWith('/') ? path.substring(1) : path;

      final now = DateTime.now().toUtc();
      final amzDate = '${now.toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}Z';
      final dateStamp = amzDate.substring(0, 8);

      final payloadHash = sha256.convert(bytes).toString();

      final host = '$accountId.r2.cloudflarestorage.com';
      final canonicalUri = '/$bucket/$cleanKey';

      final canonicalHeaders = 'content-type:$contentType\n'
          'host:$host\n'
          'x-amz-content-sha256:$payloadHash\n'
          'x-amz-date:$amzDate\n';

      final signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';

      final canonicalRequest = [
        'PUT',
        canonicalUri,
        '', // query string
        canonicalHeaders,
        signedHeaders,
        payloadHash,
      ].join('\n');

      final hashedCanonicalRequest = sha256.convert(utf8.encode(canonicalRequest)).toString();
      final credentialScope = '$dateStamp/auto/s3/aws4_request';

      final stringToSign = [
        'AWS4-HMAC-SHA256',
        amzDate,
        credentialScope,
        hashedCanonicalRequest,
      ].join('\n');

      List<int> hmacSha256(List<int> key, String data) {
        return Hmac(sha256, key).convert(utf8.encode(data)).bytes;
      }

      final kSecret = utf8.encode('AWS4$secretKey');
      final kDate = hmacSha256(kSecret, dateStamp);
      final kRegion = hmacSha256(kDate, 'auto');
      final kService = hmacSha256(kRegion, 's3');
      final kSigning = hmacSha256(kService, 'aws4_request');

      final signature = Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).toString();

      final authHeader = 'AWS4-HMAC-SHA256 '
          'Credential=$accessKey/$credentialScope, '
          'SignedHeaders=$signedHeaders, '
          'Signature=$signature';

      final putUrl = 'https://$host$canonicalUri';

      final res = await http.put(
        Uri.parse(putUrl),
        headers: {
          'Host': host,
          'x-amz-date': amzDate,
          'x-amz-content-sha256': payloadHash,
          'content-type': contentType,
          'Authorization': authHeader,
        },
        body: bytes,
      );

      if (res.statusCode == 200) {
        final publicUrl = '$publicBase/$cleanKey';
        debugPrint('Cloudflare R2 upload success: $publicUrl');
        return publicUrl;
      } else {
        debugPrint('Cloudflare R2 upload failed [${res.statusCode}]: ${res.body}');
        return null;
      }
    } catch (e, st) {
      ErrorHandler.log('CloudflareR2Service.uploadBytes', e, st);
      return null;
    }
  }

  /// Convenience method for uploading group cover photos or bill receipts
  Future<String?> uploadImage({
    required Uint8List bytes,
    String folder = 'groups',
    String? customFileName,
    String extension = 'jpg',
  }) async {
    final fileName = customFileName ?? '${_uuid.v4()}.$extension';
    final path = '$folder/$fileName';
    final contentType = extension.toLowerCase() == 'png'
        ? 'image/png'
        : (extension.toLowerCase() == 'webp' ? 'image/webp' : 'image/jpeg');

    return uploadBytes(
      bytes: bytes,
      path: path,
      contentType: contentType,
    );
  }

  /// Deletes an object from Cloudflare R2 by its public URL.
  Future<bool> deleteByUrl(String publicUrl) async {
    try {
      final accountId = AppConfig.r2AccountId;
      final bucket = AppConfig.r2BucketName;
      final accessKey = AppConfig.r2AccessKeyId;
      final secretKey = AppConfig.r2SecretAccessKey;
      final publicBase = AppConfig.r2PublicBaseUrl;

      // Extract the key from publicUrl
      String cleanKey;
      if (publicBase.isNotEmpty && publicUrl.startsWith(publicBase)) {
        cleanKey = publicUrl.substring(publicBase.length);
      } else {
        final uri = Uri.tryParse(publicUrl);
        cleanKey = uri?.path ?? publicUrl;
      }
      if (cleanKey.startsWith('/')) cleanKey = cleanKey.substring(1);

      if (cleanKey.isEmpty) return false;

      final now = DateTime.now().toUtc();
      final amzDate = '${now.toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}Z';
      final dateStamp = amzDate.substring(0, 8);

      const payloadHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'; // sha256 of empty string

      final host = '$accountId.r2.cloudflarestorage.com';
      final canonicalUri = '/$bucket/$cleanKey';

      final canonicalHeaders = 'host:$host\n'
          'x-amz-content-sha256:$payloadHash\n'
          'x-amz-date:$amzDate\n';

      final signedHeaders = 'host;x-amz-content-sha256;x-amz-date';

      final canonicalRequest = [
        'DELETE',
        canonicalUri,
        '', // query string
        canonicalHeaders,
        signedHeaders,
        payloadHash,
      ].join('\n');

      final hashedCanonicalRequest = sha256.convert(utf8.encode(canonicalRequest)).toString();
      final credentialScope = '$dateStamp/auto/s3/aws4_request';

      final stringToSign = [
        'AWS4-HMAC-SHA256',
        amzDate,
        credentialScope,
        hashedCanonicalRequest,
      ].join('\n');

      List<int> hmacSha256(List<int> key, String data) {
        return Hmac(sha256, key).convert(utf8.encode(data)).bytes;
      }

      final kSecret = utf8.encode('AWS4$secretKey');
      final kDate = hmacSha256(kSecret, dateStamp);
      final kRegion = hmacSha256(kDate, 'auto');
      final kService = hmacSha256(kRegion, 's3');
      final kSigning = hmacSha256(kService, 'aws4_request');

      final signature = Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).toString();

      final authHeader = 'AWS4-HMAC-SHA256 '
          'Credential=$accessKey/$credentialScope, '
          'SignedHeaders=$signedHeaders, '
          'Signature=$signature';

      final deleteUrl = 'https://$host$canonicalUri';

      final res = await http.delete(
        Uri.parse(deleteUrl),
        headers: {
          'Host': host,
          'x-amz-date': amzDate,
          'x-amz-content-sha256': payloadHash,
          'Authorization': authHeader,
        },
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        debugPrint('Cloudflare R2 delete success: $publicUrl');
        return true;
      } else {
        debugPrint('Cloudflare R2 delete failed [${res.statusCode}]: ${res.body}');
        return false;
      }
    } catch (e, st) {
      ErrorHandler.log('CloudflareR2Service.deleteByUrl', e, st);
      return false;
    }
  }
}

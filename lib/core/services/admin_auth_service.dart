import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'fcm_direct_service.dart'; // To access FcmConfig

class AdminAuthService {
  AdminAuthService._();
  static final AdminAuthService instance = AdminAuthService._();

  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  // نطاق الصلاحيات الخاص بـ Firebase Auth
  static const _scope = 'https://www.googleapis.com/auth/identitytoolkit';

  String? _cachedToken;
  DateTime? _tokenExpiry;

  Future<String> _getAccessToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken!;
    }

    final now = DateTime.now();
    final token = await compute(_signJwt, {
      'privateKey': FcmConfig.privateKey,
      'payload': {
        'iss': FcmConfig.clientEmail,
        'scope': _scope,
        'aud': _tokenEndpoint,
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'exp': (now.millisecondsSinceEpoch ~/ 1000) + 3600,
      },
    });

    final response = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': token,
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      debugPrint('❌ Auth Token Request Failed: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to get Auth access token');
    }

    final data = jsonDecode(response.body);
    _cachedToken = data['access_token'] as String;
    _tokenExpiry = now.add(const Duration(minutes: 55));
    return _cachedToken!;
  }

  Future<bool> updateUserPassword(String uid, String newPassword) async {
    try {
      final accessToken = await _getAccessToken();
      
      final payload = {
        'localId': uid,
        'password': newPassword,
      };

      final response = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/projects/${FcmConfig.projectId}/accounts:update'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint('✅ User password updated successfully for UID: $uid');
        return true;
      } else {
        debugPrint('❌ Failed to update password: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('🚨 Error updating password: $e');
      return false;
    }
  }
}

String _signJwt(Map<String, dynamic> params) {
  final jwt = JWT(params['payload']);
  return jwt.sign(
    RSAPrivateKey(params['privateKey']),
    algorithm: JWTAlgorithm.RS256,
  );
}

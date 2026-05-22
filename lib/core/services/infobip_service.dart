import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class InfobipService {
  // TODO: Add your Infobip credentials here
  static const String baseUrl = 'https://2yj1kl.api.infobip.com'; // قم بتعديل الرابط الأساسي لحسابك
  static const String apiKey = '0b9a0ed482add2633f8d93c1235b6fba-4ac2ae88-fe42-488b-aeb2-1504e77c77cd';
  static const String appId = 'E792E5B6609B1678A00CE512A25A5CD2';
  static const String messageId = '98AB55AB5B9164EBBADB25D3E264F1CD';

  /// طلب إرسال رمز التحقق عبر خدمة Infobip 2FA
  static Future<String?> sendVerifyOtp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('$baseUrl/2fa/2/pin');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'App $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'applicationId': appId,
          'messageId': messageId,
          'from': 'Aamal',
          'to': cleanPhone,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Infobip Verify OTP Sent Successfully');
        debugPrint('Infobip Response: ${response.body}');
        final data = jsonDecode(response.body);
        return data['pinId'];
      } else {
        debugPrint('Failed to send Infobip Verify OTP: ${response.statusCode}');
        debugPrint(response.body);
        return null;
      }
    } catch (e) {
      debugPrint('Exception in sendVerifyOtp (Infobip): $e');
      return null;
    }
  }

  /// التحقق من صحة الكود المُدخل عبر خدمة Infobip 2FA
  static Future<bool> checkVerifyOtp(String pinId, String code) async {
    final url = Uri.parse('$baseUrl/2fa/2/pin/$pinId/verify');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'App $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'pin': code,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['verified'] == true;
      } else {
        debugPrint('Failed to verify OTP with Infobip: ${response.statusCode}');
        debugPrint(response.body);
        return false;
      }
    } catch (e) {
      debugPrint('Exception in checkVerifyOtp (Infobip): $e');
      return false;
    }
  }
}

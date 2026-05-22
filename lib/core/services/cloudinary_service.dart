import 'dart:io';
import 'dart:convert';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  final String cloudName = 'dl6vgq6r9';
  final String apiKey = '437334944735157';
  final String apiSecret = 'y4GD91jOsNBKmO2UTzfYaSL5ao4';
  
  // إعداد بيانات Cloudinary الخاصة بك
  late final CloudinaryPublic cloudinary;

  CloudinaryService() {
    cloudinary = CloudinaryPublic(cloudName, 'cgdbmald', cache: false);
  }

  /// دالة لرفع الصورة وإرجاع الرابط الآمن (secureUrl)
  Future<String?> uploadImage(File imageFile) async {
    try {
      print('=== بدء عملية الرفع إلى Cloudinary ===');
      print('مسار الملف: ${imageFile.path}');
      
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      ).timeout(const Duration(seconds: 20)); // حد أقصى للوقت لتجنب التعليق
      
      print('=== تم الرفع بنجاح ===');
      print('الرابط: ${response.secureUrl}');
      return response.secureUrl;
    } on CloudinaryException catch (e) {
      print('Cloudinary Error: ${e.message}');
      print('Cloudinary Error Request: ${e.request}');
      throw Exception('فشل رفع الصورة على Cloudinary: ${e.message}');
    } catch (e) {
      print('Unknown Error: $e');
      throw Exception('حدث خطأ غير متوقع أثناء عملية الرفع: تأكد من اتصالك بالإنترنت ($e)');
    }
  }

  /// دالة لاستخراج public_id من الرابط
  String? _extractPublicId(String url) {
    try {
      const uploadStr = '/upload/';
      final uploadIndex = url.indexOf(uploadStr);
      if (uploadIndex == -1) return null;
      
      String path = url.substring(uploadIndex + uploadStr.length);
      
      // إزالة رقم النسخة مثل v1234567890/
      final RegExp versionRegExp = RegExp(r'^v\d+/');
      path = path.replaceFirst(versionRegExp, '');
      
      // إزالة الامتداد مثل .jpg
      final extensionIndex = path.lastIndexOf('.');
      if (extensionIndex != -1) {
        path = path.substring(0, extensionIndex);
      }
      return path;
    } catch (e) {
      return null;
    }
  }

  /// دالة لحذف الصورة باستخدام REST API
  Future<bool> deleteImage(String secureUrl) async {
    try {
      final publicId = _extractPublicId(secureUrl);
      if (publicId == null) return false;

      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      
      // إنشاء التوقيع الرقمي (Signature) للطلب
      final strToSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
      final bytes = utf8.encode(strToSign);
      final digest = sha1.convert(bytes);
      final signature = digest.toString();

      final response = await http.post(
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy'),
        body: {
          'public_id': publicId,
          'timestamp': timestamp,
          'api_key': apiKey,
          'signature': signature,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('تم حذف الصورة من Cloudinary بنجاح: $secureUrl');
        return true;
      } else {
        print('فشل حذف الصورة من Cloudinary: ${response.body}');
        return false;
      }
    } catch (e) {
      print('حدث خطأ أثناء محاولة حذف الصورة: $e');
      return false;
    }
  }
}

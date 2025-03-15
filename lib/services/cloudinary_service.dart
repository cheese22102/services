import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/config/constants.dart';

class CloudinaryService {
  static Future<List<String>> uploadImages(List<File> images) async {
    final List<String> imageUrls = [];
    
    try {
      for (final image in images) {
        final url = await _uploadImage(image);
        if (url != null) imageUrls.add(url);
      }
      return imageUrls;
    } catch (e) {
      throw Exception('Erreur de téléchargement des images: $e');
    }
  }

  static Future<String?> _uploadImage(File imageFile) async {
    const url = "https://api.cloudinary.com/v1_1/${AppConstants.cloudName}/image/upload";
    
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['upload_preset'] = AppConstants.uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonData['secure_url'] as String;
      }
      return null;
    } catch (e) {
      print('Erreur Cloudinary: $e');
      return null;
    }
  }

  static Future<void> deleteImage(String publicId) async {
    // Implémentez la suppression si nécessaire
  }
}
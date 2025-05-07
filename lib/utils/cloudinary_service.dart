import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // Cloudinary config
  static const String cloudName = "dfk7mskxv";
  static const String uploadPreset = "plateforme_service";
  
  // Upload a single image to Cloudinary
  static Future<String?> uploadImage(File imageFile) async {
    return await _uploadImageToCloudinary(imageFile);
  }
  
  // Upload multiple images to Cloudinary
  static Future<List<String>> uploadImages(List<File> imageFiles) async {
    List<String> imageUrls = [];
    
    for (var image in imageFiles) {
      String? url = await _uploadImageToCloudinary(image);
      if (url != null) {
        imageUrls.add(url);
      }
    }
    
    return imageUrls;
  }
  
  // Private method to handle the actual upload
  static Future<String?> _uploadImageToCloudinary(File imageFile) async {
    final url = "https://api.cloudinary.com/v1_1/$cloudName/image/upload";
    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonData = json.decode(responseData);
        return jsonData['secure_url'];
      } else {
        throw Exception("Upload failed. Code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }
}
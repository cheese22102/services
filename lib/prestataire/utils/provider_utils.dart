import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

class ProviderUtils {
  static const String cloudName = "dfk7mskxv";
  static const String uploadPreset = "plateforme_service";
  
  // Upload file to Cloudinary
  static Future<String?> uploadFileToCloudinary(File file) async {
    final url = "https://api.cloudinary.com/v1_1/$cloudName/image/upload";
    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonData = json.decode(responseData);
        return jsonData['secure_url'];
      }
    } catch (e) {
      print('Erreur upload: $e');
    }
    return null;
  }
  
  // Get address from coordinates
  static Future<String> getAddressFromCoordinates(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}'
          .replaceAll(RegExp(r', ,'), ',')
          .replaceAll(RegExp(r'^, |, $'), '');
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return '';
  }
  
  // Time utilities
  static TimeOfDay parseTimeString(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
  
  static double calculateHoursDifference(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return (endMinutes - startMinutes) / 60;
  }
  
  // Initialize working days and hours
  static Map<String, bool> initializeWorkingDays() {
    return {
      'monday': false,
      'tuesday': false,
      'wednesday': false,
      'thursday': false,
      'friday': false,
      'saturday': false,
      'sunday': false,
    };
  }
  
  static Map<String, Map<String, String>> initializeWorkingHours() {
    final Map<String, Map<String, String>> hours = {};
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    
    for (var day in days) {
      hours[day] = {'start': '00:00', 'end': '00:00'};
    }
    
    return hours;
  }
  
  static Map<String, String> getDayNames() {
    return {
      'monday': 'Lundi',
      'tuesday': 'Mardi',
      'wednesday': 'Mercredi',
      'thursday': 'Jeudi',
      'friday': 'Vendredi',
      'saturday': 'Samedi',
      'sunday': 'Dimanche',
    };
  }
}
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ProviderUtils {
  // Get address from coordinates
  static Future<String> getAddressFromCoordinates(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
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
      'monday': true,
      'tuesday': true,
      'wednesday': true,
      'thursday': true,
      'friday': true,
      'saturday': false,
      'sunday': false,
    };
  }
  
  static Map<String, Map<String, String>> initializeWorkingHours() {
    final Map<String, Map<String, String>> hours = {};
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    
    for (var day in days) {
      hours[day] = {'start': '08:00', 'end': '18:00'};
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

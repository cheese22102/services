import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class ProviderFinderService {
  // Upload images to cloud storage
  static Future<List<String>> uploadImages(List<File> images) async {
    List<String> imageUrls = [];
    
    if (images.isEmpty) {
      return imageUrls;
    }
    
    for (final image in images) {
      final url = await _uploadImageToCloudinary(image);
      if (url != null) {
        imageUrls.add(url);
      }
    }
    
    return imageUrls;
  }
  
  // Upload a single image to Cloudinary
  static Future<String?> _uploadImageToCloudinary(File imageFile) async {
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/your-cloud-name/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = 'your-upload-preset'
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonData = jsonDecode(responseString);
        return jsonData['secure_url'];
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }
  
  // Get current user data
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return null;
      }
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        return null;
      }
      
      return {
        'id': user.uid,
        'name': userDoc.data()?['name'] ?? 'Client',
        ...userDoc.data() ?? {},
      };
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }
  
  // Create a service request and navigate to results
  static Future<void> createServiceRequest({
    required String service,
    required String serviceId,
    required String description,
    required LatLng location,
    required String address,
    required List<String> imageUrls,
    required DateTime preferredDateTime,
    required bool isImmediate,
    required BuildContext context,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      // Get current user data
      final userData = await getCurrentUserData();
      if (userData == null) {
        onError('Veuillez vous connecter pour demander un service');
        return;
      }
      
      // Create service request in Firestore
      final requestData = {
        'clientId': userData['id'],
        'clientName': userData['name'],
        'service': service,
        'serviceId': serviceId,
        'description': description,
        'location': GeoPoint(location.latitude, location.longitude),
        'address': address,
        'images': imageUrls,
        'preferredDate': Timestamp.fromDate(preferredDateTime),
        'isImmediate': isImmediate,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      final requestRef = await FirebaseFirestore.instance
          .collection('serviceRequests')
          .add(requestData);
      
      // Update the request with its ID
      await requestRef.update({'id': requestRef.id});
      
      onSuccess(requestRef.id);
    } catch (e) {
      debugPrint('Error creating service request: $e');
      onError('Erreur: $e');
    }
  }
  
  // Find providers for a service request
  static Future<List<Map<String, dynamic>>> findProvidersForService(String serviceId) async {
    try {
      // Query providers who offer this service
      final providersSnapshot = await FirebaseFirestore.instance
          .collection('providers')
          .where('services', arrayContains: serviceId)
          .where('status', isEqualTo: 'active')
          .where('isVerified', isEqualTo: true)
          .get();
      
      List<Map<String, dynamic>> providers = [];
      
      for (final doc in providersSnapshot.docs) {
        final providerId = doc.id;
        
        // Get provider's ratings from provider_reviews collection
        final reviewsQuery = await FirebaseFirestore.instance
            .collection('provider_reviews')
            .where('providerId', isEqualTo: providerId)
            .get();
        
        // Calculate average rating
        double averageRating = 0;
        int totalReviews = reviewsQuery.docs.length;
        
        if (totalReviews > 0) {
          double sum = 0;
          for (final review in reviewsQuery.docs) {
            sum += (review.data()['rating'] as num).toDouble();
          }
          averageRating = sum / totalReviews;
        }
        
        // Add provider with calculated rating
        providers.add({
          'id': providerId,
          'name': doc.data()['name'] ?? doc.data()['professionalEmail'] ?? 'Prestataire',
          'rating': averageRating,
          'reviewCount': totalReviews,
          'completedJobs': doc.data()['completedServices'] ?? 0,
          'profileImage': doc.data()['profileImage'] ?? '',
          'bio': doc.data()['bio'] ?? 'Aucune description disponible',
          'hourlyRate': doc.data()['rateRange'] != null ? 
              (doc.data()['rateRange']['min'] as num).toDouble() : 0.0,
          'maxRate': doc.data()['rateRange'] != null ? 
              (doc.data()['rateRange']['max'] as num).toDouble() : 0.0,
          'workingDays': doc.data()['workingDays'] ?? {},
          'workingHours': doc.data()['workingHours'] ?? {},
          'exactLocation': doc.data()['exactLocation'],
          'isAvailable': doc.data()['isAvailable'] ?? false,
          'services': (doc.data()['services'] as List<dynamic>?)?.cast<String>() ?? [],
          ...doc.data(),
        });
      }
      
      return providers;
    } catch (e) {
      debugPrint('Error finding providers: $e');
      return [];
    }
  }
  
  // Find best providers for a service request with more detailed matching
  static Future<List<Map<String, dynamic>>> findBestProvidersForRequest({
    required String serviceId,
    required LatLng clientLocation,
    required DateTime preferredDateTime,
    required bool isImmediate,
  }) async {
    try {
      debugPrint('Finding providers for service ID: $serviceId');
      
      // Get all providers first
      final providersSnapshot = await FirebaseFirestore.instance
          .collection('providers')
          .get();
      
      debugPrint('Total providers found: ${providersSnapshot.docs.length}');
      
      // List to store providers with their calculated scores
      List<Map<String, dynamic>> scoredProviders = [];

      // Process each provider
      for (final doc in providersSnapshot.docs) {
        final data = doc.data();
        final providerId = doc.id;
        
        debugPrint('Evaluating provider: $providerId');
        
        // Check basic eligibility criteria
        final services = (data['services'] as List?)?.cast<String>() ?? [];
        final status = data['status'] as String?;
        final isVerified = data['isVerified'] as bool?;

        // Skip providers that don't meet basic criteria
        if (!services.contains(serviceId)) {
          debugPrint('- Provider does not offer this service');
          continue;
        }
        
        if (status != 'active') {
          debugPrint('- Provider is not active');
          continue;
        }
        
        if (isVerified != true) {
          debugPrint('- Provider is not verified');
          continue;
        }
        
        debugPrint('- Provider meets basic criteria');

        // Calculate distance score (30% of total)
        double distanceScore = 0.0;
        double distance = 0.0;
        final providerLocation = data['exactLocation'];
        if (providerLocation != null) {
          distance = Geolocator.distanceBetween(
            clientLocation.latitude,
            clientLocation.longitude,
            providerLocation['latitude'],
            providerLocation['longitude'],
          ) / 1000; // Convert to km
          
          // Closer providers get higher scores (max 30 points)
          distanceScore = 30 * (1 - (distance.clamp(0, 30) / 30));
          debugPrint('- Distance: ${distance.toStringAsFixed(2)} km, Score: ${distanceScore.toStringAsFixed(2)}/30');
        } else {
          debugPrint('- No location data available');
        }

        // Calculate rating score (25% of total)
        double ratingScore = 0.0;
        double rating = 0.0;
        final reviews = await FirebaseFirestore.instance
            .collection('provider_reviews')
            .where('providerId', isEqualTo: providerId)
            .get();
        
        if (reviews.docs.isNotEmpty) {
          rating = reviews.docs.fold(0.0, (sum, doc) => 
            sum + (doc.data()['rating'] as num).toDouble()) / reviews.docs.length;
          
          // Higher ratings get higher scores (max 25 points)
          ratingScore = 25 * (rating / 5.0);
          debugPrint('- Rating: ${rating.toStringAsFixed(2)}/5, Score: ${ratingScore.toStringAsFixed(2)}/25');
        } else {
          // Default rating score for new providers
          ratingScore = 12.5; // 50% of max rating score
          debugPrint('- No ratings yet, default score: ${ratingScore.toStringAsFixed(2)}/25');
        }

        // Calculate experience score (20% of total)
        final completedJobs = data['completedServices'] ?? 0;
        // More completed jobs get higher scores (max 20 points)
        final experienceScore = 20 * ((completedJobs.clamp(0, 50) as num) / 50);
        debugPrint('- Completed jobs: $completedJobs, Score: ${experienceScore.toStringAsFixed(2)}/20');

        // Calculate availability score (15% of total)
        double availabilityScore = 0.0;
        bool isAvailable = false;
        
        if (data['workingDays'] != null && data['workingHours'] != null) {
          isAvailable = await _isProviderAvailable(
            data,
            preferredDateTime,
            isImmediate,
            clientLocation,
            providerLocation,
          );
          
          // Available providers get full points
          availabilityScore = isAvailable ? 15.0 : 0.0;
          debugPrint('- Available for requested time: $isAvailable, Score: ${availabilityScore.toStringAsFixed(2)}/15');
        } else {
          // Default availability score if no schedule data
          availabilityScore = 7.5; // 50% of max availability score
          debugPrint('- No availability data, default score: ${availabilityScore.toStringAsFixed(2)}/15');
        }

        // Calculate price score (10% of total)
        double priceScore = 0.0;
        final minRate = data['rateRange']?['min'] as num? ?? 0.0;
        
        // Lower rates get higher scores (max 10 points)
        // Assuming rates range from 0-200, adjust as needed
        priceScore = 10 * (1 - (minRate.clamp(0, 200) / 200));
        debugPrint('- Hourly rate: $minRate, Score: ${priceScore.toStringAsFixed(2)}/10');

        // Calculate total score (out of 100)
        final totalScore = distanceScore + ratingScore + experienceScore + availabilityScore + priceScore;
        debugPrint('- TOTAL SCORE: ${totalScore.toStringAsFixed(2)}/100');

        // Add provider to scored list
        scoredProviders.add({
          'id': providerId,
          'name': data['name'] ?? data['professionalEmail'] ?? 'Prestataire',
          'profileImage': data['profileImage'] ?? '',
          'rating': rating,
          'completedJobs': completedJobs,
          'hourlyRate': minRate.toDouble(),
          'maxRate': (data['rateRange']?['max'] as num?)?.toDouble() ?? 0.0,
          'distance': distance,
          'isAvailable': isAvailable,
          'score': totalScore,
          'bio': data['bio'] ?? 'Aucune description disponible',
          'workingDays': data['workingDays'] ?? {},
          'workingHours': data['workingHours'] ?? {},
        });
      }

      debugPrint('Found ${scoredProviders.length} eligible providers');
      
      // Sort providers by score (highest first)
      scoredProviders.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
      
      // Take top 3 providers
      final topProviders = scoredProviders.take(3).toList();
      debugPrint('Selected top ${topProviders.length} providers');
      
      // Log the selected providers
      for (int i = 0; i < topProviders.length; i++) {
        debugPrint('Top ${i+1}: ${topProviders[i]['name']} (Score: ${topProviders[i]['score']})');
      }

      return topProviders;
    } catch (e) {
      debugPrint('Error in findBestProvidersForRequest: $e');
      return [];
    }
  }

  // Add this new helper method

  // Helper method: Availability check
  static Future<bool> _isProviderAvailable(
    Map<String, dynamic> data,
    DateTime preferredDateTime,
    bool isImmediate,
    LatLng clientLocation,
    Map<String, dynamic>? exactLocation,
  ) async {
    if (!(data['isAvailable'] ?? false)) return false;
    
    if (isImmediate) {
      // Check current location availability
      return _checkCurrentAvailability(data);
    } else {
      // Check scheduled availability
      return _checkScheduledAvailability(data, preferredDateTime);
    }
  }

  // Helper method: Current availability
  static bool _checkCurrentAvailability(Map<String, dynamic> data) {
    final workingDays = data['workingDays'] as Map<String, dynamic>?;
    final now = DateTime.now();
    final currentDay = _getDayName(now.weekday).toLowerCase();
    
    return workingDays?[currentDay] == true &&
        _isWithinWorkingHours(data, now);
  }

  // Helper method: Scheduled availability
  static bool _checkScheduledAvailability(
    Map<String, dynamic> data,
    DateTime preferredDateTime,
  ) {
    final workingDays = data['workingDays'] as Map<String, dynamic>?;
    final dayName = _getDayName(preferredDateTime.weekday).toLowerCase();
    
    return workingDays?[dayName] == true &&
        _isWithinWorkingHours(data, preferredDateTime);
  }

  // Helper method: Distance calculation

  // Helper method: Build provider data

  // Helper method to get day name from weekday number
  static String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return 'monday';
    }
  }
  
  // Helper method to parse time string (HH:MM)
  static TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
    return const TimeOfDay(hour: 0, minute: 0);
  }
  
  // Get service details by ID
  static Future<Map<String, dynamic>?> getServiceDetails(String serviceId) async {
    try {
      final serviceDoc = await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .get();
      
      if (!serviceDoc.exists) {
        return null;
      }
      
      return {
        'id': serviceDoc.id,
        ...serviceDoc.data() ?? {},
      };
    } catch (e) {
      debugPrint('Error getting service details: $e');
      return null;
    }
  }


// Add missing helper method
static bool _isWithinWorkingHours(Map<String, dynamic> data, DateTime date) {
  final workingHours = data['workingHours'] as Map<String, dynamic>?;
  final dayName = _getDayName(date.weekday).toLowerCase();
  
  if (workingHours == null) return false;
  
  final hours = workingHours[dayName] as Map<String, dynamic>?;
  if (hours == null) return false;

  final startTime = _parseTimeString(hours['start']?.toString() ?? '00:00');
  final endTime = _parseTimeString(hours['end']?.toString() ?? '00:00');
  final requestTime = TimeOfDay.fromDateTime(date);
  
  final startMinutes = startTime.hour * 60 + startTime.minute;
  final endMinutes = endTime.hour * 60 + endTime.minute;
  final requestMinutes = requestTime.hour * 60 + requestTime.minute;
  
  return requestMinutes >= startMinutes && requestMinutes <= endMinutes;
}
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit a provider rating
  static Future<void> rateProvider({
    required String providerId,
    required double qualityRating,
    required double timelinessRating,
    required double priceRating,
    String? comment,
    String? reservationId,
  }) async {
    try {
      // Get the current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Get the provider document
      final providerDoc = await _firestore.collection('providers').doc(providerId).get();
      
      if (!providerDoc.exists) {
        throw Exception('Prestataire introuvable');
      }
      
      final providerData = providerDoc.data()!;
      
      // Calculate new ratings
      // Quality rating
      final qualityTotal = ((providerData['ratings']?['quality']?['total'] ?? 0.0) as num).toDouble() + qualityRating;
      final qualityCount = ((providerData['ratings']?['quality']?['count'] ?? 0) as num).toInt() + 1;
      final qualityAverage = qualityTotal / qualityCount;
      
      // Timeliness rating
      final timelinessTotal = ((providerData['ratings']?['timeliness']?['total'] ?? 0.0) as num).toDouble() + timelinessRating;
      final timelinessCount = ((providerData['ratings']?['timeliness']?['count'] ?? 0) as num).toInt() + 1;
      final timelinessAverage = timelinessTotal / timelinessCount;
      
      // Price rating
      final priceTotal = ((providerData['ratings']?['price']?['total'] ?? 0.0) as num).toDouble() + priceRating;
      final priceCount = ((providerData['ratings']?['price']?['count'] ?? 0) as num).toInt() + 1;
      final priceAverage = priceTotal / priceCount;
      
      // Overall rating (average of all three)
      final overallAverage = (qualityAverage + timelinessAverage + priceAverage) / 3;
      
      // Update the provider document with the new ratings
      await _firestore.collection('providers').doc(providerId).update({
        'ratings.quality.total': qualityTotal,
        'ratings.quality.count': qualityCount,
        'ratings.quality.average': qualityAverage,
        
        'ratings.timeliness.total': timelinessTotal,
        'ratings.timeliness.count': timelinessCount,
        'ratings.timeliness.average': timelinessAverage,
        
        'ratings.price.total': priceTotal,
        'ratings.price.count': priceCount,
        'ratings.price.average': priceAverage,
        
        'ratings.overall': overallAverage,
        'reviewCount': FieldValue.increment(1),
      });
      
      // Store the review in a separate reviews collection
      await _firestore.collection('provider_reviews').add({
        'providerId': providerId,
        'userId': currentUser.uid,
        'quality': qualityRating,
        'timeliness': timelinessRating,
        'price': priceRating,
        'comment': comment ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'reservationId': reservationId ?? '',
      });
    } catch (e) {
      rethrow;
    }
  }
}
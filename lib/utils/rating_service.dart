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
      
    
      // Get current ratings from the ratings subcollection
      final ratingsDoc = await _firestore
          .collection('providers')
          .doc(providerId)
          .collection('ratings')
          .doc('stats')
          .get();
      
      Map<String, dynamic> ratingsData;
      if (ratingsDoc.exists) {
        ratingsData = ratingsDoc.data()!;
      } else {
        // Initialize ratings data if it doesn't exist
        ratingsData = {
          'quality': {
            'total': 0.0,
            'count': 0,
            'average': 0.0,
          },
          'timeliness': {
            'total': 0.0,
            'count': 0,
            'average': 0.0,
          },
          'price': {
            'total': 0.0,
            'count': 0,
            'average': 0.0,
          },
          'reviewCount': 0,
        };
      }
      
      // Calculate new ratings
      // Quality rating
      final qualityTotal = ((ratingsData['quality']?['total'] ?? 0.0) as num).toDouble() + qualityRating;
      final qualityCount = ((ratingsData['quality']?['count'] ?? 0) as num).toInt() + 1;
      final qualityAverage = qualityTotal / qualityCount;
      
      // Timeliness rating
      final timelinessTotal = ((ratingsData['timeliness']?['total'] ?? 0.0) as num).toDouble() + timelinessRating;
      final timelinessCount = ((ratingsData['timeliness']?['count'] ?? 0) as num).toInt() + 1;
      final timelinessAverage = timelinessTotal / timelinessCount;
      
      // Price rating
      final priceTotal = ((ratingsData['price']?['total'] ?? 0.0) as num).toDouble() + priceRating;
      final priceCount = ((ratingsData['price']?['count'] ?? 0) as num).toInt() + 1;
      final priceAverage = priceTotal / priceCount;
      
      // Overall rating (average of all three)
      final overallAverage = (qualityAverage + timelinessAverage + priceAverage) / 3;
      final reviewCount = ((ratingsData['reviewCount'] ?? 0) as num).toInt() + 1;
      
      // Update the ratings subcollection document with detailed ratings
      await _firestore.collection('providers').doc(providerId).collection('ratings').doc('stats').set({
        'quality': {
          'total': qualityTotal,
          'count': qualityCount,
          'average': qualityAverage,
        },
        'timeliness': {
          'total': timelinessTotal,
          'count': timelinessCount,
          'average': timelinessAverage,
        },
        'price': {
          'total': priceTotal,
          'count': priceCount,
          'average': priceAverage,
        },
        'reviewCount': reviewCount,
      });
      
      // Update only the overall rating in the main provider document
      await _firestore.collection('providers').doc(providerId).update({
        'rating': overallAverage,
        'reviewCount': reviewCount,
      });
      
      // Store the individual review in the ratings subcollection
      await _firestore.collection('providers')
          .doc(providerId)
          .collection('ratings')
          .doc('reviews')
          .collection('items')
          .add({
        'userId': currentUser.uid,
        'quality': qualityRating,
        'timeliness': timelinessRating,
        'price': priceRating,
        'comment': comment ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'reservationId': reservationId ?? '',
      });
      
      // Also fetch the user's name to store with the review
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final userName = '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}'.trim();
        
        // Update the review with the user's name
        final reviewsQuery = await _firestore.collection('providers')
            .doc(providerId)
            .collection('ratings')
            .doc('reviews')
            .collection('items')
            .where('userId', isEqualTo: currentUser.uid)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
            
        if (reviewsQuery.docs.isNotEmpty) {
          await reviewsQuery.docs.first.reference.update({
            'userName': userName,
          });
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}
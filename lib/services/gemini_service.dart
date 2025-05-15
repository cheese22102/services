import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const String _apiKey = 'AIzaSyANrdPSY-DNNnzRSwzLrcarTafLJvpAX4s'; // Your API key
  late final GenerativeModel _model;
  
  // Application context to help the model understand what it should focus on
  static const String _appContext = '''
    Vous êtes un assistant IA pour une application de services à domicile et une marketplace en Tunisie.
    
    STRUCTURE DE L'APPLICATION:
    
    1. PAGES PRINCIPALES:
       - Page d'accueil (/clientHome): Affiche les services populaires et les prestataires recommandés
       - Services (/clientHome/all-services): Liste tous les services disponibles
       - Marketplace (/clientHome/marketplace): Permet d'acheter/vendre des produits liés à l'entretien de la maison
       - Messages (/clientHome/marketplace/chat): Affiche toutes les conversations avec les prestataires et vendeurs
       - Assistant IA (/clientHome/chatbot): Vous êtes ici, pour aider les utilisateurs
    
    2. FONCTIONNALITÉS PRINCIPALES:
       - Recherche de prestataires par service
       - Réservation d'interventions à domicile
       - Achat et vente de produits sur la marketplace
       - Messagerie avec les prestataires et vendeurs
       - Notifications pour les réservations et messages
       - Favoris pour enregistrer vos prestataires préférés
       - Système d'évaluation des prestataires
    
    3. NAVIGATION:
       - La barre de navigation en bas permet de naviguer entre les pages principales
       - Pour réserver un service: Accueil > Services > Sélectionner un service > Choisir un prestataire > Réserver
       - Pour contacter un prestataire: Profil du prestataire > Bouton "Contacter"
       - Pour acheter un produit: Marketplace > Détails du produit > Contacter le vendeur
       - Pour publier une annonce: Marketplace > Bouton "+" > Remplir le formulaire
       - Pour voir vos réservations: Menu latéral > Mes réservations
    
    4. TYPES D'UTILISATEURS:
       - Clients: Recherchent et réservent des services, achètent des produits
       - Prestataires: Offrent des services à domicile, gèrent leurs réservations
       - Vendeurs: Publient des annonces de produits sur la marketplace
       - Administrateurs: Gèrent la plateforme et valident les prestataires
    
    Répondez uniquement aux questions liées à ces fonctionnalités et à l'utilisation de l'application.
    Si l'utilisateur pose une question non liée à l'application ou aux services à domicile, 
    répondez poliment que vous êtes spécialisé dans l'assistance pour cette application de services à domicile
    et proposez de l'aider sur ce sujet.
  ''';
  
  // Chat history to maintain context
  final List<Content> _chatHistory = [];
  
  // Cache for storing responses to common queries
  static final Map<String, _CachedResponse> _responseCache = {};
  
  // Rate limiting variables
  static const int _maxRequestsPerMinute = 10;
  static final List<DateTime> _requestTimestamps = [];
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  
  // Cache expiration time (24 hours)
  static const Duration _cacheExpiration = Duration(hours: 24);
  
  GeminiService() {
    try {
      // Using Gemini 2.0 Flash-Lite model
      _model = GenerativeModel(
        model: 'gemini-1.5-flash', // Updated to Flash-Lite model
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024, // Adjusted for Flash-Lite model
        ),
        // Safety settings are applied directly to the model, not in GenerationConfig
        safetySettings: [
          SafetySetting(
            HarmCategory.dangerousContent,
            HarmBlockThreshold.medium,
          ),
          SafetySetting(
            HarmCategory.harassment,
            HarmBlockThreshold.medium,
          ),
          SafetySetting(
            HarmCategory.hateSpeech,
            HarmBlockThreshold.medium,
          ),
        ],
      );
      _loadCacheFromStorage();
    } catch (e) {
      print('Error initializing Gemini model: $e');
    }
  }
  
  // Load cache from SharedPreferences
  Future<void> _loadCacheFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cacheJson = prefs.getString('gemini_response_cache');
      
      if (cacheJson != null) {
        final Map<String, dynamic> cacheData = jsonDecode(cacheJson);
        final now = DateTime.now();
        
        cacheData.forEach((key, value) {
          final cachedResponse = _CachedResponse.fromJson(value);
          // Only load non-expired cache entries
          if (now.difference(cachedResponse.timestamp) <= _cacheExpiration) {
            _responseCache[key] = cachedResponse;
          }
        });
      }
    } catch (e) {
      print('Error loading cache: $e');
    }
  }
  
  // Save cache to SharedPreferences
  Future<void> _saveCacheToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> cacheData = {};
      
      _responseCache.forEach((key, value) {
        cacheData[key] = value.toJson();
      });
      
      await prefs.setString('gemini_response_cache', jsonEncode(cacheData));
    } catch (e) {
      print('Error saving cache: $e');
    }
  }
  
  // Check if rate limit is exceeded
  bool _isRateLimited() {
    final now = DateTime.now();
    
    // Remove timestamps older than the rate limit window
    _requestTimestamps.removeWhere(
      (timestamp) => now.difference(timestamp) > _rateLimitWindow
    );
    
    // Check if we've exceeded the maximum requests per minute
    return _requestTimestamps.length >= _maxRequestsPerMinute;
  }
  
  // Record a new request for rate limiting
  void _recordRequest() {
    _requestTimestamps.add(DateTime.now());
  }
  
  // Generate a cache key from the prompt
  String _generateCacheKey(String prompt) {
    // Simple normalization: lowercase and trim whitespace
    return prompt.toLowerCase().trim();
  }
  
  Future<String> generateResponse(String prompt) async {
    try {
      // Check rate limiting
      if (_isRateLimited()) {
        return "Désolé, vous avez atteint la limite de requêtes. Veuillez réessayer dans quelques instants.";
      }
      
      // Record this request for rate limiting
      _recordRequest();
      
      // Check cache for this prompt
      final cacheKey = _generateCacheKey(prompt);
      if (_responseCache.containsKey(cacheKey)) {
        final cachedResponse = _responseCache[cacheKey]!;
        final now = DateTime.now();
        
        // Return cached response if it's not expired
        if (now.difference(cachedResponse.timestamp) <= _cacheExpiration) {
          print('Using cached response for: $prompt');
          return cachedResponse.response;
        } else {
          // Remove expired cache entry
          _responseCache.remove(cacheKey);
        }
      }
      
      // Create content from prompt
      final userMessage = Content.text(prompt);
      
      // If chat history is empty, add the system context first
      if (_chatHistory.isEmpty) {
        _chatHistory.add(Content.text(_appContext));
      }
      
      // Add user message to history
      _chatHistory.add(userMessage);
      
      // Generate response using the model with chat history for context
      final response = await _model.generateContent(_chatHistory);
      
      if (response.candidates.isEmpty || 
          response.candidates.first.content.parts.isEmpty) {
        return "Je n'ai pas pu générer une réponse. Veuillez réessayer.";
      }
      
      // Extract text from response
      final part = response.candidates.first.content.parts.first;
      String responseText;
      
      if (part is TextPart) {
        responseText = part.text;
      } else {
        responseText = "Réponse reçue dans un format non textuel.";
      }
      
      // Add model response to chat history (for context in future exchanges)
      _chatHistory.add(response.candidates.first.content);
      
      // Limit history size to prevent token limits (keep last 10 exchanges)
      if (_chatHistory.length > 20) {
        // Always keep the system context (first message)
        final systemContext = _chatHistory.first;
        _chatHistory.removeRange(1, 3); // Remove oldest exchanges after system context
        _chatHistory[0] = systemContext;
      }
      
      // Cache the response
      _responseCache[cacheKey] = _CachedResponse(
        response: responseText,
        timestamp: DateTime.now(),
      );
      
      // Save updated cache to storage
      _saveCacheToStorage();
      
      return responseText;
    } catch (e) {
      print('Error with Gemini API: $e');
      // Fallback to direct API call if the package method fails
      try {
        return await _fallbackApiCall(prompt);
      } catch (fallbackError) {
        print('Fallback API call failed: $fallbackError');
        return "Erreur: Impossible de se connecter à l'API Gemini. Veuillez vérifier votre connexion internet.";
      }
    }
  }
  
  // Clear chat history (for new conversations)
  void clearChatHistory() {
    _chatHistory.clear();
  }
  
  // Clear response cache
  Future<void> clearCache() async {
    _responseCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('gemini_response_cache');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
  
  Future<String> _fallbackApiCall(String prompt) async {
    try {
      // Check rate limiting for fallback method too
      if (_isRateLimited()) {
        return "Désolé, vous avez atteint la limite de requêtes. Veuillez réessayer dans quelques instants.";
      }
      
      // Record this request for rate limiting
      _recordRequest();
      
      // Check cache for this prompt
      final cacheKey = _generateCacheKey(prompt);
      if (_responseCache.containsKey(cacheKey)) {
        final cachedResponse = _responseCache[cacheKey]!;
        final now = DateTime.now();
        
        // Return cached response if it's not expired
        if (now.difference(cachedResponse.timestamp) <= _cacheExpiration) {
          print('Using cached response for fallback: $prompt');
          return cachedResponse.response;
        } else {
          // Remove expired cache entry
          _responseCache.remove(cacheKey);
        }
      }
      
      final contextualPrompt = '''
$_appContext

Question de l'utilisateur: $prompt

Réponse (en français):
''';

      final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': contextualPrompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            }
          ]
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        try {
          final responseText = data['candidates'][0]['content']['parts'][0]['text'];
          
          // Cache the response
          _responseCache[cacheKey] = _CachedResponse(
            response: responseText,
            timestamp: DateTime.now(),
          );
          
          // Save updated cache to storage
          _saveCacheToStorage();
          
          return responseText;
        } catch (e) {
          print('Error parsing API response: $e');
          return "Réponse reçue mais format inattendu.";
        }
      } else {
        print('API request failed with status: ${response.statusCode}, body: ${response.body}');
        throw Exception('API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fallback API call: $e');
      throw e;
    }
  }
}

// Class to store cached responses with timestamps
class _CachedResponse {
  final String response;
  final DateTime timestamp;
  
  _CachedResponse({
    required this.response,
    required this.timestamp,
  });
  
  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'response': response,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  // Create from JSON
  factory _CachedResponse.fromJson(Map<String, dynamic> json) {
    return _CachedResponse(
      response: json['response'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
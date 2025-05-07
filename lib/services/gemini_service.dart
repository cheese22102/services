import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GeminiService {
  static const String _apiKey = 'AIzaSyDRjT9mNaWtP8rLZjFLgjyjYneMh4OABLg'; // Your API key
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
    
    3. NAVIGATION:
       - La barre de navigation en bas permet de naviguer entre les pages principales
       - Pour réserver un service: Accueil > Services > Sélectionner un service > Choisir un prestataire > Réserver
       - Pour contacter un prestataire: Profil du prestataire > Bouton "Contacter"
       - Pour acheter un produit: Marketplace > Détails du produit > Contacter le vendeur
       - Pour publier une annonce: Marketplace > Bouton "+" > Remplir le formulaire
    
    4. TYPES D'UTILISATEURS:
       - Clients: Recherchent et réservent des services, achètent des produits
       - Prestataires: Offrent des services à domicile, gèrent leurs réservations
       - Vendeurs: Publient des annonces de produits sur la marketplace
    
    Répondez uniquement aux questions liées à ces fonctionnalités et à l'utilisation de l'application.
    Si l'utilisateur pose une question non liée à l'application ou aux services à domicile, 
    répondez poliment que vous êtes spécialisé dans l'assistance pour cette application de services à domicile
    et proposez de l'aider sur ce sujet.
  ''';
  
  GeminiService() {
    // Using the latest model version available
    _model = GenerativeModel(
      model: 'gemini-1.5-pro', // Updated to the latest model version
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048, // Increased token limit
      ),
      // Safety settings are applied directly to the model, not in GenerationConfig
      safetySettings: [
        SafetySetting(
          HarmCategory.dangerousContent,
          HarmBlockThreshold.medium,
        ),
      ],
    );
  }
  
  Future<String> generateResponse(String prompt) async {
    try {
      // Create content from prompt with app context
      final contextualPrompt = '''
$_appContext

Question de l'utilisateur: $prompt

Réponse (en français):
''';
      
      final content = [Content.text(contextualPrompt)];
      
      // Generate response using the model
      final response = await _model.generateContent(content);
      
      if (response.candidates.isEmpty || 
          response.candidates.first.content.parts.isEmpty) {
        return "Je n'ai pas pu générer une réponse. Veuillez réessayer.";
      }
      
      // Extract text from response
      final part = response.candidates.first.content.parts.first;
      if (part is TextPart) {
        return part.text;
      } else {
        return "Réponse reçue dans un format non textuel.";
      }
    } catch (e) {
      // Fallback to direct API call if the package method fails
      try {
        return await _fallbackApiCall(prompt);
      } catch (fallbackError) {
        return "Erreur: Impossible de se connecter à l'API Gemini. Veuillez vérifier votre clé API et votre connexion internet.";
      }
    }
  }
  
  Future<String> _fallbackApiCall(String prompt) async {
    final contextualPrompt = '''
$_appContext

Question de l'utilisateur: $prompt

Réponse (en français):
''';

    final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=$_apiKey';
    
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
          'maxOutputTokens': 2048,
        },
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          }
        ]
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      try {
        return data['candidates'][0]['content']['parts'][0]['text'];
      } catch (e) {
        return "Réponse reçue mais format inattendu.";
      }
    } else {
      throw Exception('API request failed with status: ${response.statusCode}, body: ${response.body}');
    }
  }
}
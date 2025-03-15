import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_signup/login_page.dart';
import 'main.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  _TutorialScreenState createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': "Bienvenue sur notre plateforme",
      'body': "Découvrez une nouvelle façon de trouver et de proposer des services",
      'image': "assets/images/welcome.png"
    },
    {
      'title': "Services diversifiés", 
      'body': "Trouvez des professionnels qualifiés dans tous les domaines",
      'image': "assets/images/services.png"
    },
    {
      'title': "Gestion simplifiée",
      'body': "Planifiez et gérez vos rendez-vous en temps réel",
      'image': "assets/images/calendar.png"
    },
    {
      'title': "Sécurité garantie",
      'body': "Paiements sécurisés et profils vérifiés",
      'image': "assets/images/security.png"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) => _buildPage(_pages[index]),
            ),
          ),
          _buildIndicators(),
          _buildBottomButtons(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPage(Map<String, String> page) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(page['image']!, height: 250),
          const SizedBox(height: 40),
          Text(
            page['title']!,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            page['body']!,
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: _currentPage == index ? 20 : 10,
        height: 10,
        decoration: BoxDecoration(
          color: _currentPage == index 
              ? Theme.of(context).primaryColor 
              : Colors.grey,
          borderRadius: BorderRadius.circular(5),
        ),
      )),
    );
  }

  Widget _buildBottomButtons() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Bouton Précédent
        TextButton(
          onPressed: _currentPage > 0 
              ? () => _controller.previousPage(
                  duration: const Duration(milliseconds: 300), 
                  curve: Curves.easeInOut)
              : null,
          child: Text(
            'Précédent',
            style: TextStyle(color: Theme.of(context).primaryColor),
          ),
        ),

        // Bouton Suivant/Commencer
        _currentPage == _pages.length - 1
            ? ElevatedButton(
                onPressed: _completeTutorial,
                child: const Text('Commencer'),
              )
            : TextButton(
                onPressed: () => _controller.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut),
                child: Text(
                  'Suivant',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
      ],
    ),
  );
}

  void _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('firstLaunch', false);
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
    );
  }
}
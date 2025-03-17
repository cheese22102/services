import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../providers/theme_provider.dart';

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
      'body': "Trouvez et proposez des services facilement et en toute sécurité.",
      'image': "https://img.icons8.com/fluency/2x/services.png"
    },
    {
      'title': "Large choix de services",
      'body': "Accédez à une variété de services professionnels, du ménage à l’électricité.",
      'image': "https://img.icons8.com/color/2x/maintenance.png"
    },
    {
      'title': "Messagerie intégrée",
      'body': "Discutez directement avec les prestataires pour organiser vos services.",
      'image': "https://img.icons8.com/color/2x/chat.png"
    },
    {
      'title': "Notifications en temps réel",
      'body': "Recevez des alertes pour vos messages et demandes de service.",
      'image': "https://img.icons8.com/fluency/2x/appointment-reminders.png"
    },
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) => _buildPage(_pages[index], isDarkMode),
                ),
              ),
              _buildIndicators(),
              _buildBottomButtons(),
              const SizedBox(height: 20),
            ],
          ),
          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: _skipTutorial,
              child: Text(
                "Passer",
                style: TextStyle(fontSize: 16, color: Colors.blueAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(Map<String, String> page, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            child: Image.network(page['image']!, height: 250),
          ),
          const SizedBox(height: 40),
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: Text(
              page['title']!,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: Text(
              page['body']!,
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: _currentPage == index ? 20 : 10,
        height: 10,
        decoration: BoxDecoration(
          color: _currentPage == index ? Colors.blueAccent : Colors.grey,
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
          TextButton(
            onPressed: _currentPage > 0 
                ? () => _controller.previousPage(
                    duration: const Duration(milliseconds: 300), 
                    curve: Curves.easeInOut)
                : null,
            child: Text(
              'Précédent',
              style: TextStyle(color: Colors.blueAccent),
            ),
          ),
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
                    style: TextStyle(color: Colors.blueAccent),
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

  void _skipTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('firstLaunch', false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
    );
  }
}

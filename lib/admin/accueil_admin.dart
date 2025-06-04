import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import '../../utils/auth_helper.dart';
import '../front/sidebar.dart';
import '../front/app_colors.dart'; // Import AppColors for consistent theming

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    if (!mounted) return;
    await AuthHelper.checkUserRole(context, 'admin');
  }

  // Define a list of dashboard items
  final List<Map<String, dynamic>> _dashboardItems = [
    {
      'label': 'Gérer les Services',
      'icon': Icons.build,
      'route': '/admin/services',
    },
    {
      'label': 'Valider les Prestataires',
      'icon': Icons.person_add,
      'route': '/admin/providers',
    },
    {
      'label': 'Valider les Posts',
      'icon': Icons.check_circle,
      'route': '/admin/posts',
    },
    {
      'label': 'Gérer les Réclamations',
      'icon': Icons.report_problem,
      'route': '/admin/reclamations',
    },
    {
      'label': 'Gérer les Comptes',
      'icon': Icons.people,
      'route': '/admin/accounts',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;

    return Scaffold(
      drawer: const Sidebar(),
      appBar: AppBar(
        title: Text(
          'Accueil',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: isDarkMode ? AppColors.darkBackground : Colors.white,
        elevation: 4,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2, // Responsive grid
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.9, // Adjusted aspect ratio to give more vertical space
          ),
          itemCount: _dashboardItems.length,
          itemBuilder: (context, index) {
            final item = _dashboardItems[index];
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  context.push(item['route']);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item['icon'],
                        size: 48,
                        color: primaryColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item['label'],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2, // Allow text to wrap to two lines
                        overflow: TextOverflow.ellipsis, // Add ellipsis if still overflows
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MarketplaceBottomNav extends StatelessWidget {
  final int selectedIndex;

  const MarketplaceBottomNav({
    super.key,
    required this.selectedIndex,
  });

  Widget _buildNavButton(BuildContext context, IconData icon, Color color, String label, VoidCallback onPressed, {double size = 28}) {
    final bool isSelected = color == Theme.of(context).colorScheme.primary || 
                          color == Theme.of(context).primaryColor;
    
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: onPressed,
          child: SizedBox(
            height: 55,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: size,
                  color: color,
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: isSelected ? 17 : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isSelected ? 1.0 : 0.0,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/clientHome/marketplace');  // Changed from '/clientHome' to '/clientHome/marketplace'
        break;
      case 1:
        context.go('/clientHome/marketplace/favorites');
        break;
      case 2:
        context.go('/clientHome/marketplace/add');
        break;
      case 3:
        context.go('/clientHome/marketplace/my-products');
        break;
      case 4:
        context.go('/clientHome/marketplace/chat');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavButton(
            context,
            Icons.home_rounded,
            selectedIndex == 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            'Accueil',
            () => _onItemTapped(context, 0),
          ),
          _buildNavButton(
            context,
            Icons.favorite_rounded,
            selectedIndex == 1 ? Theme.of(context).primaryColor : Colors.grey,
            'Favoris',
            () => _onItemTapped(context, 1),
          ),
          _buildNavButton(
            context,
            Icons.add_circle_rounded,
            selectedIndex == 2 ? Theme.of(context).primaryColor : Colors.grey,
            'Ajouter',
            () => _onItemTapped(context, 2),
            size: 36,
          ),
          _buildNavButton(
            context,
            Icons.inventory_2_rounded,
            selectedIndex == 3 ? Theme.of(context).primaryColor : Colors.grey,
            'Mes Produits',
            () => _onItemTapped(context, 3),
          ),
          _buildNavButton(
            context,
            Icons.chat_rounded,
            selectedIndex == 4 ? Theme.of(context).primaryColor : Colors.grey,
            'Chat',
            () => _onItemTapped(context, 4),
          ),
        ],
      ),
    );
  }
}
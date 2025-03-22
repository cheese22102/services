import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:plateforme_services/marketplace/image_plein_ecran.dart';
import 'ajout_marketplace.dart'; // Page d'ajout de post
import 'details_post_page.dart'; // Page des détails du post
import '../chat/chat_list_screen.dart'; // Page de messagerie
import '/client_home_page.dart'; // Page d'accueil client
import 'package:plateforme_services/widgets/sidebar.dart'; // Votre sidebar
import '../widgets/zoom_product.dart'; // Le widget ZoomProduct
import 'mes_produits_page.dart';
import 'favoris_page.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  _MarketplacePageState createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  // Add this variable for selected index
  int _selectedIndex = 0;

  String searchQuery = '';

  // Variables de filtre
  String _filterCondition = 'All'; // "All", "Neuf", "Occasion"
  bool _sortByDateAsc = true; // true = date ascendante, false = descendante
  RangeValues _priceRange = const RangeValues(0, 100000);

  Stream<QuerySnapshot> _getMarketplacePosts() {
    return FirebaseFirestore.instance
        .collection('marketplace')
        .where('isValidated', isEqualTo: true)  // Only show validated posts
        .orderBy('createdAt', descending: !_sortByDateAsc)
        .snapshots();
  }

  // Ouvre le panneau de filtre
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        String localCondition = _filterCondition;
        bool localSortAsc = _sortByDateAsc;
        RangeValues localPriceRange = _priceRange;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Filtrer les posts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  // Tri par date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Tri par date :"),
                      DropdownButton<bool>(
                        value: localSortAsc,
                        items: const [
                          DropdownMenuItem(value: true, child: Text("Ascendant")),
                          DropdownMenuItem(value: false, child: Text("Descendant")),
                        ],
                        onChanged: (value) {
                          setModalState(() {
                            localSortAsc = value!;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Filtre par état
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text("État du produit:"),
                        const SizedBox(width: 16),
                        ChoiceChip(
                          label: const Text("Tous"),
                          selected: localCondition == 'All',
                          onSelected: (selected) {
                            setModalState(() {
                              localCondition = 'All';
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text("Neuf"),
                          selected: localCondition == 'Neuf',
                          onSelected: (selected) {
                            setModalState(() {
                              localCondition = 'Neuf';
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text("Occasion"),
                          selected: localCondition == 'Occasion',
                          onSelected: (selected) {
                            setModalState(() {
                              localCondition = 'Occasion';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filtre par intervalle de prix
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Intervalle de prix (TND):"),
                      RangeSlider(
                        values: localPriceRange,
                        min: 0,
                        max: 100000,
                        divisions: 100,
                        labels: RangeLabels(
                          localPriceRange.start.round().toString(),
                          localPriceRange.end.round().toString(),
                        ),
                        onChanged: (values) {
                          setModalState(() {
                            localPriceRange = values;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _filterCondition = localCondition;
                        _sortByDateAsc = localSortAsc;
                        _priceRange = localPriceRange;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text("Appliquer"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Réinitialiser les filtres
  void _clearFilters() {
    setState(() {
      _filterCondition = 'All';
      _sortByDateAsc = true;
      _priceRange = const RangeValues(0, 100000);
    });
  }

  Widget _buildNavButton(IconData icon, Color color, String label, VoidCallback onPressed, {double size = 28}) {
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
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: color == Colors.green ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Sidebar(),
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: Text('Marketplace', 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 22,
          )
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 2,
        actions: [
          if (_filterCondition != 'All' || !_sortByDateAsc || _priceRange.start != 0 || _priceRange.end != 100000)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: Theme.of(context).colorScheme.onPrimary),
              onPressed: _clearFilters,
            ),
          IconButton(
            icon: Icon(Icons.tune_rounded, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                hintText: 'Rechercher un produit...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
            ),
          ),
          // Liste des posts
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getMarketplacePosts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Aucun post disponible.",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  );
                }
                var posts = snapshot.data!.docs;
                var filteredPosts = posts.where((post) {
                  String title = post['title']?.toLowerCase() ?? '';
                  if (!title.contains(searchQuery)) return false;
                  if (_filterCondition != 'All') {
                    String etat = post['etat']?.toLowerCase() ?? '';
                    if (etat != _filterCondition.toLowerCase()) return false;
                  }
                  String priceStr = post['price']?.toString() ?? '0';
                  double price = double.tryParse(priceStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                  if (price < _priceRange.start || price > _priceRange.end) return false;
                  return true;
                }).toList();
                if (filteredPosts.isEmpty) {
                  return const Center(
                    child: Text(
                      "Aucun produit ne correspond à vos critères.",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  );
                }
                filteredPosts.sort((a, b) {
                  Timestamp ta = a['createdAt'] ?? Timestamp(0, 0);
                  Timestamp tb = b['createdAt'] ?? Timestamp(0, 0);
                  return _sortByDateAsc ? ta.compareTo(tb) : tb.compareTo(ta);
                });
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: filteredPosts.length,
                    itemBuilder: (context, index) {
                      var post = filteredPosts[index];
                      List<dynamic>? images = post['images'];
                      String imageUrl = images != null && images.isNotEmpty ? images[0] : "";
                      if (post['title'] == null || post['price'] == null || imageUrl.isEmpty) {
                        return Container();
                      }
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailsPage(post: post),
                            ),
                          );
                        },
                        child: ZoomProduct(
                          imageUrl: imageUrl,
                          title: post['title'] ?? 'Produit sans titre',
                          price: post['price'] != null ? double.tryParse(post['price'].toString()) ?? 0 : 0,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Footer fixe avec 3 icônes
      bottomNavigationBar: Container(
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
              Icons.home_rounded,
              _selectedIndex == 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              'Accueil',
              () {
                setState(() => _selectedIndex = 0);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const ClientHomePage()),
                );
              },
            ),
            _buildNavButton(
              Icons.favorite_rounded, // Updated to rounded
              _selectedIndex == 1 ? Theme.of(context).primaryColor : Colors.grey,
              'Favoris',
              () {
                setState(() => _selectedIndex = 1);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const FavorisPage()),
                );
              },
            ),
            _buildNavButton(
              Icons.add_circle_rounded, // Updated to rounded
              _selectedIndex == 2 ? Theme.of(context).primaryColor : Colors.grey,
              'Ajouter',
              () {
                setState(() => _selectedIndex = 2);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AddPostPage()),
                );
              },
              size: 36,
            ),
            _buildNavButton(
              Icons.inventory_2_rounded, // Changed from list to inventory_2
              _selectedIndex == 3 ? Theme.of(context).primaryColor : Colors.grey,
              'Mes Produits',
              () {
                setState(() => _selectedIndex = 3);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MesProduitsPage()),
                );
              },
            ),
            _buildNavButton(
              Icons.chat_rounded, // Updated to rounded
              _selectedIndex == 4 ? Theme.of(context).primaryColor : Colors.grey,
              'Chat',
              () {
                setState(() => _selectedIndex = 4);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatListScreen()),
                );
              },
            ),
          ],
        ),
      ),
    ); // Close Scaffold
  } // Close build method
} // Close class

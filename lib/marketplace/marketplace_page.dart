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

class _MarketplacePageState extends State<MarketplacePage> with SingleTickerProviderStateMixin {
  String searchQuery = '';

  // Variables de filtre
  String _filterCondition = 'All'; // "All", "Neuf", "Occasion"
  bool _sortByDateAsc = true; // true = date ascendante, false = descendante
  RangeValues _priceRange = const RangeValues(0, 100000);

  Stream<QuerySnapshot> _getMarketplacePosts() {
    return FirebaseFirestore.instance.collection('marketplace').snapshots();
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
                  Row(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Sidebar(),
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Marketplace',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_filterCondition != 'All' || !_sortByDateAsc || 
              _priceRange.start != 0 || _priceRange.end != 100000)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearFilters,
              tooltip: 'Réinitialiser les filtres',
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterSheet,
            tooltip: 'Filtrer',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.primary,
                ),
                hintText: 'Rechercher un produit...',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getMarketplacePosts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Aucun produit disponible",
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter and sort logic remains the same
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
                  Timestamp ta = a['timestamp'] ?? Timestamp(0, 0);
                  Timestamp tb = b['timestamp'] ?? Timestamp(0, 0);
                  return _sortByDateAsc ? ta.compareTo(tb) : tb.compareTo(ta);
                });
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredPosts.length,
                    itemBuilder: (context, index) {
                      var post = filteredPosts[index];
                      List<dynamic>? images = post['images'];
                      String imageUrl = images != null && images.isNotEmpty ? images[0] : "";

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailsPage(post: post),
                            ),
                          ),
                          child: ZoomProduct(
                            imageUrl: imageUrl,
                            title: post['title'] ?? 'Sans titre',
                            price: post['price']?.toDouble() ?? 0,
                          ),
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
      bottomNavigationBar: Container(
        height: 65,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavButton(
              icon: Icons.home,
              label: 'Accueil',
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ClientHomePage()),
              ),
            ),
            _buildNavButton(
              icon: Icons.favorite,
              label: 'Favoris',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FavorisPage()),
              ),
            ),
            _buildNavButton(
              icon: Icons.add_circle,
              label: 'Ajouter',
              isMain: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddPostPage()),
              ),
            ),
            _buildNavButton(
              icon: Icons.list,
              label: 'Mes Posts',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MesProduitsPage()),
              ),
            ),
            _buildNavButton(
              icon: Icons.chat,
              label: 'Messages',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatListScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isMain = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isMain ? 32 : 24,
            color: isMain 
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.primary,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isMain 
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
<<<<<<< Updated upstream

      // Bouton Mes Posts (NOUVEAU)
      IconButton(
        icon: const Icon(Icons.list, size: 28, color: Colors.orange),
        onPressed: () {
          // Remplace par la page Mes Posts
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MesProduitsPage()),
          );
        },
      ),

      // Bouton Messagerie
      IconButton(
        icon: const Icon(Icons.chat, size: 28, color: Colors.blueAccent),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) =>  ConversationsListPage()),
          );
        },
      ),
    ],
  ),
),

=======
>>>>>>> Stashed changes
    );
  }
}

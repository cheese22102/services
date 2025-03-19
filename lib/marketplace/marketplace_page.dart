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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: const Text('Marketplace', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        actions: [
          if (_filterCondition != 'All' || !_sortByDateAsc || _priceRange.start != 0 || _priceRange.end != 100000)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearFilters,
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
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
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                hintText: 'Rechercher un produit...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
  height: 55,
  margin: const EdgeInsets.all(8),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5),
    ],
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      // Bouton Accueil
      IconButton(
        icon: const Icon(Icons.home, size: 28, color: Colors.blue),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ClientHomePage()),
          );
        },
      ),
      
      // Bouton Favoris (NOUVEAU)
      IconButton(
        icon: const Icon(Icons.favorite, size: 28, color: Colors.redAccent),
        onPressed: () {
          // Remplace par la page Favoris
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FavorisPage()),
          );
        },
      ),

      // Bouton Ajouter un Post
      IconButton(
        icon: const Icon(Icons.add_circle, size: 36, color: Colors.green),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPostPage()),
          );
        },
      ),

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

    );
  }
}

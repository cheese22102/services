import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/zoom_product.dart'; // Le widget ZoomProduct
import 'package:go_router/go_router.dart';
import '../../widgets/bottom_navbar.dart';
import '../../widgets/search_bar.dart';

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


  // In _onItemTapped method, change the chat route

  void _navigateToDetails(DocumentSnapshot post) {
    print("Navigating to details with post ID: ${post.id}");
    print("Post data: ${post.data()}");
    context.push('/clientHome/marketplace/details/${post.id}', extra: post);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        // Replace the sidebar menu with back arrow
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.black38 
                  : Colors.white38,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back),
          ),
          onPressed: () => context.go('/clientHome'),
        ),
        title: const Text('Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearFilters,
          ),
        ],
      ),
      // Remove the drawer property since we no longer need it
      // drawer: const Sidebar(),
      body: Column(
        children: [
          // Replace the old search bar with the new CustomSearchBar
          CustomSearchBar(
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
            hintText: 'Rechercher un produit...',
          ),
          
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
                  String title = post['title']?.toString().toLowerCase() ?? '';
                  if (searchQuery.isNotEmpty && !title.contains(searchQuery.toLowerCase())) {
                    return false;
                  }
                  if (_filterCondition != 'All') {
                    String etat = post['etat']?.toString().toLowerCase() ?? '';
                    if (etat != _filterCondition.toLowerCase()) {
                      return false;
                    }
                  }
                  String priceStr = post['price']?.toString() ?? '0';
                  double price = double.tryParse(priceStr) ?? 0;
                  if (price < _priceRange.start || price > _priceRange.end) {
                    return false;
                  }
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

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: filteredPosts.length,
                  itemBuilder: (context, index) {
                    var post = filteredPosts[index];
                    List<dynamic>? images = post['images'];
                    String imageUrl = images != null && images.isNotEmpty ? images[0] : "";
                    
                    return InkWell(
                      onTap: () => _navigateToDetails(post),
                      child: ZoomProduct(
                        imageUrl: imageUrl,
                        title: post['title'] ?? 'Produit sans titre',
                        price: post['price'] != null ? double.tryParse(post['price'].toString()) ?? 0 : 0,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: MarketplaceBottomNav(
        selectedIndex: _selectedIndex,
      ),
    );
  }
} // Close class

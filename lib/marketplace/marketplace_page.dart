import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'ajout_marketplace.dart'; // Importation de la page d'ajout de post
import 'details_post_page.dart'; // Import the PostDetailsPage

class MarketplacePage extends StatelessWidget {
  const MarketplacePage({super.key});

  // Fonction pour récupérer les posts du marketplace depuis Firestore
  Stream<QuerySnapshot> _getMarketplacePosts() {
    return FirebaseFirestore.instance.collection('marketplace').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getMarketplacePosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Aucun post disponible."));
          }

          var posts = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // Deux colonnes
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.75, // Ajustement du ratio hauteur/largeur
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              var post = posts[index];

              // Vérification des images
              List<dynamic>? images = post['images'];
              String imageUrl = images != null && images.isNotEmpty ? images[0] : "";

              // Avoid rendering empty posts
              if (post['title'] == null || post['price'] == null || imageUrl.isEmpty) {
                return Container(); // Return an empty container if the post is incomplete
              }

              return InkWell(
                onTap: () {
                  // Navigate to the post details page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailsPage(post: post),
                    ),
                  );
                },
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                              child: Image.network(
                                imageUrl,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  print("Erreur de chargement de l'image : $error");
                                  return Image.network(
                                    "https://via.placeholder.com/150",
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            )
                          : Image.network(
                              "https://via.placeholder.com/150",
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post['title'],
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${post['price']} €",
                              style: const TextStyle(fontSize: 14, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPostPage()),
          );
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}

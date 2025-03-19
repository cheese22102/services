import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'image_plein_ecran.dart'; // Ensure this file is in your project
import 'modifier_post_page.dart';
import '../chat/chat_screen.dart';

class PostDetailsPage extends StatefulWidget {
  final DocumentSnapshot post; // Use DocumentSnapshot
  const PostDetailsPage({Key? key, required this.post}) : super(key: key);

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  late Map<String, dynamic> postData;

  @override
  void initState() {
    super.initState();
    // Get the post data; if null, use an empty map.
    postData = widget.post.data() as Map<String, dynamic>? ?? {};
  }

  Future<String> _getUserName(String userId) async {
    try {
      var userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        var userData = userDoc.data();
        if (userData != null &&
            userData['firstname'] != null &&
            userData['lastname'] != null) {
          return "${userData['firstname']} ${userData['lastname']}";
        }
      }
      return "Unknown User";
    } catch (e) {
      return "Error loading user info";
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final favoritesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favoris')
        .doc(widget.post.id);

    final doc = await favoritesRef.get();
    if (doc.exists) {
      await favoritesRef.delete();
    } else {
      await favoritesRef.set({'timestamp': FieldValue.serverTimestamp()});
    }
  }

  @override
  Widget build(BuildContext context) {
    String postUserId = postData['userId'];
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du produit'),
        backgroundColor: Colors.green,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .collection('favoris')
                .doc(widget.post.id)
                .snapshots(),
            builder: (context, snapshot) {
              final isFavorite = snapshot.data?.exists ?? false;
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? Colors.amber : Colors.white,
                ),
                onPressed: _toggleFavorite,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _getUserName(postData['userId']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text("Error loading user information"));
          }
          String userName = snapshot.data ?? "Unknown User";

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Carousel
                  if (postData['images'] != null &&
                      (postData['images'] as List).isNotEmpty)
                    ImageCarousel(
                      imageUrls: List<String>.from(postData['images']),
                      postId: widget.post.id,
                    ),
                  const SizedBox(height: 16),
                  // Post title
                  Text(
                    postData['title'] ?? 'No Title',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ) ??
                        const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Description
                  Text(
                    postData['description'] ?? "No description provided.",
                    style: Theme.of(context).textTheme.bodyMedium ??
                        const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  // Price
                  Text(
                    "Price: ${postData['price']} €",
                    style: const TextStyle(
                        fontSize: 18,
                        color: Colors.green,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Product state
                  Text(
                    "Etat du produit: ${postData['etat'] ?? 'Unknown'}",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  // Posted by
                  Text(
                    "Posted by: $userName",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  // If current user is not the owner, show Send Message button
                  if (currentUserId != postUserId)
                    ElevatedButton(
                      onPressed: () async {
                        String receiverName = await _getUserName(postData['userId']);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreenPage(
                              otherUserId: postData['userId'],
                              postId: widget.post.id,
                              otherUserName: postData['title'],
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green,
                      ),
                      child: const Text("Send Message"),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      // Floating buttons for edit and delete (only for the owner)
      floatingActionButton: currentUserId == postUserId
          ? Padding(
              padding: const EdgeInsets.only(bottom: 16.0, right: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    onPressed: () async {
                      // Pass the DocumentSnapshot directly to ModifyPostPage
                      final updatedData = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ModifyPostPage(post: widget.post),
                        ),
                      );
                      if (updatedData != null) {
                        setState(() {
                          postData = updatedData;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Post updated successfully")),
                        );
                      }
                    },
                    backgroundColor: Colors.blueAccent,
                    child: const Icon(Icons.edit),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    onPressed: () async {
                      bool? confirmDelete = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text("Confirm Deletion"),
                            content: const Text("Are you sure you want to delete this post? This action cannot be undone."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text("Delete", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          );
                        },
                      );
                      if (confirmDelete == true) {
                        await FirebaseFirestore.instance
                            .collection('marketplace')
                            .doc(widget.post.id)
                            .delete();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Post deleted")),
                        );
                        Navigator.pop(context);
                      }
                    },
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.delete),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final String postId;

  const ImageCarousel({Key? key, required this.imageUrls, required this.postId}) : super(key: key);

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double carouselHeight = MediaQuery.of(context).size.height * 0.5;
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.orange, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: carouselHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.imageUrls.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  String imageUrl = widget.imageUrls[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImagePage(
                            imageUrl: imageUrl,
                            tag: "postImage$index-${widget.postId}",
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: "postImage$index-${widget.postId}",
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: carouselHeight,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Image.network(
                            "https://via.placeholder.com/150",
                            width: double.infinity,
                            height: carouselHeight,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Page indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.imageUrls.length, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 10 : 6,
              height: _currentPage == index ? 10 : 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index ? Colors.orange : Colors.grey,
              ),
            );
          }),
        ),
      ],
    );
  }
}

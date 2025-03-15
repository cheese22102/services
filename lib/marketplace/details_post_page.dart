import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'image_plein_ecran.dart';
import 'modifier_post_page.dart';
import '../chat/chat_screen.dart';

class PostDetailsPage extends StatefulWidget {
  final QueryDocumentSnapshot post;
  const PostDetailsPage({super.key, required this.post});

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  late Map<String, dynamic> postData;

  @override
  void initState() {
    super.initState();
    postData = widget.post.data() as Map<String, dynamic>;
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
          return "${userData['firstName']} ${userData['lastName']}";
        }
      }
      return "Unknown User";
    } catch (e) {
      return "Error loading user info";
    }
  }

  @override
  Widget build(BuildContext context) {
    String postUserId = postData['userId'];
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
        backgroundColor: Colors.green,
      ),
      body: FutureBuilder<String>(
        future: _getUserName(postUserId),
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
                  // Carrousel d'images
                  if (postData['images'] != null &&
                      postData['images'].isNotEmpty)
                    ImageCarousel(
                      imageUrls: List<String>.from(postData['images']),
                      postId: widget.post.id,
                    ),
                  const SizedBox(height: 16),
                  // Titre du post
                  Text(
                    postData['title'],
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Description
                  Text(
                    postData['description'] ?? "No description provided.",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  // Prix
                  Text(
                    "Price: ${postData['price']} €",
                    style: const TextStyle(
                        fontSize: 18,
                        color: Colors.green,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Informations sur le posteur
                  Text(
                    "Posted by: $userName",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  // Boutons d'action selon l'utilisateur courant
                  if (currentUserId == postUserId)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final updatedData = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ModifyPostPage(post: widget.post),
                              ),
                            );
                            if (updatedData != null) {
                              setState(() {
                                postData = updatedData;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("Post updated successfully")),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.blueAccent,
                          ),
                          child: const Text("Modify Post"),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () async {
                            bool? confirmDelete = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text("Confirm Deletion"),
                                  content: const Text(
                                      "Are you sure you want to delete this post? This action cannot be undone."),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text("Delete",
                                          style:
                                              TextStyle(color: Colors.red)),
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
                                const SnackBar(
                                    content: Text("Post deleted")),
                              );
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.redAccent,
                          ),
                          child: const Text("Delete Post"),
                        ),
                      ],
                    )
                  else
                   ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          senderId: currentUserId,  // Current logged-in user
          receiverId: postUserId,  // The person who posted the item
          postId: widget.post.id, // Pass the post ID

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
    );
  }
}

class ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final String postId;

  const ImageCarousel(
      {super.key, required this.imageUrls, required this.postId});

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

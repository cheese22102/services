import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        backgroundColor: Colors.blue,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.lightBlueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data?.docs ?? [];
          if (chats.isEmpty) {
            return Center(
              child: Text(
                'No conversations yet.\nStart a new chat!', 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final participants = List<String>.from(chat['participants']);
              final otherUserId = participants.firstWhere((id) => id != currentUserId);

              return FutureBuilder<Map<String, dynamic>>(
                future: Future.wait([
                  _getUserName(otherUserId),
                  _getPostTitle(chat['postId']),
                  _getPostStatus(chat['postId']),
                ]).then((results) => {
                  'userName': results[0],
                  'postTitle': results[1],
                  'postActive': results[2],
                }),
                builder: (context, snapshot) {
                  final userName = snapshot.data?['userName'] ?? 'Loading...';
                  final postTitle = snapshot.data?['postTitle'] ?? 'Loading post...';
                  final postActive = snapshot.data?['postActive'] ?? true;
                  final lastMessage = chat['lastMessage']?.toString() ?? 'No messages yet';
                  final timestamp = chat['lastMessageTime']?.toDate();

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Icon(Icons.person, color: Colors.blue),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(userName, 
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          if (!postActive)
                            const Icon(Icons.archive, size: 16, color: Colors.grey)
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(postTitle, style: TextStyle(color: Colors.blue[800])),
                          Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: lastMessage == 'No messages yet' 
                                  ? Colors.grey 
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (timestamp != null)
                            Text(
                              DateFormat('HH:mm').format(timestamp),
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (timestamp != null)
                            Text(
                              DateFormat('MMM dd').format(timestamp),
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            senderId: currentUserId,
                            receiverId: otherUserId,
                            postId: chat['postId'],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<String> _getUserName(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!doc.exists) return 'Unknown User';
      return '${doc['firstname']} ${doc['lastname']}'.trim().isEmpty 
          ? 'Unknown User' 
          : '${doc['firstname']} ${doc['lastname']}';
    } catch (e) {
      return 'Error loading user';
    }
  }

  Future<String> _getPostTitle(String postId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('marketplace').doc(postId).get();
      return doc.exists ? doc['title'] ?? 'Untitled Post' : 'Deleted Post';
    } catch (e) {
      return 'Error loading post';
    }
  }

  Future<bool> _getPostStatus(String postId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('marketplace').doc(postId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }
}
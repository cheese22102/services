import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReactionDisplay extends StatelessWidget {
  final Map<String, dynamic>? reactions;
  final String reactionEmoji;

  const ReactionDisplay({
    Key? key,
    required this.reactions,
    this.reactionEmoji = '❤️',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<dynamic> usersReacted =
        reactions != null && reactions![reactionEmoji] != null
            ? List<dynamic>.from(reactions![reactionEmoji])
            : [];
    if (usersReacted.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        // Afficher un dialogue listant les utilisateurs ayant réagi
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Réactions'),
              content: FutureBuilder<List<String>>(
                future: _fetchUserNames(usersReacted),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final names = snapshot.data ?? [];
                  return SizedBox(
                    width: double.maxFinite,
                    child: ListView(
                      children:
                          names.map((name) => ListTile(title: Text(name))).toList(),
                    ),
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                )
              ],
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, color: Colors.red, size: 16),
            const SizedBox(width: 4),
            Text(
              usersReacted.length.toString(),
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>> _fetchUserNames(List<dynamic> userIds) async {
    final List<String> names = [];
    for (var uid in userIds) {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        String name = '';
        if (data['firstname'] != null && data['lastname'] != null) {
          name = '${data['firstname']} ${data['lastname']}';
        } else {
          name = 'Inconnu';
        }
        names.add(name);
      } else {
        names.add('Inconnu');
      }
    }
    return names;
  }
}

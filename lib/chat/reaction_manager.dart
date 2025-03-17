import 'package:cloud_firestore/cloud_firestore.dart';

class ReactionManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> toggleReaction({
    required String chatroomId,
    required String messageId,
    required String userId,
    String reaction = '❤️',
  }) async {
    final messageRef = _firestore
        .collection('chats')
        .doc(chatroomId)
        .collection('messages')
        .doc(messageId);

    final doc = await messageRef.get();
    if (!doc.exists) return;

    Map<String, dynamic> reactions = {};
    if (doc.data()?['reactions'] != null && doc.data()!['reactions'] is Map) {
      reactions = Map<String, dynamic>.from(doc.data()!['reactions']);
    }

    List<dynamic> usersReacted = reactions[reaction] != null
        ? List<dynamic>.from(reactions[reaction])
        : [];

    if (usersReacted.contains(userId)) {
      usersReacted.remove(userId);
    } else {
      usersReacted.add(userId);
    }
    reactions[reaction] = usersReacted;
    await messageRef.update({'reactions': reactions});
  }
}

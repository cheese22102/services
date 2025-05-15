import 'package:cloud_firestore/cloud_firestore.dart';

class ReclamationModel {
  final String id;
  final String reservationId;
  final String submitterId;
  final String targetId;
  final String title;
  final String description;
  final List<String> imageUrls;
  final String status;
  final Timestamp createdAt;
  final String? adminResponse;
  final Timestamp? resolvedAt;
  final bool isNotified;

  ReclamationModel({
    required this.id,
    required this.reservationId,
    required this.submitterId,
    required this.targetId,
    required this.title,
    required this.description,
    required this.imageUrls,
    required this.status,
    required this.createdAt,
    this.adminResponse,
    this.resolvedAt,
    this.isNotified = false,
  });

  factory ReclamationModel.fromMap(Map<String, dynamic> map, String docId) {
    return ReclamationModel(
      id: docId,
      reservationId: map['reservationId'] ?? '',
      submitterId: map['submitterId'] ?? '',
      targetId: map['targetId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      adminResponse: map['adminResponse'],
      resolvedAt: map['resolvedAt'],
      isNotified: map['isNotified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reservationId': reservationId,
      'submitterId': submitterId,
      'targetId': targetId,
      'title': title,
      'description': description,
      'imageUrls': imageUrls,
      'status': status,
      'createdAt': createdAt,
      'adminResponse': adminResponse,
      'resolvedAt': resolvedAt,
      'isNotified': isNotified,
    };
  }

  ReclamationModel copyWith({
    String? id,
    String? reservationId,
    String? submitterId,
    String? targetId,
    String? title,
    String? description,
    List<String>? imageUrls,
    String? status,
    Timestamp? createdAt,
    String? adminResponse,
    Timestamp? resolvedAt,
    bool? isNotified,
  }) {
    return ReclamationModel(
      id: id ?? this.id,
      reservationId: reservationId ?? this.reservationId,
      submitterId: submitterId ?? this.submitterId,
      targetId: targetId ?? this.targetId,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      adminResponse: adminResponse ?? this.adminResponse,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      isNotified: isNotified ?? this.isNotified,
    );
  }
}
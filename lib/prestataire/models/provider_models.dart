import 'package:cloud_firestore/cloud_firestore.dart';

// Modèle du Prestataire
class Provider {
  final String userId;
  final List<String> services;
  final List<Experience> experiences;
  final List<String> certifications;
  final List<String> certificationFiles;
  final String bio;
  final String idCardUrl;
  final String? selfieWithIdUrl;
  final String? patenteUrl;
  final Map<String, dynamic> exactLocation;
  final Map<String, Map<String, String>> workingHours;
  final Map<String, bool> workingDays;
  final String status;
  final Timestamp submissionDate;

  Provider({
    required this.userId,
    required this.services,
    required this.experiences,
    required this.certifications,
    required this.certificationFiles,
    required this.bio,
    required this.idCardUrl,
    this.selfieWithIdUrl,
    this.patenteUrl,
    required this.exactLocation,
    required this.workingHours,
    required this.workingDays,
    required this.status,
    required this.submissionDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'services': services,
      'experiences': experiences.map((e) => e.toMap()).toList(),
      'certifications': certifications,
      'certificationFiles': certificationFiles,
      'bio': bio,
      'idCardUrl': idCardUrl,
      'selfieWithIdUrl': selfieWithIdUrl,
      'patenteUrl': patenteUrl,
      'exactLocation': exactLocation,
      'workingHours': workingHours,
      'workingDays': workingDays,
      'status': status,
      'submissionDate': submissionDate,
    };
  }
  
  factory Provider.fromMap(Map<String, dynamic> map) {
    return Provider(
      userId: map['userId'] ?? '',
      services: List<String>.from(map['services'] ?? []),
      experiences: List<Experience>.from(
        (map['experiences'] ?? []).map((x) => Experience.fromMap(x))),
      certifications: List<String>.from(map['certifications'] ?? []),
      certificationFiles: List<String>.from(map['certificationFiles'] ?? []),
      bio: map['bio'] ?? '',
      idCardUrl: map['idCardUrl'] ?? '',
      selfieWithIdUrl: map['selfieWithIdUrl'],
      patenteUrl: map['patenteUrl'],
      exactLocation: Map<String, dynamic>.from(map['exactLocation'] ?? {}),
      workingHours: (map['workingHours'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, Map<String, String>.from(value)),
      ) ?? {},
      workingDays: Map<String, bool>.from(map['workingDays'] ?? {}),
      status: map['status'] ?? 'pending',
      submissionDate: map['submissionDate'] ?? Timestamp.now(),
    );
  }
}

// Modèle d'expérience
class Experience {
  final String service;
  final int years;
  final String description;

  Experience({
    required this.service,
    required this.years,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'service': service,
      'years': years,
      'description': description,
    };
  }

  factory Experience.fromMap(Map<String, dynamic> map) {
    return Experience(
      service: map['service'] ?? '',
      years: map['years'] ?? 0,
      description: map['description'] ?? '',
    );
  }
}
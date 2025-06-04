import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../front/app_colors.dart';
import '../../front/app_spacing.dart';
import '../../front/app_typography.dart';
import '../../front/custom_button.dart';
import '../../front/custom_app_bar.dart';
import 'package:go_router/go_router.dart';
import '../../utils/image_gallery_utils.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

class ProviderProfilePage extends StatefulWidget {
  final String providerId;
  final String serviceName;

  const ProviderProfilePage({
    super.key,
    required this.providerId,
    this.serviceName = '',
  });

  @override
  State<ProviderProfilePage> createState() => _ProviderProfilePageState();
}

class _ProviderProfilePageState extends State<ProviderProfilePage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 0.0;
  bool _isFavorite = false;
  late TabController _tabController;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _hasActiveReservation = false;
  bool _checkingReservation = true;
  StreamSubscription<QuerySnapshot>? _reservationSubscription;

  Widget _buildStarRating(double rating, {double iconSize = AppSpacing.iconSm, Color? color}) {
    List<Widget> stars = [];
    int fullStars = rating.floor();
    double halfStar = rating - fullStars;

    for (int i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.add(Icon(Icons.star_rounded, color: color ?? Colors.amber, size: iconSize));
      } else if (i == fullStars && halfStar >= 0.5) {
        stars.add(Icon(Icons.star_half_rounded, color: color ?? Colors.amber, size: iconSize));
      } else {
        stars.add(Icon(Icons.star_border_rounded, color: color ?? Colors.amber, size: iconSize));
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: stars);
  }

  Map<String, dynamic> _providerData = {};
  Map<String, dynamic> _userData = {};
  String _fetchedServiceName = '';

  double _qualityRating = 0.0;
  double _timelinessRating = 0.0;
  double _priceRating = 0.0;
  int _reviewCount = 0;

  List<String> _projectImages = [];

  double? _latitude;
  double? _longitude;
  String _address = '';
  GoogleMapController? _googleMapController;
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      if (mounted) {
        _tabController = TabController(length: 3, vsync: this);
        _fetchProviderData();
        _setupReservationListener();
      }
    });
  }

  @override
  void dispose() {
    _reservationSubscription?.cancel();
    _tabController.dispose();
    _googleMapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchProviderData() async {
    try {
      final providerDoc = await FirebaseFirestore.instance.collection('providers').doc(widget.providerId).get();
      if (!providerDoc.exists) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final providerData = providerDoc.data() ?? {};
      final userId = providerData['userId'] as String?;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final userData = userDoc.data() ?? {};
      String fetchedServiceName = widget.serviceName.isNotEmpty ? widget.serviceName : '';
      if (fetchedServiceName.isEmpty && providerData.containsKey('services') && providerData['services'] is List && (providerData['services'] as List).isNotEmpty) {
        fetchedServiceName = (providerData['services'] as List).first.toString();
      }
      double? latitude;
      double? longitude;
      String address = 'Adresse non spécifiée';
      if (providerData.containsKey('exactLocation') && providerData['exactLocation'] is Map<String, dynamic>) {
        final locationData = providerData['exactLocation'] as Map<String, dynamic>;
        latitude = (locationData['latitude'] as num?)?.toDouble();
        longitude = (locationData['longitude'] as num?)?.toDouble();
        address = locationData['address'] as String? ?? 'Adresse non spécifiée';
      }
      List<String> projectImages = [];
      if (providerData.containsKey('projectPhotos') && providerData['projectPhotos'] is List) {
        projectImages = List<String>.from(providerData['projectPhotos'] as List);
      }
      if (mounted) {
        setState(() {
          _providerData = providerData;
          _userData = userData;
          _fetchedServiceName = fetchedServiceName;
          _latitude = latitude;
          _longitude = longitude;
          _address = address;
          _projectImages = projectImages;
          if (_latitude != null && _longitude != null) {
            _circles = {
              Circle(
                circleId: const CircleId('provider_radius'),
                center: LatLng(_latitude!, _longitude!),
                radius: 10000, 
                fillColor: AppColors.primaryGreen.withOpacity(0.1),
                strokeColor: AppColors.primaryGreen.withOpacity(0.5),
                strokeWidth: 1,
              )
            };
          }
        });
      }
      await _loadData();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    try {
      if (currentUserId != null) {
        final favDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).collection('prestataires_favoris').doc(widget.providerId).get();
        if (mounted) setState(() => _isFavorite = favDoc.exists);
      }
      final ratingsDoc = await FirebaseFirestore.instance.collection('providers').doc(widget.providerId).collection('ratings').doc('stats').get();
      if (mounted && ratingsDoc.exists) {
        final ratingsData = ratingsDoc.data() ?? {};
        setState(() {
          _qualityRating = (ratingsData['quality']?['average'] as num?)?.toDouble() ?? 0.0;
          _timelinessRating = (ratingsData['timeliness']?['average'] as num?)?.toDouble() ?? 0.0;
          _priceRating = (ratingsData['price']?['average'] as num?)?.toDouble() ?? 0.0;
          _reviewCount = (ratingsData['reviewCount'] as num?)?.toInt() ?? 0;
        });
      }
      if (mounted && _providerData.containsKey('rating')) {
        setState(() => _averageRating = (_providerData['rating'] as num?)?.toDouble() ?? 0.0);
      }
      final reviewsSnapshot = await FirebaseFirestore.instance.collection('providers').doc(widget.providerId).collection('ratings').doc('reviews').collection('items').orderBy('createdAt', descending: true).get();
      if (mounted) {
        setState(() {
          _reviews = reviewsSnapshot.docs.map((doc) => doc.data()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (currentUserId == null) return;
    final newFavoriteState = !_isFavorite;
    if (mounted) setState(() => _isFavorite = newFavoriteState);
    try {
      final favRef = FirebaseFirestore.instance.collection('users').doc(currentUserId).collection('prestataires_favoris').doc(widget.providerId);
      if (newFavoriteState) {
        await favRef.set({'providerId': widget.providerId, 'addedAt': FieldValue.serverTimestamp(), 'serviceName': _fetchedServiceName});
      } else {
        await favRef.delete();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFavorite = !newFavoriteState);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur des favoris.', style: AppTypography.bodySmall(context))));
      }
    }
  }

  Future<void> _checkActiveReservations() async {
    if (currentUserId == null) {
      if (mounted) setState(() => _checkingReservation = false);
      return;
    }
    try {
      final reservationsQuery = await FirebaseFirestore.instance.collection('reservations').where('userId', isEqualTo: currentUserId).where('providerId', isEqualTo: widget.providerId).where('status', isEqualTo: 'pending').get();
      if (mounted) setState(() {
        _hasActiveReservation = reservationsQuery.docs.isNotEmpty;
        _checkingReservation = false;
      });
    } catch (e) {
      if (mounted) setState(() => _checkingReservation = false);
    }
  }

  Future<void> _setupReservationListener() async {
    if (currentUserId == null) {
      if (mounted) setState(() => _checkingReservation = false);
      return;
    }
    try {
      await _checkActiveReservations();
      final reservationsQuery = FirebaseFirestore.instance.collection('reservations').where('userId', isEqualTo: currentUserId).where('providerId', isEqualTo: widget.providerId).where('status', isEqualTo: 'pending');
      _reservationSubscription = reservationsQuery.snapshots().listen((snapshot) {
        if (mounted) setState(() {
          _hasActiveReservation = snapshot.docs.isNotEmpty;
          _checkingReservation = false;
        });
      }, onError: (error) {
        if (mounted) setState(() => _checkingReservation = false);
      });
    } catch (e) {
      if (mounted) setState(() => _checkingReservation = false);
    }
  }

  void _contactProvider() {
    if (_providerData.containsKey('userId')) {
      final providerUserId = _providerData['userId'] as String;
      final providerName = '${_userData['firstname'] ?? ''} ${_userData['lastname'] ?? ''}'.trim();
      context.push('/clientHome/marketplace/chat/conversation/$providerUserId', extra: {'otherUserName': providerName.isNotEmpty ? providerName : 'Prestataire'});
    }
  }

  Future<void> _makePhoneCall() async {
    final phone = _userData['phone'] as String?;
    if (phone != null && phone.isNotEmpty) {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);
      try {
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch $phoneUri';
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir: $e', style: AppTypography.bodySmall(context).copyWith(color: Colors.white)), backgroundColor: AppColors.errorLightRed));
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Numéro non disponible', style: AppTypography.bodySmall(context).copyWith(color: Colors.white)), backgroundColor: AppColors.warningOrange));
    }
  }

  Future<void> _openInGoogleMaps() async {
    if (_latitude == null || _longitude == null) return;
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$_latitude,$_longitude');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    else if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir Maps', style: AppTypography.bodySmall(context))));
  }

  Widget _buildEnhancedProviderHeader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    final providerName = '${_userData['firstname'] ?? ''} ${_userData['lastname'] ?? ''}'.trim();
    final photoUrl = _userData['avatarUrl'] as String? ?? '';
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      margin: EdgeInsets.only(bottom: AppSpacing.md, left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground, // Changed to match AppBar
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: AppSpacing.xxl * 2.2,
            height: AppSpacing.xxl * 2.2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor, width: 3),
              color: isDarkMode ? AppColors.darkSurface : AppColors.lightSurface,
            ),
            child: ClipOval(
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: primaryColor,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.broken_image_rounded, size: AppSpacing.iconXl, color: primaryColor);
                      },
                    )
                  : Icon(Icons.person_outline_rounded, size: AppSpacing.iconXl, color: primaryColor),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(providerName.isNotEmpty ? providerName : 'Prestataire', style: AppTypography.h3(context).copyWith(fontWeight: FontWeight.bold, color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
            SizedBox(height: AppSpacing.xxs),
            Row(children: [
              Icon(Icons.star_rounded, color: Colors.amber, size: AppSpacing.iconSm),
              SizedBox(width: AppSpacing.xxs),
              Text(_averageRating.toStringAsFixed(1), style: AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w600, color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
              SizedBox(width: AppSpacing.xs),
              Text('(${_reviewCount} avis)', style: AppTypography.labelMedium(context).copyWith(color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
            ]),
            SizedBox(height: AppSpacing.xs),
            Text(_fetchedServiceName, style: AppTypography.bodyMedium(context).copyWith(color: primaryColor, fontWeight: FontWeight.w500)),
          ])),
        ]),
        SizedBox(height: AppSpacing.lg),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Expanded(child: _buildContactButton(icon: Icons.chat_bubble_outline_rounded, label: 'Message', onTap: _contactProvider, isDarkMode: isDarkMode, primaryColor: primaryColor)),
          SizedBox(width: AppSpacing.md),
          Expanded(child: _buildContactButton(icon: Icons.phone_outlined, label: 'Appeler', onTap: _makePhoneCall, isDarkMode: isDarkMode, primaryColor: primaryColor)),
        ]),
      ]),
    );
  }

  Widget _buildContactButton({required IconData icon, required String label, required VoidCallback onTap, required bool isDarkMode, required Color primaryColor}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: AppSpacing.iconSm, color: primaryColor),
      label: Text(label, style: AppTypography.button(context).copyWith(color: primaryColor)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg), side: BorderSide(color: primaryColor, width: 1.5)),
        elevation: 0,
      ),
    );
  }

  Widget _buildReviewsTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Évaluations et Avis', style: AppTypography.h4(context).copyWith(color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        SizedBox(height: AppSpacing.md),
        Card(
          elevation: 2,
          color: isDarkMode ? Colors.grey.shade900 : Colors.white, // Match Scaffold background
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          child: Padding(padding: EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: AppSpacing.xxl * 1.5, height: AppSpacing.xxl * 1.5, decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle), child: Center(child: Text(_averageRating.toStringAsFixed(1), style: AppTypography.h3(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold)))),
              SizedBox(width: AppSpacing.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Note globale', style: AppTypography.h4(context).copyWith(color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                SizedBox(height: AppSpacing.xxs),
                _buildStarRating(_averageRating, iconSize: AppSpacing.iconSm),
                SizedBox(height: AppSpacing.xxs),
                Text('Basé sur ${_reviewCount} avis', style: AppTypography.labelMedium(context).copyWith(color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
              ])),
            ]),
            Divider(height: AppSpacing.lg, color: isDarkMode ? AppColors.darkBorder : AppColors.lightBorder),
            _buildRatingBar('Qualité', _qualityRating, isDarkMode),
            SizedBox(height: AppSpacing.sm),
            _buildRatingBar('Ponctualité', _timelinessRating, isDarkMode),
            SizedBox(height: AppSpacing.sm),
            _buildRatingBar('Prix', _priceRating, isDarkMode),
          ])),
        ),
        SizedBox(height: AppSpacing.lg),
        Text('Commentaires des clients', style: AppTypography.h4(context).copyWith(color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        SizedBox(height: AppSpacing.md),
        if (_reviews.isEmpty)
          Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.rate_review_outlined, size: AppSpacing.iconXl, color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint),
            SizedBox(height: AppSpacing.md),
            Text('Aucun avis pour le moment', style: AppTypography.bodyLarge(context).copyWith(color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint), textAlign: TextAlign.center),
          ])))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reviews.length,
            itemBuilder: (context, index) {
              final review = _reviews[index];
              final reviewerName = review['userName'] as String? ?? 'Client';
              final comment = review['comment'] as String? ?? '';
              final quality = (review['quality'] as num?)?.toDouble() ?? 0.0;
              final timeliness = (review['timeliness'] as num?)?.toDouble() ?? 0.0;
              final price = (review['price'] as num?)?.toDouble() ?? 0.0;
              final average = (quality + timeliness + price) / 3.0;
              DateTime? date;
              if (review['createdAt'] != null && review['createdAt'] is Timestamp) date = (review['createdAt'] as Timestamp).toDate();
              return Card(
                elevation: 0,
                color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, // Reverted to original card background
                margin: EdgeInsets.only(bottom: AppSpacing.md),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd), side: BorderSide(color: isDarkMode ? AppColors.darkBorder.withOpacity(0.5) : AppColors.lightBorder.withOpacity(0.5))),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(backgroundColor: primaryColor.withOpacity(0.1), child: Text(reviewerName.isNotEmpty ? reviewerName[0].toUpperCase() : 'C', style: AppTypography.h4(context).copyWith(color: primaryColor))),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(reviewerName, style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w600, color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                        if (date != null) Text(DateFormat('dd MMM yyyy', 'fr_FR').format(date), style: AppTypography.labelSmall(context).copyWith(color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                      ])),
                      _buildStarRating(average, iconSize: AppSpacing.iconXs),
                    ]),
                    if (comment.isNotEmpty) ...[SizedBox(height: AppSpacing.sm), Text(comment, style: AppTypography.bodyMedium(context).copyWith(color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))],
                    SizedBox(height: AppSpacing.xs),
                    Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                      _buildRatingChip('Qualité', quality, isDarkMode),
                      _buildRatingChip('Ponctualité', timeliness, isDarkMode),
                      _buildRatingChip('Prix', price, isDarkMode),
                    ]),
                  ]),
                ),
              );
            },
          ),
      ]),
    );
  }
  
  Widget _buildRatingBar(String label, double rating, bool isDarkMode) {
    return Row(children: [
      SizedBox(width: 100, child: Text(label, style: AppTypography.bodyMedium(context).copyWith(color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))),
      Expanded(child: _buildStarRating(rating, iconSize: AppSpacing.iconSm)),
      SizedBox(width: AppSpacing.xl, child: Text(rating.toStringAsFixed(1), style: AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w500, color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary), textAlign: TextAlign.end)),
    ]);
  }
  
  Widget _buildRatingChip(String label, double rating, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: isDarkMode ? AppColors.darkSurface : AppColors.lightSurface, borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: AppTypography.labelSmall(context).copyWith(color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        SizedBox(width: AppSpacing.xxs),
        Text(rating.toStringAsFixed(1), style: AppTypography.labelSmall(context).copyWith(fontWeight: FontWeight.w600, color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        SizedBox(width: AppSpacing.xxs),
        Icon(Icons.star_rounded, size: AppSpacing.iconXs - 2, color: Colors.amber),
      ]),
    );
  }

  Widget _buildInformationsTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: AppSpacing.xxl), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEnhancedProviderHeader(), 
          Padding( 
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('À propos de moi', style: AppTypography.h4(context).copyWith(color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                  SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    child: (_providerData['bio'] != null && _providerData['bio'].toString().isNotEmpty)
                        ? Text(_providerData['bio'].toString(), style: AppTypography.bodyMedium(context).copyWith(color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, height: 1.5))
                        : Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Text(
                                'Ce prestataire n\'a pas encore ajouté de biographie.',
                                style: AppTypography.bodyLarge(context).copyWith(color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                  ),
                  SizedBox(height: AppSpacing.lg),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Horaires de travail', style: AppTypography.h4(context).copyWith(color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                  SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    child: Column(children: [
                      _buildWorkingDayRow('Lundi', 'monday', isDarkMode, primaryColor),
                      _buildWorkingDayRow('Mardi', 'tuesday', isDarkMode, primaryColor),
                      _buildWorkingDayRow('Mercredi', 'wednesday', isDarkMode, primaryColor),
                      _buildWorkingDayRow('Jeudi', 'thursday', isDarkMode, primaryColor),
                      _buildWorkingDayRow('Vendredi', 'friday', isDarkMode, primaryColor),
                      _buildWorkingDayRow('Samedi', 'saturday', isDarkMode, primaryColor),
                      _buildWorkingDayRow('Dimanche', 'sunday', isDarkMode, primaryColor),
                    ]),
                  ),
                ]),
                SizedBox(height: AppSpacing.lg),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Zone de travail', style: AppTypography.h4(context).copyWith(color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                  SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    child: (_latitude != null && _longitude != null)
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Padding(padding: EdgeInsets.all(AppSpacing.xs), child: Row(children: [
                              Icon(Icons.location_on_outlined, color: primaryColor, size: AppSpacing.iconSm),
                              SizedBox(width: AppSpacing.sm),
                              Expanded(child: Text(_address, style: AppTypography.bodyMedium(context).copyWith(color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))),
                            ])),
                            SizedBox(height: AppSpacing.sm),
                            GestureDetector(
                              onTap: () => _openInGoogleMaps(),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                child: SizedBox(
                                  height: 200, width: double.infinity,
                                  child: GoogleMap(
                                    mapType: MapType.normal,
                                    initialCameraPosition: CameraPosition(target: LatLng(_latitude!, _longitude!), zoom: 11.0),
                                    onMapCreated: (GoogleMapController controller) => _googleMapController = controller,
                                    circles: _circles,
                                    markers: {Marker(markerId: const MarkerId('providerLocation'), position: LatLng(_latitude!, _longitude!), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen))},
                                    zoomControlsEnabled: false,
                                    scrollGesturesEnabled: false,
                                    tiltGesturesEnabled: false,
                                    rotateGesturesEnabled: false,
                                  ),
                                ),
                              ),
                            ),
                          ])
                        : Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Text(
                                'Zone de travail non spécifiée.',
                                style: AppTypography.bodyLarge(context).copyWith(color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                  ),
                ]),
              ],
            ),
          ),
      ]),
    );
  }
  
  Widget _buildWorkingDayRow(String dayName, String dayKey, bool isDarkMode, Color primaryColor) {
    final bool isWorkingDay = _providerData.containsKey('workingDays') && _providerData['workingDays'] is Map && _providerData['workingDays'][dayKey] == true;
    String workingHours = 'Fermé';
    if (isWorkingDay && _providerData.containsKey('workingHours') && _providerData['workingHours'] is Map && _providerData['workingHours'][dayKey] is Map) {
      final startTime = _providerData['workingHours'][dayKey]['start'] as String?;
      final endTime = _providerData['workingHours'][dayKey]['end'] as String?;
      if (startTime != null && endTime != null && startTime.isNotEmpty && endTime.isNotEmpty && startTime != "00:00" && endTime != "00:00") {
        workingHours = '$startTime - $endTime';
      }
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Icon(isWorkingDay ? Icons.check_circle_outline_rounded : Icons.cancel_rounded, color: isWorkingDay ? primaryColor : AppColors.errorLightRed, size: AppSpacing.iconSm),
          SizedBox(width: AppSpacing.md),
          Text(dayName, style: AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w500, color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        ]),
        Text(workingHours, style: AppTypography.bodyMedium(context).copyWith(color: isDarkMode ? (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary) : AppColors.errorLightRed, fontWeight: isWorkingDay ? FontWeight.w500 : FontWeight.bold)),
      ]),
    );
  }

  Widget _buildProjectPhotosTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (_projectImages.isEmpty) {
      return Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.photo_library_outlined, size: AppSpacing.iconXl, color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint),
        SizedBox(height: AppSpacing.md),
        Text('Aucune photo de projet disponible', style: AppTypography.bodyLarge(context).copyWith(color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint), textAlign: TextAlign.center),
      ])));
    }
    return SingleChildScrollView( // Added SingleChildScrollView for consistency
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Galerie de Projets', style: AppTypography.h4(context).copyWith(color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        SizedBox(height: AppSpacing.md),
        ImageGalleryUtils.buildImageGallery(context, _projectImages, isDarkMode: isDarkMode), // Removed Expanded
      ]),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground, // Match other pages
      appBar: CustomAppBar(
        title: 'Profil Prestataire',
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite ? AppColors.errorLightRed : (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen), // Use default icon color when not favorited
            ),
            onPressed: _toggleFavorite,
            tooltip: _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                Container(
                  color: isDarkMode ? Colors.grey.shade900 : Colors.white, // Match CustomAppBar background
                  child: TabBar(
                    controller: _tabController,
                    labelColor: primaryColor,
                    unselectedLabelColor: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                    indicatorColor: primaryColor,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: AppTypography.button(context),
                    unselectedLabelStyle: AppTypography.button(context).copyWith(fontWeight: FontWeight.normal),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.info_outline_rounded, size: AppSpacing.iconSm), SizedBox(width: AppSpacing.xs), Text('Infos')])),
                      Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.reviews_outlined, size: AppSpacing.iconSm), SizedBox(width: AppSpacing.xs), Text('Avis')])),
                      Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.photo_album_outlined, size: AppSpacing.iconSm), SizedBox(width: AppSpacing.xs), Text('Projets')])),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildInformationsTab(), _buildReviewsTab(), _buildProjectPhotosTab()],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white, // Match CustomAppBar background
        padding: EdgeInsets.all(AppSpacing.md),
        child: CustomButton(
          text: _isLoading || _checkingReservation
              ? 'Chargement...'
              : _hasActiveReservation
                  ? 'Réservation en cours'
                  : 'Réserver une prestation',
          onPressed: (_isLoading || _checkingReservation || _hasActiveReservation)
              ? null
              : () {
                  context.push(
                    '/clientHome/reservation/${widget.providerId}',
                    extra: {
                      'providerName': '${_userData['firstname'] ?? ''} ${_userData['lastname'] ?? ''}'.trim(),
                      'serviceName': _fetchedServiceName,
                    },
                  );
                },
          isPrimary: !_hasActiveReservation, // Primary only if no active reservation
          backgroundColor: _hasActiveReservation
              ? (isDarkMode ? AppColors.darkInputBackground : Colors.grey.shade200) // Different color for active reservation
              : (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen), // Match app bar text color
          textColor: _hasActiveReservation
              ? (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary) // Different text color
              : Colors.white, // Primary button text color is white
          icon: _isLoading || _checkingReservation
              ? null // No icon during loading
              : _hasActiveReservation
                  ? Icon(Icons.event_note_outlined, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary) // Icon for active reservation
                  : const Icon(Icons.calendar_today_outlined, color: Colors.white), // Icon for booking
          width: double.infinity,
          height: AppSpacing.buttonLarge,
          borderRadius: AppSpacing.radiusMd,
        ),
      ),
    );
  }
}

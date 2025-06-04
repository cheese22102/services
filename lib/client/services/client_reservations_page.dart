import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../front/app_colors.dart';
import '../../front/app_spacing.dart';
import '../../front/app_typography.dart';
import '../../front/custom_app_bar.dart';
import '../../front/marketplace_search.dart';

class ClientReservationsPage extends StatefulWidget {
  const ClientReservationsPage({super.key});

  @override
  State<ClientReservationsPage> createState() => _ClientReservationsPageState();
}

class _ClientReservationsPageState extends State<ClientReservationsPage> { // Removed with SingleTickerProviderStateMixin
  bool _isLoading = false;
  String? _currentUserId;
  // Removed TabController? _tabController;
  
  String? _selectedFilterStatus;
  final List<Map<String, String?>> _filterOptions = const [
    {'label': 'Toutes', 'value': null},
    {'label': 'En attente', 'value': 'pending'},
    {'label': 'Acceptées', 'value': 'approved'},
    {'label': 'Terminées', 'value': 'completed'},
    {'label': 'Refusées', 'value': 'rejected'},
    {'label': 'Annulées', 'value': 'cancelled'},
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isAscending = false;

  // Pagination and infinite scrolling variables
  final ScrollController _scrollController = ScrollController();
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  final int _pageSize = 10;

  List<Map<String, dynamic>> _allReservations = [];
  List<Map<String, dynamic>> _filteredAndSortedReservations = [];

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    // Removed _tabController initialization
    _selectedFilterStatus = _filterOptions.first['value'];
    _loadInitialReservations();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    // Removed _tabController?.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && _hasMore && !_isFetchingMore) {
      _loadMoreReservations();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
      _applyFiltersAndSort();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _applyFiltersAndSort();
    });
  }
  
  Future<Map<String, dynamic>> _fetchReservationsPage({String? status, DocumentSnapshot? startAfterDocument}) async {
    Query query = FirebaseFirestore.instance
        .collection('reservations')
        .where('userId', isEqualTo: _currentUserId);
    
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    
    query = query.orderBy('createdAt', descending: !_isAscending);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }
    query = query.limit(_pageSize);

    final snapshot = await query.get();
    List<Map<String, dynamic>> combinedReservations = [];

    for (var doc in snapshot.docs) {
      final reservationData = doc.data() as Map<String, dynamic>;
      final providerId = reservationData['providerId'] as String?;
      
      String providerName = 'Prestataire Inconnu';
      String? providerPhotoURL;

      if (providerId != null) {
        final providerDoc = await FirebaseFirestore.instance.collection('users').doc(providerId).get();
        if (providerDoc.exists) {
          final userData = providerDoc.data() as Map<String, dynamic>;
          providerName = '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}'.trim();
          providerName = providerName.isEmpty ? 'Prestataire Inconnu' : providerName;
          providerPhotoURL = userData['avatarUrl'] as String?;
        }
      }
      
      combinedReservations.add({
        ...reservationData,
        'id': doc.id,
        'fetchedProviderName': providerName,
        'fetchedProviderPhotoURL': providerPhotoURL,
      });
    }
    return {
      'reservations': combinedReservations,
      'lastDocument': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    };
  }

  Future<void> _loadInitialReservations() async {
    setState(() {
      _isLoading = true;
      _allReservations.clear();
      _filteredAndSortedReservations.clear();
      _lastDocument = null;
      _hasMore = true;
    });

    try {
      final result = await _fetchReservationsPage(status: _selectedFilterStatus);
      final newReservations = result['reservations'] as List<Map<String, dynamic>>;
      final lastDoc = result['lastDocument'] as DocumentSnapshot?;
      if (mounted) {
        setState(() {
          _allReservations = newReservations;
          _lastDocument = lastDoc;
          _hasMore = newReservations.length == _pageSize;
          _applyFiltersAndSort();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading initial reservations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des réservations: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreReservations() async {
    if (!_hasMore || _isFetchingMore || _lastDocument == null) return;

    setState(() => _isFetchingMore = true);

    try {
      final result = await _fetchReservationsPage(status: _selectedFilterStatus, startAfterDocument: _lastDocument);
      final newReservations = result['reservations'] as List<Map<String, dynamic>>;
      final lastDoc = result['lastDocument'] as DocumentSnapshot?;
      if (mounted) {
        setState(() {
          _allReservations.addAll(newReservations);
          _lastDocument = lastDoc;
          _hasMore = newReservations.length == _pageSize;
          _applyFiltersAndSort();
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more reservations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement de plus de réservations: $e')),
        );
        setState(() => _isFetchingMore = false);
      }
    }
  }

  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> temp = List.from(_allReservations);

    if (_searchQuery.isNotEmpty) {
      temp = temp.where((reservation) {
        final serviceName = (reservation['serviceName'] as String? ?? '').toLowerCase();
        final providerName = (reservation['fetchedProviderName'] as String? ?? '').toLowerCase();
        return serviceName.contains(_searchQuery) || providerName.contains(_searchQuery);
      }).toList();
    }

    if (mounted) {
      setState(() {
        _filteredAndSortedReservations = temp;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground,
      appBar: CustomAppBar(
        title: 'Mes réservations',
        showBackButton: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Column(
              children: [
                MarketplaceSearch(
                  controller: _searchController,
                  hintText: 'Rechercher par service ou prestataire...',
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                            color: isDarkMode ? AppColors.darkBorderColor.withOpacity(0.3) : AppColors.lightBorderColor.withOpacity(0.3),
                          ),
                        ),
                        child: DropdownButtonFormField<String?>(
                          value: _selectedFilterStatus,
                          decoration: InputDecoration(
                            labelText: 'Filtrer par statut',
                            filled: true,
                            fillColor: Colors.transparent, // Background handled by parent Container
                            border: InputBorder.none, // Remove default border
                            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            labelStyle: AppTypography.bodyMedium(context).copyWith(
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          icon: Icon( // Control the default icon
                            Icons.arrow_drop_down,
                            color: isDarkMode ? AppColors.darkTextPrimary : AppColors.primaryDarkGreen, // Ensure visible icon
                          ),
                          items: _filterOptions.map((option) {
                            return DropdownMenuItem<String?>(
                              value: option['value'],
                              child: Text(
                                option['label']!,
                                style: AppTypography.bodyMedium(context).copyWith(
                                  color: isDarkMode ? AppColors.darkTextPrimary : AppColors.primaryDarkGreen, // Ensure visible text in dropdown items
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedFilterStatus = newValue;
                              _loadInitialReservations();
                            });
                          },
                          style: AppTypography.bodyMedium(context).copyWith(
                            color: isDarkMode ? AppColors.darkTextPrimary : AppColors.primaryDarkGreen, // Ensure visible selected text
                          ),
                          dropdownColor: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isAscending = !_isAscending;
                          _loadInitialReservations();
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isDarkMode ? AppColors.darkInputBackground : AppColors.lightCardBackground,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                            color: isDarkMode ? AppColors.darkBorderColor.withOpacity(0.3) : AppColors.lightBorderColor.withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          _isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          size: AppSpacing.iconMd,
                          color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading && _filteredAndSortedReservations.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    ),
                  )
                : _filteredAndSortedReservations.isEmpty && !_hasMore && !_isFetchingMore
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty ? Icons.search_off : Icons.calendar_today_outlined,
                              size: AppSpacing.iconXl,
                              color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                            ),
                            SizedBox(height: AppSpacing.sm),
                            Text(
                              _searchQuery.isNotEmpty ? 'Aucune réservation trouvée pour votre recherche' : 'Aucune réservation trouvée',
                              style: AppTypography.bodyMedium(context).copyWith(
                                color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: EdgeInsets.all(AppSpacing.md),
                        itemCount: _filteredAndSortedReservations.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (context, index) => SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          if (index == _filteredAndSortedReservations.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                ),
                              ),
                            );
                          }

                          final reservation = _filteredAndSortedReservations[index];
                          final reservationId = reservation['id'] as String;
                          final providerName = reservation['fetchedProviderName'] as String?;
                          final providerPhotoURL = reservation['fetchedProviderPhotoURL'] as String?;
                          
                          return GestureDetector(
                            onTap: () {
                              context.go('/clientHome/reservation-details/$reservationId');
                            },
                            child: Card(
                              elevation: AppSpacing.xxs,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              ),
                              color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            reservation['serviceName'] ?? 'Service',
                                            style: AppTypography.bodyLarge(context).copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: isDarkMode ? Colors.white : Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        _buildStatusBadge(
                                          context,
                                          reservation['status'] ?? 'pending',
                                          isDarkMode,
                                          providerCompletionStatus: reservation['providerCompletionStatus'],
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: AppSpacing.md),
                                    Row(
                                      children: [
                                        Container(
                                          width: AppSpacing.iconXl,
                                          height: AppSpacing.iconXl,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                                            image: providerPhotoURL != null && providerPhotoURL.isNotEmpty
                                                ? DecorationImage(
                                                    image: NetworkImage(providerPhotoURL),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: (providerPhotoURL == null || providerPhotoURL.isEmpty)
                                              ? Icon(
                                                  Icons.person,
                                                  color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                                                  size: AppSpacing.iconLg,
                                                )
                                              : null,
                                        ),
                                        SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Prestataire: ${providerName ?? 'Non spécifié'}',
                                                style: AppTypography.labelLarge(context).copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  color: isDarkMode ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                              if (reservation['scheduledDate'] != null) ...[
                                                SizedBox(height: AppSpacing.xs),
                                                Text(
                                                  'Date: ${_formatDate(reservation['scheduledDate'])}',
                                                  style: AppTypography.bodySmall(context).copyWith(
                                                    color: isDarkMode ? Colors.white70 : Colors.black54,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusBadge(BuildContext context, String status, bool isDarkMode, {dynamic providerCompletionStatus = false}) {
    Color badgeColor;
    String statusText;
    
    bool isProviderCompleted = false;
    if (providerCompletionStatus is bool) {
      isProviderCompleted = providerCompletionStatus;
    } else if (providerCompletionStatus is String) {
      isProviderCompleted = providerCompletionStatus == 'true';
    }
    
    if (status == 'approved' && isProviderCompleted) {
      badgeColor = Colors.purple;
      statusText = 'À confirmer';
    } else {
      switch (status) {
        case 'approved':
          badgeColor = Colors.green;
          statusText = 'Acceptée';
          break;
        case 'cancelled':
          badgeColor = Colors.red;
          statusText = 'Annulée';
          break;
        case 'rejected':
          badgeColor = Colors.red;
          statusText = 'Refusée';
          break;
        case 'completed':
          badgeColor = Colors.blue;
          statusText = 'Terminée';
          break;
        case 'pending':
        default:
          badgeColor = Colors.orange;
          statusText = 'En attente';
          break;
      }
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Text(
        statusText,
        textAlign: TextAlign.center,
        style: AppTypography.labelSmall(context).copyWith(
          color: badgeColor,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }
  
  // Helper method to format dates
  String _formatDate(dynamic date) {
    if (date == null) return 'Non spécifiée';
    
    try {
      if (date is Timestamp) {
        final dateTime = date.toDate();
        return DateFormat('dd/MM/yyyy à HH:mm').format(dateTime);
      } else if (date is String) {
        final dateTime = DateTime.parse(date);
        return DateFormat('dd/MM/yyyy à HH:mm').format(dateTime);
      }
    } catch (e) {
      // Handle parsing errors
    }
    
    return 'Non spécifiée';
  }
  
}

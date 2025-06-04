import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/app_spacing.dart';
import '../../front/app_typography.dart';
import '../../front/marketplace_search.dart';
import '../../models/reclamation_model.dart';

class ClientReclamationsPage extends StatefulWidget {
  const ClientReclamationsPage({super.key});

  @override
  State<ClientReclamationsPage> createState() => _ClientReclamationsPageState();
}

class _ClientReclamationsPageState extends State<ClientReclamationsPage> {
  bool _isLoading = false;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  String? _selectedFilterStatus;
  final List<Map<String, String?>> _filterOptions = const [
    {'label': 'Toutes', 'value': null},
    {'label': 'En attente', 'value': 'pending'},
    {'label': 'Traitées', 'value': 'resolved'}, // Changed from 'Acceptées' to 'Traitées'
    {'label': 'Rejetées', 'value': 'rejected'}, // Added 'Rejetées'
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isAscending = false; // For sorting by date (createdAt)

  // Pagination and infinite scrolling variables
  final ScrollController _scrollController = ScrollController();
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  final int _pageSize = 10;

  List<Map<String, dynamic>> _allReclamations = [];
  List<Map<String, dynamic>> _filteredAndSortedReclamations = [];
  
  @override
  void initState() {
    super.initState();
    _selectedFilterStatus = _filterOptions.first['value'];
    _loadInitialReclamations();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && _hasMore && !_isFetchingMore) {
      _loadMoreReclamations();
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
  
  Future<Map<String, dynamic>> _fetchReclamationsPage({String? status, DocumentSnapshot? startAfterDocument}) async {
    if (currentUserId == null) {
      return {'reclamations': [], 'lastDocument': null};
    }

    Query query = FirebaseFirestore.instance
        .collection('reclamations')
        .where('submitterId', isEqualTo: currentUserId);
    
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    
    query = query.orderBy('createdAt', descending: !_isAscending);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }
    query = query.limit(_pageSize);

    final snapshot = await query.get();
    List<Map<String, dynamic>> combinedReclamations = [];

    for (var doc in snapshot.docs) {
      final reclamationData = doc.data() as Map<String, dynamic>;
      final reservationId = reclamationData['reservationId'] as String?;
      
      String providerName = 'Prestataire Inconnu';
      String serviceName = 'Service Inconnu';

      if (reservationId != null) {
        final reservationDoc = await FirebaseFirestore.instance.collection('reservations').doc(reservationId).get();
        if (reservationDoc.exists) {
          final reservationData = reservationDoc.data() as Map<String, dynamic>;
          serviceName = reservationData['serviceName'] as String? ?? 'Service Inconnu';
          final providerId = reservationData['providerId'] as String?;

          if (providerId != null) {
            final providerUserDoc = await FirebaseFirestore.instance.collection('users').doc(providerId).get();
            if (providerUserDoc.exists) {
              final providerUserData = providerUserDoc.data() as Map<String, dynamic>;
              providerName = '${providerUserData['firstname'] ?? ''} ${providerUserData['lastname'] ?? ''}'.trim();
              providerName = providerName.isEmpty ? 'Prestataire Inconnu' : providerName;
            }
          }
        }
      }

      combinedReclamations.add({
        ...reclamationData,
        'id': doc.id,
        'fetchedProviderName': providerName,
        'fetchedServiceName': serviceName,
      });
    }
    return {
      'reclamations': combinedReclamations,
      'lastDocument': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    };
  }

  Future<void> _loadInitialReclamations() async {
    setState(() {
      _isLoading = true;
      _allReclamations.clear();
      _filteredAndSortedReclamations.clear();
      _lastDocument = null;
      _hasMore = true;
    });

    try {
      final result = await _fetchReclamationsPage(status: _selectedFilterStatus);
      final newReclamations = result['reclamations'] as List<Map<String, dynamic>>;
      final lastDoc = result['lastDocument'] as DocumentSnapshot?;
      if (mounted) {
        setState(() {
          _allReclamations = newReclamations;
          _lastDocument = lastDoc;
          _hasMore = newReclamations.length == _pageSize;
          _applyFiltersAndSort();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading initial reclamations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des réclamations: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreReclamations() async {
    if (!_hasMore || _isFetchingMore || _lastDocument == null) return;

    setState(() => _isFetchingMore = true);

    try {
      final result = await _fetchReclamationsPage(status: _selectedFilterStatus, startAfterDocument: _lastDocument);
      final newReclamations = result['reclamations'] as List<Map<String, dynamic>>;
      final lastDoc = result['lastDocument'] as DocumentSnapshot?;
      if (mounted) {
        setState(() {
          _allReclamations.addAll(newReclamations);
          _lastDocument = lastDoc;
          _hasMore = newReclamations.length == _pageSize;
          _applyFiltersAndSort();
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more reclamations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement de plus de réclamations: $e')),
        );
        setState(() => _isFetchingMore = false);
      }
    }
  }

  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> temp = List.from(_allReclamations);

    if (_searchQuery.isNotEmpty) {
      temp = temp.where((reclamation) {
        final title = (reclamation['title'] as String? ?? '').toLowerCase();
        final description = (reclamation['description'] as String? ?? '').toLowerCase();
        final providerName = (reclamation['fetchedProviderName'] as String? ?? '').toLowerCase(); // Added
        final serviceName = (reclamation['fetchedServiceName'] as String? ?? '').toLowerCase(); // Added
        return title.contains(_searchQuery) || 
               description.contains(_searchQuery) ||
               providerName.contains(_searchQuery) || // Added
               serviceName.contains(_searchQuery); // Added
      }).toList();
    }

    // Sorting is handled by Firestore query, so no client-side sort needed here
    // unless we introduce other client-side filters.

    if (mounted) {
      setState(() {
        _filteredAndSortedReclamations = temp;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground, // Consistent background
      appBar: CustomAppBar(
        title: 'Mes réclamations',
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
                  hintText: 'Rechercher par titre, description, prestataire ou service...', // Updated hint
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode ? AppColors.darkInputBackground : Colors.white, // Changed to Colors.white for light mode visibility
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
                              _loadInitialReclamations();
                            });
                          },
                          style: AppTypography.bodyMedium(context).copyWith(
                            color: isDarkMode ? AppColors.darkTextPrimary : AppColors.primaryDarkGreen, // Ensure visible selected text
                          ),
                          dropdownColor: isDarkMode ? AppColors.darkCardBackground : Colors.white, // Changed to Colors.white for light mode visibility
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isAscending = !_isAscending;
                          _loadInitialReclamations();
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
            child: _isLoading && _filteredAndSortedReclamations.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    ),
                  )
                : _filteredAndSortedReclamations.isEmpty && !_hasMore && !_isFetchingMore // Corrected typo
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox_outlined, // Changed icon
                              size: AppSpacing.iconXl,
                              color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                            ),
                            SizedBox(height: AppSpacing.sm),
                            Text(
                              _searchQuery.isNotEmpty ? 'Aucune réclamation trouvée pour votre recherche' : 'Aucune réclamation trouvée', // Changed text
                              style: AppTypography.bodyMedium(context).copyWith(
                                color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.all(AppSpacing.md),
                        itemCount: _filteredAndSortedReclamations.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _filteredAndSortedReclamations.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                ),
                              ),
                            );
                          }

                          final reclamationData = _filteredAndSortedReclamations[index];
                          final reclamation = ReclamationModel.fromMap(reclamationData, reclamationData['id']);
                          final fetchedProviderName = reclamationData['fetchedProviderName'] as String?;
                          final fetchedServiceName = reclamationData['fetchedServiceName'] as String?;
                          
                          return _buildReclamationCard(
                            reclamation, 
                            isDarkMode,
                            fetchedProviderName,
                            fetchedServiceName,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReclamationCard(
    ReclamationModel reclamation, 
    bool isDarkMode,
    String? providerName, // Added
    String? serviceName, // Added
  ) {
    // Format the date
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    final createdAtDate = reclamation.createdAt.toDate();
    final formattedDate = dateFormat.format(createdAtDate);
    
    // Status color and text
    Color statusColor;
    String statusText;
    
    switch (reclamation.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'En attente';
        break;
      case 'resolved':
        statusColor = AppColors.primaryGreen; // Changed to AppColors.primaryGreen
        statusText = 'Traitée';
        break;
      case 'rejected':
        statusColor = AppColors.errorRed; // Changed to AppColors.errorRed
        statusText = 'Rejetée';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Inconnu';
    }
    
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.md), // Use AppSpacing
      elevation: 0, // Consistent with other cards
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
        side: BorderSide(
          color: isDarkMode ? AppColors.darkBorderColor.withOpacity(0.2) : AppColors.lightBorderColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, // Consistent with other cards
      child: InkWell(
        onTap: () {
          context.push('/clientHome/reclamations/details/${reclamation.id}');
        },
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md), // Use AppSpacing
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      reclamation.title,
                      style: AppTypography.h4(context).copyWith( // Use AppTypography
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs), // Use AppSpacing
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: AppTypography.labelSmall(context).copyWith( // Use AppTypography
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.verticalSpacing(AppSpacing.xs), // Use AppSpacing
              Text(
                'Prestataire: ${providerName ?? 'Non spécifié'}', // Display provider name
                style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                  color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              AppSpacing.verticalSpacing(AppSpacing.xxs), // Added spacing
              Text(
                'Service: ${serviceName ?? 'Non spécifié'}', // Display service name
                style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                  color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              AppSpacing.verticalSpacing(AppSpacing.sm), // Use AppSpacing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Soumise le $formattedDate',
                    style: AppTypography.labelSmall(context).copyWith( // Use AppTypography
                      color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                    ),
                  ),
                  // Removed image icon
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

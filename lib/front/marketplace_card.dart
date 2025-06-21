import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo; // Import geocoding with alias
import 'app_colors.dart';
import 'app_spacing.dart'; // Import AppSpacing
import 'app_typography.dart'; // Import AppTypography

class MarketplaceCard extends StatefulWidget {
  final String id;
  final String title;
  final double price;
  final String imageUrl;
  final String condition;
  final String location;
  final VoidCallback onTap;

  const MarketplaceCard({
    Key? key,
    required this.id,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.condition,
    required this.location,
    required this.onTap,
  }) : super(key: key);

  @override
  State<MarketplaceCard> createState() => _MarketplaceCardState();
}

class _MarketplaceCardState extends State<MarketplaceCard> {
  String _displayLocation = '';

  @override
  void initState() {
    super.initState();
    _getCityFromAddress(widget.location);
  }

  @override
  void didUpdateWidget(covariant MarketplaceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _getCityFromAddress(widget.location);
    }
  }

  Future<void> _getCityFromAddress(String address) async {
    if (address.isEmpty) {
      if (!mounted) return; // Add mounted check
      setState(() {
        _displayLocation = 'Inconnu';
      });
      return;
    }
    try {
      List<geo.Placemark> placemarks = await geo.GeocodingPlatform.instance!.placemarkFromAddress(address); // Use alias
      if (!mounted) return; // Add mounted check
      if (placemarks.isNotEmpty) {
        setState(() {
          _displayLocation = placemarks.first.locality ?? placemarks.first.subAdministrativeArea ?? 'Inconnu';
        });
      } else {
        setState(() {
          _displayLocation = 'Inconnu';
        });
      }
    } catch (e) {
      if (!mounted) return; // Add mounted check
      setState(() {
        _displayLocation = 'Inconnu';
      });
      debugPrint('Error getting city from address: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkCardBackground : Colors.white, // Use white for light mode
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image (takes available space)
            Expanded( // Use Expanded to make image flexible
              flex: 3, // Give more flex to image
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppSpacing.radiusMd), // Use AppSpacing
                  topRight: Radius.circular(AppSpacing.radiusMd), // Use AppSpacing
                ),
                child: SizedBox( // Wrap with SizedBox to explicitly set width
                  width: double.infinity, // Make it take full available width
                  child: widget.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_rounded,
                                  color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
                                  size: AppSpacing.iconLg, // Use AppSpacing
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) { // Added loadingBuilder
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported_rounded,
                              color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
                              size: AppSpacing.iconLg, // Use AppSpacing
                            ),
                          ),
                        ),
                ),
              ),
            ),
            
            // Product info (takes remaining space)
            Expanded( // Use Expanded to make info flexible
              flex: 2, // Give less flex to info
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.sm), // Use AppSpacing
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start, // Changed to MainAxisAlignment.start
                  children: [
                    // Title
                    Flexible( // Use Flexible for title
                      child: Text(
                        widget.title,
                        style: AppTypography.labelSmall(context).copyWith( // Reduced font size to labelSmall
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                        ),
                        maxLines: 2, // Allow two lines for title
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs), // Use AppSpacing
                    
                    // Price
                    Flexible( // Use Flexible for price
                      child: Text(
                        '${widget.price.toStringAsFixed(2)} DT', // Format price
                        style: AppTypography.labelMedium(context).copyWith( // Reduced font size to labelMedium
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Use AppColors
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs), // Use AppSpacing
                    
                    // Condition and location
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs), // Use AppSpacing
                          decoration: BoxDecoration(
                            color: widget.condition == 'Neuf'
                                ? Colors.green.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusXs), // Use AppSpacing
                          ),
                          child: Text(
                            widget.condition,
                            style: AppTypography.labelSmall(context).copyWith( // Use AppTypography
                              fontWeight: FontWeight.w500,
                              color: widget.condition == 'Neuf'
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.xs), // Use AppSpacing
                        Expanded( // Use Expanded for location
                          child: Text(
                            _displayLocation, // Use the extracted city
                            style: AppTypography.labelSmall(context).copyWith( // Use AppTypography
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class MarketplaceCard extends StatelessWidget {
  final String id;
  final String title;
  final double price;
  final String imageUrl;
  final String condition;
  final String location;
  final VoidCallback onTap;
  final double cardHeight; // New parameter
  final double imageHeight; // New parameter
  final double titleFontSize; // New parameter
  final double priceFontSize; // New parameter
  final double detailsFontSize; // New parameter

  const MarketplaceCard({
    Key? key,
    required this.id,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.condition,
    required this.location,
    required this.onTap,
    this.cardHeight = 210, // Default value
    this.imageHeight = 130, // Default value
    this.titleFontSize = 13, // Default value
    this.priceFontSize = 15, // Default value
    this.detailsFontSize = 10, // Default value
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: cardHeight, // Use parameter instead of fixed value
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade900 : Colors.white,
            borderRadius: BorderRadius.circular(12),
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
              // Product image with fixed height
              SizedBox(
                height: imageHeight, // Use parameter instead of fixed value
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_rounded,
                                  color: isDarkMode ? Colors.white54 : Colors.black38,
                                  size: 24,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported_rounded,
                              color: isDarkMode ? Colors.white54 : Colors.black38,
                              size: 24,
                            ),
                          ),
                        ),
                ),
              ),
              
              // Product info
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: titleFontSize, // Use parameter instead of fixed value
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    
                    // Price
                    Text(
                      '$price DT',
                      style: GoogleFonts.poppins(
                        fontSize: priceFontSize, // Use parameter instead of fixed value
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    
                    // Condition and location
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: condition == 'Neuf'
                                ? Colors.green.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            condition,
                            style: GoogleFonts.poppins(
                              fontSize: detailsFontSize, // Use parameter instead of fixed value
                              fontWeight: FontWeight.w500,
                              color: condition == 'Neuf'
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            location,
                            style: GoogleFonts.poppins(
                              fontSize: detailsFontSize, // Use parameter instead of fixed value
                              color: isDarkMode ? Colors.white70 : Colors.black54,
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
            ],
          ),
        ),
      ),
    );
  }
}
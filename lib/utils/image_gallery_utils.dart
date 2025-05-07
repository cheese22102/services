import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/app_colors.dart';


class ImageGalleryUtils {
  /// Builds a Facebook-like image gallery that adapts based on the number of images
  static Widget buildImageGallery(
    BuildContext context,
    List<String> imageUrls, {
    bool isDarkMode = false,
    double? fixedHeight,
  }) {
    // If fixedHeight is provided, wrap in a SizedBox to constrain height
    Widget gallery;
    
    // Facebook-like gallery layout
    switch (imageUrls.length) {
      case 0:
        gallery = const SizedBox.shrink(); // No images
        break;
      case 1:
        // Single image - show full width
        gallery = _buildSingleImage(context, imageUrls[0], isDarkMode);
        break;
      case 2:
        // Two images - side by side
        gallery = _buildTwoImages(context, imageUrls, isDarkMode);
        break;
      case 3:
        // Three images - one large, two small
        gallery = _buildThreeImages(context, imageUrls, isDarkMode);
        break;
      default:
        // 4 or more images - grid with "more" indicator
        gallery = _buildFourPlusImages(context, imageUrls, isDarkMode);
        break;
    }
    
    // Apply fixed height constraint if provided
    if (fixedHeight != null) {
      return SizedBox(
        height: fixedHeight,
        child: gallery,
      );
    }
    
    return gallery;
  }

  // Single image layout
  static Widget _buildSingleImage(BuildContext context, String imageUrl, bool isDarkMode) {
    return GestureDetector(
      onTap: () => showFullScreenImage(context, imageUrl),
      child: Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildNetworkImage(imageUrl, isDarkMode),
        ),
      ),
    );
  }

  // Two images layout
  static Widget _buildTwoImages(BuildContext context, List<String> imageUrls, bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => showFullScreenImage(context, imageUrls[0]),
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildNetworkImage(imageUrls[0], isDarkMode),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => showFullScreenImage(context, imageUrls[1]),
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildNetworkImage(imageUrls[1], isDarkMode),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Three images layout
  static Widget _buildThreeImages(BuildContext context, List<String> imageUrls, bool isDarkMode) {
    return Column(
      children: [
        // First image (large)
        GestureDetector(
          onTap: () => showFullScreenImage(context, imageUrls[0]),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildNetworkImage(imageUrls[0], isDarkMode),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Second row with two images
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => showFullScreenImage(context, imageUrls[1]),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildNetworkImage(imageUrls[1], isDarkMode),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => showFullScreenImage(context, imageUrls[2]),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildNetworkImage(imageUrls[2], isDarkMode),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Four or more images layout
  static Widget _buildFourPlusImages(BuildContext context, List<String> imageUrls, bool isDarkMode) {
    return Column(
      children: [
        // First row with two images
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => showFullScreenImage(context, imageUrls[0]),
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildNetworkImage(imageUrls[0], isDarkMode),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => showFullScreenImage(context, imageUrls[1]),
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildNetworkImage(imageUrls[1], isDarkMode),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Second row with two images (one might show "+X more")
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => showFullScreenImage(context, imageUrls[2]),
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildNetworkImage(imageUrls[2], isDarkMode),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // Show all images in a gallery view
                  showImageGallery(context, imageUrls);
                },
                child: Stack(
                  children: [
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildNetworkImage(imageUrls[3], isDarkMode),
                      ),
                    ),
                    if (imageUrls.length > 4)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '+${imageUrls.length - 3}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper method to build network image with loading and error handling
  static Widget _buildNetworkImage(String imageUrl, bool isDarkMode) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            color: isDarkMode 
                ? AppColors.primaryGreen 
                : AppColors.primaryDarkGreen,
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / 
                    (loadingProgress.expectedTotalBytes ?? 1)
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
        );
      },
    );
  }

  // Show a single image in full screen
  static void showFullScreenImage(BuildContext context, String imageUrl) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          appBar: AppBar(
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          body: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / 
                              (loadingProgress.expectedTotalBytes ?? 1)
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Impossible de charger l\'image',
                          style: GoogleFonts.poppins(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }



  // Show all images in a gallery view
  static void showImageGallery(BuildContext context, List<String> imageUrls) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          appBar: AppBar(
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            title: Text(
              'Toutes les photos',
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: PageView.builder(
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    imageUrls[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / 
                                  (loadingProgress.expectedTotalBytes ?? 1)
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 48,
                              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Impossible de charger l\'image',
                              style: GoogleFonts.poppins(
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    
  }

  /// Opens a full-screen image gallery with the provided images
  static void openImageGallery(
    BuildContext context,
    List<String> imageUrls, {
    int initialIndex = 0,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenGallery(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  static uploadMultipleImages(pickedImages, String s) {}
}

/// Full screen gallery widget for viewing images
class _FullScreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenGallery({
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1}/${widget.imageUrls.length}',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Center(
              child: Image.network(
                widget.imageUrls[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / 
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: AppColors.primaryGreen,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Impossible de charger l\'image',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
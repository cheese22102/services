import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/app_colors.dart';
import 'dart:io'; // Import for File

class ImageGalleryUtils {
  /// Builds a Facebook-like image gallery that adapts based on the number of images
  static Widget buildImageGallery(
    BuildContext context,
    List<dynamic> images, { // Changed to dynamic to accept File or String
    bool isDarkMode = false,
    double? fixedHeight,
    Function(int)? onRemoveImage, // Added onRemoveImage callback
  }) {
    // If fixedHeight is provided, wrap in a SizedBox to constrain height
    Widget gallery;
    
    // Facebook-like gallery layout
    switch (images.length) {
      case 0:
        gallery = const SizedBox.shrink(); // No images
        break;
      case 1:
        // Single image - show full width
        gallery = _buildSingleImage(context, images[0], isDarkMode, onRemoveImage != null ? () => onRemoveImage(0) : null);
        break;
      case 2:
        // Two images - side by side
        gallery = _buildTwoImages(context, images, isDarkMode, onRemoveImage);
        break;
      case 3:
        // Three images - one large, two small
        gallery = _buildThreeImages(context, images, isDarkMode, onRemoveImage);
        break;
      default:
        // 4 or more images - grid with "more" indicator
        gallery = _buildFourPlusImages(context, images, isDarkMode, onRemoveImage);
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

  // Helper to add delete button overlay
  static Widget _wrapWithDeleteButton(BuildContext context, Widget imageWidget, bool isDarkMode, Function()? onDelete) {
    if (onDelete == null) {
      return imageWidget;
    }
    return Stack(
      children: [
        imageWidget,
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Single image layout
  static Widget _buildSingleImage(BuildContext context, dynamic image, bool isDarkMode, Function()? onDelete) {
    return _wrapWithDeleteButton(
      context,
      GestureDetector(
        onTap: () => showFullScreenImage(context, image),
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
            child: _buildImageProvider(image, isDarkMode),
          ),
        ),
      ),
      isDarkMode,
      onDelete,
    );
  }

  // Two images layout
  static Widget _buildTwoImages(BuildContext context, List<dynamic> images, bool isDarkMode, Function(int)? onRemoveImage) {
    return Row(
      children: [
        Expanded(
          child: _wrapWithDeleteButton(
            context,
            GestureDetector(
              onTap: () => showFullScreenImage(context, images[0]),
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
                  child: _buildImageProvider(images[0], isDarkMode),
                ),
              ),
            ),
            isDarkMode,
            onRemoveImage != null ? () => onRemoveImage(0) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _wrapWithDeleteButton(
            context,
            GestureDetector(
              onTap: () => showFullScreenImage(context, images[1]),
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
                  child: _buildImageProvider(images[1], isDarkMode),
                ),
              ),
            ),
            isDarkMode,
            onRemoveImage != null ? () => onRemoveImage(1) : null,
          ),
        ),
      ],
    );
  }

  // Three images layout
  static Widget _buildThreeImages(BuildContext context, List<dynamic> images, bool isDarkMode, Function(int)? onRemoveImage) {
    return Column(
      children: [
        // First image (large)
        _wrapWithDeleteButton(
          context,
          GestureDetector(
            onTap: () => showFullScreenImage(context, images[0]),
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
                child: _buildImageProvider(images[0], isDarkMode),
              ),
            ),
          ),
          isDarkMode,
          onRemoveImage != null ? () => onRemoveImage(0) : null,
        ),
        const SizedBox(height: 8),
        // Second row with two images
        Row(
          children: [
            Expanded(
              child: _wrapWithDeleteButton(
                context,
                GestureDetector(
                  onTap: () => showFullScreenImage(context, images[1]),
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
                      child: _buildImageProvider(images[1], isDarkMode),
                    ),
                  ),
                ),
                isDarkMode,
                onRemoveImage != null ? () => onRemoveImage(1) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _wrapWithDeleteButton(
                context,
                GestureDetector(
                  onTap: () => showFullScreenImage(context, images[2]),
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
                      child: _buildImageProvider(images[2], isDarkMode),
                    ),
                  ),
                ),
                isDarkMode,
                onRemoveImage != null ? () => onRemoveImage(2) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Four or more images layout
  static Widget _buildFourPlusImages(BuildContext context, List<dynamic> images, bool isDarkMode, Function(int)? onRemoveImage) {
    return Column(
      children: [
        // First row with two images
        Row(
          children: [
            Expanded(
              child: _wrapWithDeleteButton(
                context,
                GestureDetector(
                  onTap: () => showFullScreenImage(context, images[0]),
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
                      child: _buildImageProvider(images[0], isDarkMode),
                    ),
                  ),
                ),
                isDarkMode,
                onRemoveImage != null ? () => onRemoveImage(0) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _wrapWithDeleteButton(
                context,
                GestureDetector(
                  onTap: () => showFullScreenImage(context, images[1]),
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
                      child: _buildImageProvider(images[1], isDarkMode),
                    ),
                  ),
                ),
                isDarkMode,
                onRemoveImage != null ? () => onRemoveImage(1) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Second row with two images (one might show "+X more")
        Row(
          children: [
            Expanded(
              child: _wrapWithDeleteButton(
                context,
                GestureDetector(
                  onTap: () => showFullScreenImage(context, images[2]),
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
                      child: _buildImageProvider(images[2], isDarkMode),
                    ),
                  ),
                ),
                isDarkMode,
                onRemoveImage != null ? () => onRemoveImage(2) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _wrapWithDeleteButton(
                context,
                GestureDetector(
                  onTap: () {
                    // Show all images in a gallery view
                    showImageGallery(context, images);
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
                          child: _buildImageProvider(images[3], isDarkMode),
                        ),
                      ),
                      if (images.length > 4)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '+${images.length - 3}',
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
                isDarkMode,
                onRemoveImage != null ? () => onRemoveImage(3) : null, // Pass index 3 for this image
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper method to build ImageProvider based on type (File or String)
  static Widget _buildImageProvider(dynamic image, bool isDarkMode) {
    ImageProvider imageProvider;
    if (image is File) {
      imageProvider = FileImage(image);
    } else if (image is String) {
      imageProvider = NetworkImage(image);
    } else {
      imageProvider = const AssetImage('assets/images/placeholder.png'); // Fallback
    }

    return Image(
      image: imageProvider,
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
  static void showFullScreenImage(BuildContext context, dynamic image) { // Made public
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
              child: Image(
                image: image is File ? FileImage(image) : NetworkImage(image),
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
  static void showImageGallery(BuildContext context, List<dynamic> images) { // Made public
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
            itemCount: images.length,
            itemBuilder: (context, index) {
              final item = images[index];
              ImageProvider imageProvider;
              if (item is File) {
                imageProvider = FileImage(item);
              } else if (item is String) {
                imageProvider = NetworkImage(item);
              } else {
                imageProvider = const AssetImage('assets/images/placeholder.png'); // Fallback
              }

              return InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: Image(
                    image: imageProvider,
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
    List<dynamic> images, { // Changed to dynamic
    int initialIndex = 0,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenGallery(
          images: images, // Pass dynamic list
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

/// Full screen gallery widget for viewing images
class _FullScreenGallery extends StatefulWidget {
  final List<dynamic> images; // Changed to dynamic
  final int initialIndex;

  const _FullScreenGallery({
    required this.images,
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
          '${_currentIndex + 1}/${widget.images.length}',
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
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final item = widget.images[index];
          ImageProvider imageProvider;
          if (item is File) {
            imageProvider = FileImage(item);
          } else if (item is String) {
            imageProvider = NetworkImage(item);
          } else {
            imageProvider = const AssetImage('assets/images/placeholder.png'); // Fallback
          }

          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Center(
              child: Image(
                image: imageProvider,
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

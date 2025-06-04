import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'cloudinary_service.dart';
import 'image_gallery_utils.dart'; // Add this import

class ImageUploadUtils {
  /// Pick multiple images from gallery
  static Future<List<File>> pickMultipleImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> pickedFiles = await picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1000,
      );
      
      if (pickedFiles.isEmpty) return [];
      
      // Convert XFile to File
      return pickedFiles.map((xFile) => File(xFile.path)).toList();
    } catch (e) {
      debugPrint('Error picking images: $e');
      return [];
    }
  }
  
  /// Pick a single image from gallery
  static Future<File?> pickSingleImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1000,
      );
      
      if (pickedFile == null) return null;
      
      return File(pickedFile.path);
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }
  
  /// Take a photo with camera
  static Future<File?> takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1000,
      );
      
      if (pickedFile == null) return null;
      
      return File(pickedFile.path);
    } catch (e) {
      debugPrint('Error taking photo: $e');
      return null;
    }
  }
  
  /// Show image source selection dialog (camera or gallery)
  static Future<File?> pickImageWithOptions(BuildContext context, {bool isDarkMode = false}) async {
    File? selectedImage;
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Choisir une source',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: Colors.blue,
                ),
                title: Text(
                  'Galerie',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  selectedImage = await pickSingleImage();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: Colors.blue,
                ),
                title: Text(
                  'Appareil photo',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  selectedImage = await takePhoto();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
    
    return selectedImage;
  }
  
  /// Pick multiple images with options dialog (camera or gallery)
  static Future<List<File>> pickMultipleImagesWithOptions(BuildContext context, {bool isDarkMode = false}) async {
    List<File> selectedImages = [];
    
    // Show the bottom sheet and wait for user selection
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Choisir une source',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Colors.blue,
                ),
                title: Text(
                  'Galerie',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop('gallery');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: Colors.blue,
                ),
                title: Text(
                  'Appareil photo',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop('camera');
                },
              ),
            ],
          ),
        );
      },
    );
    
    // Handle the user selection
    if (source == 'gallery') {
      selectedImages = await pickMultipleImages();
    } else if (source == 'camera') {
      final image = await takePhoto();
      if (image != null) {
        selectedImages.add(image);
      }
    }
    
    return selectedImages;
  }
  
  /// Upload multiple images to Cloudinary
  static Future<List<String>> uploadMultipleImages(List<File> imageFiles) async {
    if (imageFiles.isEmpty) return [];
    
    try {
      return await CloudinaryService.uploadImages(imageFiles);
    } catch (e) {
      debugPrint('Error uploading multiple images: $e');
      return [];
    }
  }
  
  /// Upload a single image to Cloudinary
  static Future<String?> uploadSingleImage(File imageFile) async {
    try {
      return await CloudinaryService.uploadImage(imageFile);
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }
  
  /// Build a horizontal image picker with preview and camera option
  static Widget buildImagePickerPreview({
    required List<dynamic> images, // Changed to dynamic to accept File or String
    required Function(int) onRemoveImage,
    required Function() onAddImages,
    required bool isLoading,
    bool isDarkMode = false,
    double height = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          SizedBox(
            height: height,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
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

                return Container( // Wrap each item in a Container for consistent margin
                  margin: const EdgeInsets.only(right: 8),
                  width: height,
                  height: height,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (item is String) { // Only open full screen for uploaded images (URLs)
                            ImageGalleryUtils.showFullScreenImage(context, item);
                          } else if (item is File) {
                            // For local files, you might want to show a temporary preview or do nothing
                            // For simplicity, we'll only enable full screen for uploaded images.
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                            image: DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => onRemoveImage(index),
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
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: isLoading ? null : onAddImages,
          icon: Icon(
            Icons.add_photo_alternate,
            color: isDarkMode ? Colors.white : Colors.white, // Icon color
          ),
          label: Text(
            isLoading ? 'Chargement...' : 'Ajouter des photos',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.white, // Text color
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDarkMode ? Colors.blue.shade700 : Colors.blue, // Button background
            foregroundColor: isDarkMode ? Colors.white : Colors.white, // Splash color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8), // Rounded corners
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Padding
          ),
        ),
      ],
    );
  }
}

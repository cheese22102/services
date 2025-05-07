import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'cloudinary_service.dart';

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
    required List<String> imageUrls,
    required Function(int) onRemoveImage,
    required Function() onAddImages,  // Changed parameter type
    required bool isLoading,
    bool isDarkMode = false,
    double height = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrls.isNotEmpty)
          SizedBox(
            height: height,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: height,
                      height: height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                        image: DecorationImage(
                          image: NetworkImage(imageUrls[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
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
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: isLoading ? null : onAddImages,  // Fixed this line
          icon: const Icon(Icons.add_photo_alternate),
          label: Text(isLoading ? 'Chargement...' : 'Ajouter des photos'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
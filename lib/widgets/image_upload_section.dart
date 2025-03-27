import 'package:flutter/material.dart';
import 'dart:io';
import 'custom_card.dart';

class ImageUploadSection extends StatelessWidget {
  final List<File> images;
  final VoidCallback onPickImages;
  final Function(int) onRemoveImage;
  final bool isUploading;

  const ImageUploadSection({
    super.key,
    required this.images,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      title: "Images du produit",
      child: Column(
        children: [
          if (images.isEmpty)
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Ajouter des images",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: FileImage(images[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 16,
                        child: CircleAvatar(
                          backgroundColor: Colors.red,
                          radius: 16,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            color: Colors.white,
                            onPressed: () => onRemoveImage(index),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isUploading ? null : onPickImages,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text(isUploading ? "Chargement..." : "Ajouter des images"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/app_colors.dart';
import '../utils/rating_service.dart';

class ProviderRatingDialog extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String? reservationId;
  final VoidCallback? onRatingSubmitted;

  const ProviderRatingDialog({
    super.key,
    required this.providerId,
    required this.providerName,
    this.reservationId,
    this.onRatingSubmitted,
  });

  @override
  State<ProviderRatingDialog> createState() => _ProviderRatingDialogState();
}

class _ProviderRatingDialogState extends State<ProviderRatingDialog> {
  double _qualityRating = 0;
  double _timelinessRating = 0;
  double _priceRating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_qualityRating == 0 || _timelinessRating == 0 || _priceRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez attribuer une note pour chaque critère')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await RatingService.rateProvider(
        providerId: widget.providerId,
        qualityRating: _qualityRating,
        timelinessRating: _timelinessRating,
        priceRating: _priceRating,
        comment: _commentController.text,
        reservationId: widget.reservationId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onRatingSubmitted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merci pour votre évaluation!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildRatingSection(String title, double rating, Function(double) onRatingChanged) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return IconButton(
              icon: Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: index < rating ? Colors.amber : Colors.grey,
                size: 32,
              ),
              onPressed: () {
                onRatingChanged(index + 1);
              },
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Évaluer ${widget.providerName}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Quality rating
              _buildRatingSection(
                'Qualité du service',
                _qualityRating,
                (rating) => setState(() => _qualityRating = rating),
              ),
              const SizedBox(height: 16),
              
              // Timeliness rating
              _buildRatingSection(
                'Ponctualité',
                _timelinessRating,
                (rating) => setState(() => _timelinessRating = rating),
              ),
              const SizedBox(height: 16),
              
              // Price rating
              _buildRatingSection(
                'Rapport qualité-prix',
                _priceRating,
                (rating) => setState(() => _priceRating = rating),
              ),
              const SizedBox(height: 24),
              
              // Comment field
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Commentaire (optionnel)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                ),
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Submit button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Soumettre',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
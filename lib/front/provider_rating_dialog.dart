import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/app_colors.dart';
import '../front/app_spacing.dart'; // Assuming AppSpacing is available for consistent spacing
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

  // emojiRatingOptions list removed

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_qualityRating == 0 || _timelinessRating == 0 || _priceRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez attribuer une note pour chaque critère.', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.errorRed,
        ),
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
        comment: _commentController.text.trim(),
        reservationId: widget.reservationId,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close the dialog
        widget.onRatingSubmitted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merci pour votre évaluation !', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi de l\'évaluation: ${e.toString()}', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Widget _buildRatingSection(String title, double currentRating, Function(double) onRatingChanged) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white.withOpacity(0.85) : Colors.black.withOpacity(0.75),
          ),
        ),
        const SizedBox(height: AppSpacing.sm), 
        Row(
          mainAxisAlignment: MainAxisAlignment.center, // Center stars
          children: List.generate(5, (index) {
            return IconButton(
              iconSize: 36, 
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs), 
              icon: Icon(
                index < currentRating ? Icons.star_rounded : Icons.star_border_rounded,
                color: index < currentRating 
                       ? AppColors.warningOrange // Using warningOrange for filled stars
                       : (isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400),
              ),
              onPressed: () {
                onRatingChanged(index + 1.0); // Rating is 1 to 5
              },
              tooltip: "Note de ${index + 1}",
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
      backgroundColor: Colors.transparent, 
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg), 
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg), 
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg), 
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Évaluer ${widget.providerName}',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              
              _buildRatingSection(
                'Qualité du service',
                _qualityRating,
                (rating) => setState(() => _qualityRating = rating),
              ),
              const SizedBox(height: AppSpacing.md + AppSpacing.xs),
              
              _buildRatingSection(
                'Ponctualité',
                _timelinessRating,
                (rating) => setState(() => _timelinessRating = rating),
              ),
              const SizedBox(height: AppSpacing.md + AppSpacing.xs),
              
              _buildRatingSection(
                'Rapport qualité-prix',
                _priceRating,
                (rating) => setState(() => _priceRating = rating),
              ),
              const SizedBox(height: AppSpacing.lg),
              
              TextField(
                controller: _commentController,
                maxLines: 3,
                minLines: 2,
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Laissez un commentaire (optionnel)...',
                  hintStyle: GoogleFonts.poppins(color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                  filled: true,
                  fillColor: isDarkMode ? AppColors.darkInputBackground : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide.none, 
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5),
                  ),
                ),
              ),
              
              const SizedBox(height: AppSpacing.xl),
              
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md - AppSpacing.xxs), 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  elevation: _isSubmitting ? 0 : 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Soumettre l\'évaluation',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
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

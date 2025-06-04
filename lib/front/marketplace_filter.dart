import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart'; // Import AppSpacing
import 'app_typography.dart'; // Import AppTypography
import 'custom_button.dart';

class MarketplaceFilter extends StatefulWidget {
  final String condition;
  final bool sortByDateAsc;
  final RangeValues priceRange;
  final String? selectedLocation; // New parameter for selected location
  final Function({
    required String condition,
    required bool sortByDateAsc,
    required RangeValues priceRange,
    String? location, // New parameter for location
  }) onApply;
  final VoidCallback onReset;

  const MarketplaceFilter({
    super.key,
    required this.condition,
    required this.sortByDateAsc,
    required this.priceRange,
    required this.onApply,
    required this.onReset,
    this.selectedLocation, // Initialize new parameter
  });

  @override
  _MarketplaceFilterState createState() => _MarketplaceFilterState();
}

class _MarketplaceFilterState extends State<MarketplaceFilter> {
  late String _condition;
  late bool _sortByDateAsc;
  late RangeValues _priceRange;
  late String? _selectedProvince; // New state variable for selected province

  // List of 24 Tunisian provinces
  final List<String> _tunisianProvinces = const [
    'Tous', // Option to show all locations
    'Ariana', 'Béja', 'Ben Arous', 'Bizerte', 'Gabès', 'Gafsa', 'Jendouba',
    'Kairouan', 'Kasserine', 'Kébili', 'Kef', 'Mahdia', 'Manouba', 'Médenine',
    'Monastir', 'Nabeul', 'Sfax', 'Sidi Bouzid', 'Siliana', 'Sousse',
    'Tataouine', 'Tozeur', 'Tunis', 'Zaghouan'
  ];

  @override
  void initState() {
    super.initState();
    _condition = widget.condition;
    _sortByDateAsc = widget.sortByDateAsc;
    _priceRange = widget.priceRange;
    _selectedProvince = widget.selectedLocation; // Initialize from widget
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Condition filter
          Text(
            'État',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Wrap( // Changed to Wrap for better responsiveness
            spacing: 8, // Use a fixed spacing
            runSpacing: 8, // Use a fixed runSpacing
            children: [
              _buildConditionChip('All', 'Tous'),
              _buildConditionChip('Neuf', 'Neuf'),
              _buildConditionChip('Très bon', 'Très bon'),
              _buildConditionChip('Bon', 'Bon'),
              _buildConditionChip('Satisfaisant', 'Satisfaisant'),
            ],
          ),
          const SizedBox(height: 16),
          
          // Price range filter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prix',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '${_priceRange.start.toInt()} DT - ${_priceRange.end.toInt()} DT',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 10000,
            divisions: 100,
            activeColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            inactiveColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
            onChanged: (values) {
              setState(() {
                _priceRange = values;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Location filter (Dropdown for provinces)
          Text(
            'Localisation',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedProvince,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            ),
            dropdownColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
            style: AppTypography.bodyMedium(context).copyWith(
              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            icon: Icon(Icons.arrow_drop_down, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            onChanged: (String? newValue) {
              setState(() {
                _selectedProvince = newValue;
              });
            },
            items: _tunisianProvinces.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Réinitialiser',
                  onPressed: () {
                    setState(() {
                      _condition = 'All';
                      _sortByDateAsc = false;
                      _priceRange = const RangeValues(0, 10000);
                      _selectedProvince = 'Tous'; // Reset location
                    });
                    widget.onReset();
                  },
                  isPrimary: false,
                  height: 45,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomButton(
                  text: 'Appliquer',
                  onPressed: () {
                    widget.onApply(
                      condition: _condition,
                      sortByDateAsc: _sortByDateAsc,
                      priceRange: _priceRange,
                      location: _selectedProvince, // Pass selected location
                    );
                  },
                  height: 45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionChip(String value, String label) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _condition == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _condition = value;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm), // Use AppSpacing
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
              : (isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground), // Use AppColors
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl), // Use AppSpacing
          border: Border.all(
            color: isSelected
                ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                : (isDarkMode ? AppColors.darkBorder : AppColors.lightBorder), // Use AppColors
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge( // Use AppTypography
            context,
            color: isSelected
                ? Colors.white
                : (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary), // Use AppColors
          ),
        ),
      ),
    );
  }
}

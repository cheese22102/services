import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'custom_button.dart';

class MarketplaceFilter extends StatefulWidget {
  final String condition;
  final bool sortByDateAsc;
  final RangeValues priceRange;
  final Function({
    required String condition,
    required bool sortByDateAsc,
    required RangeValues priceRange,
  }) onApply;
  final VoidCallback onReset;

  const MarketplaceFilter({
    super.key,
    required this.condition,
    required this.sortByDateAsc,
    required this.priceRange,
    required this.onApply,
    required this.onReset,
  });

  @override
  _MarketplaceFilterState createState() => _MarketplaceFilterState();
}

class _MarketplaceFilterState extends State<MarketplaceFilter> {
  late String _condition;
  late bool _sortByDateAsc;
  late RangeValues _priceRange;

  @override
  void initState() {
    super.initState();
    _condition = widget.condition;
    _sortByDateAsc = widget.sortByDateAsc;
    _priceRange = widget.priceRange;
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
          Row(
            children: [
              _buildConditionChip('All', 'Tous'),
              const SizedBox(width: 8),
              _buildConditionChip('Neuf', 'Neuf'),
              const SizedBox(width: 8),
              _buildConditionChip('Occasion', 'Occasion'),
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
          
          // Sort order
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trier par date',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Switch(
                value: _sortByDateAsc,
                onChanged: (value) {
                  setState(() {
                    _sortByDateAsc = value;
                  });
                },
                activeColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              ),
            ],
          ),
          Text(
            _sortByDateAsc ? 'Plus ancien d\'abord' : 'Plus récent d\'abord',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Réinitialiser',
                  onPressed: () {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
              : (isDarkMode ? Colors.grey.shade800 : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
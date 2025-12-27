import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui'; // For ClipRect and BackdropFilter

class CustomSideNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomSideNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80, // Fixed width for sidebar
      decoration: BoxDecoration(
        // Right borders only
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF1A0000).withOpacity(0.8), // Dark red/black
            const Color(0xFF000000).withOpacity(0.9), // Black
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(5, 0), // Shadow to the right
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SafeArea(
            right: false, // Don't need safe area on right
            child: Container(
              color: Colors.black.withOpacity(0.2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   // Logo or spacing at top could go here
                   const SizedBox(height: 20),
                   
                   _buildNavItem(0, 'assets/icons/home.svg', 'assets/icons/home_red.svg'),
                   const SizedBox(height: 30),
                   
                   _buildNavItem(1, 'assets/icons/Search.svg', 'assets/icons/search_red.svg'),
                   const SizedBox(height: 30),
                   
                   _buildNavItem(2, 'assets/icons/explore.svg', 'assets/icons/explore_red.svg'),
                   const SizedBox(height: 30),
                   
                   _buildNavItem(3, 'assets/icons/favorite.svg', 'assets/icons/favorite_red.svg'),
                   const SizedBox(height: 30),
                   
                   _buildNavItem(4, 'assets/icons/profile.svg', 'assets/icons/profile_red.svg'),
                   
                   const Spacer(),
                   // Optional: Settings or Exit icon at bottom?
                   const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String inactiveIcon, String activeIcon) {
    final isActive = currentIndex == index;
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: SvgPicture.asset(
          isActive ? activeIcon : inactiveIcon,
          width: 24, 
          height: 24,
          colorFilter: isActive 
              ? null // Use original colors (red) for active
              : const ColorFilter.mode(Colors.white, BlendMode.srcIn), // Tint white for inactive
        ),
      ),
    );
  }
}

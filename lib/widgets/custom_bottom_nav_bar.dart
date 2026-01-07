import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui'; // For ClipRect and BackdropFilter

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // margin removed for docked look
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), // Rounded top only
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A0000).withOpacity(0.8), // Very dark red/black with opacity for glass
            const Color(0xFF000000).withOpacity(0.9), // Black
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, -5), // Shadow upwards
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SafeArea( // Added SafeArea to handle system gesture area
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), 
              color: Colors.black.withOpacity(0.2),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                        ? 500
                        : double.infinity,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(0, 'assets/icons/home.svg', 'assets/icons/home_red.svg'),
                      _buildNavItem(1, 'assets/icons/Search.svg', 'assets/icons/search_red.svg'),
                      _buildNavItem(2, 'assets/icons/explore.svg', 'assets/icons/explore_red.svg'),
                      _buildNavItem(3, 'assets/icons/favorite.svg', 'assets/icons/favorite_red.svg'),
                      _buildNavItem(4, 'assets/icons/profile.svg', 'assets/icons/profile_red.svg'),
                    ],
                  ),
                ),
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
        padding: const EdgeInsets.all(8),
        child: SvgPicture.asset(
          isActive ? activeIcon : inactiveIcon,
          width: 22, // Reduced from 28
          height: 22, // Reduced from 28
          // No color filter for active icon as we use the provided red assets
          // For inactive, we ensure they are white (assuming the SVG is white or we tint it)
          colorFilter: isActive 
              ? null // Use original colors (red) for active
              : const ColorFilter.mode(Colors.white, BlendMode.srcIn), // Tint white for inactive
        ),
      ),
    );
  }
}

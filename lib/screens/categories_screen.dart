import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'search_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CategoriesScreen extends StatefulWidget {
  final bool initialIsAnime;
  const CategoriesScreen({Key? key, this.initialIsAnime = true}) : super(key: key);

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late bool _isAnimeSelected;

  @override
  void initState() {
    super.initState();
    _isAnimeSelected = widget.initialIsAnime;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background as per UI
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(autoFocus: true))),
                     child: Icon(Icons.search, color: Colors.white, size: 28),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Custom Toggle Buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isAnimeSelected = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _isAnimeSelected ? const Color(0xFFE53935) : const Color(0xFF1F1F1F),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'ANIME',
                          style: TextStyle(
                            color: _isAnimeSelected ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isAnimeSelected = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: !_isAnimeSelected ? const Color(0xFFE53935) : const Color(0xFF1F1F1F),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'KOMIK',
                          style: TextStyle(
                            color: !_isAnimeSelected ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Grid
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount;
                    if (constraints.maxWidth > 1200) {
                      crossAxisCount = 6;
                    } else if (constraints.maxWidth > 900) {
                      crossAxisCount = 5;
                    } else if (constraints.maxWidth > 600) {
                      crossAxisCount = 3; // 3 columns for tablets/small windows
                    } else {
                      crossAxisCount = 2; // 2 columns for phones
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.0, // Match square-ish look
                      ),
                      itemCount: 8,
                      itemBuilder: (context, index) {
                        return _buildCategoryCard();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFF7F66), // Salmon/Coral color
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: AssetImage('assets/images/bg_categories.png'),
          fit: BoxFit.cover, // Pattern background
          opacity: 0.5, // Subtle pattern
        ),
      ),
      child: Stack(
        children: [
          // Character Image at Bottom Right
          Positioned(
            right: -15,
            bottom: -5,
            child: SvgPicture.asset(
              'assets/images/anime_categories.svg',
              height: 160, // Significantly larger to match design
              fit: BoxFit.contain,
            ),
          ),
          
          // Text Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Category',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: [
                       Shadow(blurRadius: 4, color: Colors.black26, offset: Offset(0, 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Soon',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
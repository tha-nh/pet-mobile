import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../login/login.dart';

class PetIntroPage extends StatefulWidget {
  const PetIntroPage({super.key});

  @override
  State<PetIntroPage> createState() => _PetIntroPageState();
}

class _PetIntroPageState extends State<PetIntroPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;
  late Timer _timer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  final List<String> heroImages = [
    'https://images.unsplash.com/photo-1552053831-71594a27632d?w=500&h=400&fit=crop&crop=faces',
    'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=500&h=400&fit=crop&crop=faces',
    'https://images.unsplash.com/photo-1425082661705-1834bfd09dca?w=500&h=400&fit=crop&crop=faces',
    'https://images.unsplash.com/photo-1583337130417-3346a1be7dee?w=500&h=400&fit=crop&crop=faces',
    'https://images.unsplash.com/photo-1548199973-03cce0bbc87b?w=500&h=400&fit=crop&crop=faces',
    'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?w=500&h=400&fit=crop&crop=faces',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
    _scaleController.forward();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        _currentPage = (_currentPage + 1) % heroImages.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    _animationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFFF6B6B) : const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F8),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildHeroPetGallery(),
                  const SizedBox(height: 24),
                  _buildWelcomeSection(),
                  const SizedBox(height: 24),
                  _buildQuoteSection(),
                  const SizedBox(height: 24),
                  _buildPetGallery(),
                  const SizedBox(height: 24),
                  _buildLoveSection(),
                  const SizedBox(height: 24),
                  _buildMemorySection(),
                  const SizedBox(height: 24),
                  _buildFinalMessage(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                    shadowColor: Colors.black.withOpacity(0.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Start Pet Care Journey',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.pets,
              size: 40,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to Pet Care',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2A2D3E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your companion for pet health and happiness',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPetGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adorable Friends',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2A2D3E),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: _pageController,
            itemCount: heroImages.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return AnimatedScale(
                scale: _currentPage == index ? 1.0 : 0.95,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          heroImages[index],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: const Color(0xFF3B82F6),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.pets,
                                size: 50,
                                color: Color(0xFF3B82F6),
                              ),
                            );
                          },
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Text(
                            _getPetDescription(index),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              heroImages.length,
                  (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 12 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index ? const Color(0xFF3B82F6) : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getPetDescription(int index) {
    final descriptions = [
      'Loyal Companion',
      'Playful Spirit',
      'Gentle Soul',
      'Adventurous Friend',
      'Cuddly Buddy',
      'Joyful Heart',
    ];
    return descriptions[index % descriptions.length];
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: const Offset(5, 5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            offset: const Offset(-5, -5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Discover the Joy of Pets',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2A2D3E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pets bring endless love and happiness to our lives. Let\'s celebrate them!',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteSection() {
    final quotes = [
      {
        'text': 'The better I get to know men, the more I find myself loving dogs.',
        'author': '- Charles de Gaulle',
        'emoji': '🐶',
        'color': Colors.white,
      },
      {
        'text': 'Cats choose us; we don\'t own them.',
        'author': '- Kristin Cast',
        'emoji': '🐱',
        'color': Colors.white,
      },
      {
        'text': 'Until one has loved an animal, a part of one\'s soul remains unawakened.',
        'author': '- Anatole France',
        'emoji': '❤️',
        'color': Colors.white,
      },
      {
        'text': 'Pets are humanizing. They remind us we have an obligation and responsibility to preserve and nurture and care for all life.',
        'author': '- James Cromwell',
        'emoji': '🌟',
        'color': Colors.white,
      },
      {
        'text': 'Animals are such agreeable friends—they ask no questions; they pass no criticisms.',
        'author': '- George Eliot',
        'emoji': '👼',
        'color': Colors.white,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Beautiful Quotes About Pets',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2A2D3E),
          ),
        ),
        const SizedBox(height: 16),
        ...quotes.map((quote) => Container(
          width: double.infinity, // <-- thêm dòng này
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: quote['color'] as Color?,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                offset: const Offset(5, 5),
                blurRadius: 10,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.7),
                offset: const Offset(-5, -5),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                quote['emoji'] as String,
                style: const TextStyle(fontSize: 30),
              ),
              const SizedBox(height: 12),
              Text(
                '"${quote['text']}"',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF2A2D3E),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                quote['author'] as String,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )),

      ],
    );
  }

  Widget _buildPetGallery() {
    final pets = [
      {
        'image': 'assets/images/dog.webp',
        'name': 'Loyal Dog',
        'description': 'Best companion ever',
      },
      {
        'image': 'assets/images/cat.jpeg',
        'name': 'Cute Cat',
        'description': 'Queen of the house',
      },
      {
        'image': 'assets/images/rabbit.png',
        'name': 'Adorable Rabbit',
        'description': 'Little snow ball',
      },
      {
        'image': 'assets/images/parrot.jpeg',
        'name': 'Singing Bird',
        'description': 'Family musician',
      },
      {
        'image': 'assets/images/hamster.jpeg',
        'name': 'Mini Hamster',
        'description': 'Tiny cute gem',
      },
      {
        'image': 'assets/images/turtle.jpeg',
        'name': 'Smart Turtle',
        'description': 'Home philosopher',
      },
      {
        'image': 'assets/images/fish.webp',
        'name': 'Gold Fish',
        'description': 'Brings luck and peace',
      },
      {
        'image': 'assets/images/hedgehog.jpg',
        'name': 'Cute Hedgehog',
        'description': 'Spiky warrior',
      },
      {
        'image': 'assets/images/horse.jpeg',
        'name': 'Mighty Horse',
        'description': 'Symbol of strength',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pet Family',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2A2D3E),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: pets.length,
          itemBuilder: (context, index) {
            final pet = pets[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    offset: const Offset(5, 5),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.7),
                    offset: const Offset(-5, -5),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.asset(
                      pet['image'] as String,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text(
                          pet['name'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2A2D3E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pet['description'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoveSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: const Offset(5, 5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            offset: const Offset(-5, -5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why We Love Pets',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2A2D3E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildLoveReason('🤗', 'Unconditional Love', 'They love us for who we are.'),
          _buildLoveReason('😊', 'Brings Happiness', 'Their presence fills us with joy.'),
          _buildLoveReason('🛡️', 'Protects Family', 'Always ready to guard our home.'),
          _buildLoveReason('🎈', 'Constant Companion', 'By our side through thick and thin.'),
        ],
      ),
    );
  }

  Widget _buildLoveReason(String emoji, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2A2D3E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemorySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: const Offset(5, 5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            offset: const Offset(-5, -5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Beautiful Memories',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2A2D3E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildMemoryCard('🎾', 'Playing in the Garden'),
              _buildMemoryCard('🍖', 'Delicious Meals'),
              _buildMemoryCard('😴', 'Sleeping Together'),
              _buildMemoryCard('🚗', 'Traveling Together'),
              _buildMemoryCard('🎂', 'Pet Birthday'),
              _buildMemoryCard('🏥', 'Caring When Sick'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Every moment with pets is a precious gift from life.',
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF2A2D3E),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: const Offset(5, 5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            offset: const Offset(-5, -5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🌟✨🌟', style: TextStyle(fontSize: 30)),
          const SizedBox(height: 12),
          Text(
            'Thank You for Loving Pets!',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2A2D3E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Pets are more than animals; they are friends, family, and endless inspiration.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('🐾 ', style: TextStyle(fontSize: 20)),
              Text('🤍 ', style: TextStyle(fontSize: 20)),
              Text('🐾 ', style: TextStyle(fontSize: 20)),
              Text('🤍 ', style: TextStyle(fontSize: 20)),
              Text('🐾', style: TextStyle(fontSize: 20)),
            ],
          ),
        ],
      ),
    );
  }
}
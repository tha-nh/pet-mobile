import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../appointments/appointment_detail.dart';
import '../models/appointment.dart';
import '../pet/add_pet.dart';

class Pet {
  final int id;
  final String name;
  final String avatar;
  final int age;
  final String breed;
  final String species;

  Pet({
    required this.id,
    required this.name,
    required this.avatar,
    required this.age,
    required this.breed,
    required this.species,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'],
      name: json['name'],
      avatar: json['avatar'] ?? "https://placehold.co/50x50",
      age: json['age'] ?? 0,
      breed: json['breed'] ?? "",
      species: json['species'] ?? "",
    );
  }
}

class Discovery {
  final int id;
  final String name;
  final String? location;
  final String? requirements;
  final IconData? icon;

  Discovery({required this.id, required this.name, this.location,  this.requirements, this.icon});

  factory Discovery.fromJson(Map<String, dynamic> json) {
    return Discovery(
      id: json['id'],
      name: json['name'],
      location: json['location'],
      requirements: json['requirements'],
      icon: json['icon'] != null ? IconData(json['icon'], fontFamily: 'MaterialIcons') : Icons.pets,
    );
  }
}

class BookingPage extends StatefulWidget {
  final Appointment? appointment; // Thêm tham số
  const BookingPage({Key? key, this.appointment}) : super(key: key);

  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> with TickerProviderStateMixin {
  DateTime? selectedDate;
  List<Pet> pets = [];
  Pet? selectedPet;
  List<Discovery> discoveries = [];
  Discovery? selectedDiscovery;
  bool loadingDiscoveries = true;
  bool loadingPets = true;
  bool isSubmitting = false;
  int? appointmentId; // Thêm để lưu ID nếu reschedule

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _buttonController;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadPets();
    _loadDiscoveries();

  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _scaleController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Future<int?> bookAppointment({
    required DateTime selectedDate,
    required int petId,
    required int discoveryId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final ownerId = prefs.getInt('userId') ?? 0;
    final body = jsonEncode({
      "petId": petId,
      "ownerId": ownerId,
      "discoveryId": discoveryId,
      "apptTime": selectedDate.toUtc().toIso8601String(),
      "createdAt": DateTime.now().toUtc().toIso8601String(),
      "status": "PENDING",
    });

    final url = Uri.parse("http://10.0.2.2:8080/api/appointments");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode != 201) {
      final errorMsg = json.decode(response.body)['error'] ?? '';
      throw Exception(errorMsg);
    }

    // Parse the created appointment ID from response
    final responseData = json.decode(response.body);
    return responseData['id'];
  }

  Future<void> _loadPets() async {
    setState(() => loadingPets = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId') ?? 0;

    try {
      final response = await http.get(Uri.parse("http://10.0.2.2:8080/api/pets/user/$userId"));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          pets = data.map((e) => Pet.fromJson(e)).toList();
          loadingPets = false;

        });
      } else {
        throw Exception("Failed to load pets: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => loadingPets = false);
      _showErrorSnackBar("Failed to load pets: $e");
    }
  }

  Future<void> _loadDiscoveries() async {
    setState(() => loadingDiscoveries = true);
    try {
      final response = await http.get(Uri.parse("http://10.0.2.2:8080/api/discoveries"));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          discoveries = data.map((e) => Discovery.fromJson(e)).toList();
          loadingDiscoveries = false;

        });
      } else {
        throw Exception("Failed to load discoveries!");
      }
    } catch (e) {
      setState(() => loadingDiscoveries = false);
      _showErrorSnackBar("Failed to load discoveries!");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
        backgroundColor: Color(0xFFE74C3C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
        backgroundColor: Color(0xFF27AE60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFEEF2F7),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF3B82F6).withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF8B5CF6).withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await Future.wait([_loadPets(), _loadDiscoveries()]);
                    },
                    color: Color(0xFF3B82F6),
                    strokeWidth: 3,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
                      physics: AlwaysScrollableScrollPhysics(),
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _buildScheduleForm(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _buildConfirmButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 40, 20, 24),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: Color(0xFF4A5568), size: 28),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Color(0xFFF7FAFC),
              shape: CircleBorder(),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Schedule Appointment',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A202C),
                  ),
                ),
                Text(
                  'Book a discovery session for your pet',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleForm() {
    if (loadingPets) {
      return _buildLoadingCard('Loading your pets...');
    }

    if (pets.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 32),
          Icon(
            Icons.pets_rounded,
            size: 64,
            color: Color(0xFF718096),
          ),
          SizedBox(height: 16),
          Text(
            'No Pets Found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A202C),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You don\'t have any pets yet. Add a pet to schedule an appointment!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Color(0xFF718096),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              // Chuyển hướng sang AddPetPage
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddPetPage()),
              );
              // Nếu thêm thú cưng thành công, làm mới danh sách pets
              if (result == true) {
                await _loadPets();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              'Add New Pet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildStepIndicator(),
        SizedBox(height: 32),
        _buildPetSection(),
        SizedBox(height: 24),
        _buildDateSection(),
        SizedBox(height: 24),
        _buildDiscoverySection(),
        SizedBox(height: 32),
        if (selectedPet != null && selectedDate != null && selectedDiscovery != null)
          _buildSummaryCard(),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF3B82F6).withOpacity(0.08),
              offset: Offset(0, 4),
              blurRadius: 20,
            ),
          ],
        ),
        child: Row(
          children: [
            _buildStep(1, selectedPet != null, 'Pet'),
            _buildStepConnector(selectedPet != null),
            _buildStep(2, selectedDate != null, 'Date'),
            _buildStepConnector(selectedDate != null),
            _buildStep(3, selectedDiscovery != null, 'Service'),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int step, bool isCompleted, String label) {
    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted ? Color(0xFF10B981) : Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                step.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isCompleted ? Color(0xFF10B981) : Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: 40,
      height: 2,
      color: isActive ? Color(0xFF10B981) : Color(0xFFE2E8F0),
      margin: EdgeInsets.only(bottom: 20),
    );
  }

  Widget _buildPetSection() {
    return _buildSection(
      title: 'Select Your Pet',
      subtitle: 'Choose which pet needs the appointment',
      icon: Icons.pets_rounded,
      child: _buildPetSelector(),
    );
  }

  Widget _buildDateSection() {
    return _buildSection(
      title: 'Choose Date',
      subtitle: 'Select your preferred appointment date',
      icon: Icons.today_rounded,
      child: _buildDateSelector(),
    );
  }

  Widget _buildDiscoverySection() {
    return _buildSection(
      title: 'Select Service',
      subtitle: 'Pick the discovery service you need',
      icon: Icons.explore_rounded,
      child: _buildDiscoverySelector(),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF000000).withOpacity(0.04),
              offset: Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6).withOpacity(0.1), Color(0xFF8B5CF6).withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Color(0xFF3B82F6), size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A202C),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Color(0xFF718096),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPetSelector() {
    if (loadingPets) {
      return _buildLoadingCard('Loading your pets...');
    }

    return Column(
      children: pets.map((pet) {
        final isSelected = selectedPet?.id == pet.id;
        return GestureDetector(
          onTap: () {
            setState(() {
              selectedPet = pet;
            });
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Color(0xFF3B82F6).withOpacity(0.1) : Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Color(0xFF3B82F6) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Color(0xFF3B82F6) : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundImage: CachedNetworkImageProvider(pet.avatar),
                    backgroundColor: Colors.grey[200],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A202C),
                        ),
                      ),
                      Text(
                        '${pet.species} • ${pet.breed} • ${pet.age} years old',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Color(0xFF718096),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: Colors.white, size: 16),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: ColorScheme.light(
                  primary: Color(0xFF3B82F6),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                ),
                dialogBackgroundColor: Colors.white,
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            selectedDate = picked;
          });
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selectedDate != null ? Color(0xFF3B82F6).withOpacity(0.1) : Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectedDate != null ? Color(0xFF3B82F6) : Color(0xFFE2E8F0),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selectedDate != null ? Color(0xFF3B82F6) : Color(0xFF64748B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.calendar_today, color: Colors.white, size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedDate != null
                        ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                        : 'Tap to select date',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: selectedDate != null ? Color(0xFF1A202C) : Color(0xFF64748B),
                    ),
                  ),
                  if (selectedDate != null)
                    Text(
                      _getFormattedDate(selectedDate!),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Color(0xFF718096),
                      ),
                    ),
                ],
              ),
            ),
            if (selectedDate != null)
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverySelector() {
    if (loadingDiscoveries) {
      return _buildLoadingCard('Loading available services...');
    }

    return Column(
      children: discoveries.map((discovery) {
        final isSelected = selectedDiscovery?.id == discovery.id;
        return GestureDetector(
          onTap: () {
            setState(() {
              selectedDiscovery = discovery;
            });
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Color(0xFF3B82F6).withOpacity(0.1) : Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Color(0xFF3B82F6) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFF3B82F6) : Color(0xFF64748B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    discovery.icon ?? Icons.explore,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        discovery.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A202C),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[700]),
                          const SizedBox(width: 4),
                          Expanded(  // Wrap Text location
                            child: Text(
                              discovery.location ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,  // Thêm để cắt text dài
                              maxLines: 1,  // Giới hạn 1 dòng
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.assignment, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(  // Wrap Text requirements
                            child: Text(
                              discovery.requirements ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,  // Thêm để cắt text dài
                              maxLines: 1,  // Giới hạn 1 dòng
                            ),
                          ),
                        ],
                      ),

                    ],
                  ),
                ),

                if (isSelected)
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: Colors.white, size: 16),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoadingCard(String message) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
          ),
          SizedBox(width: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF3B82F6).withOpacity(0.3),
              offset: Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_turned_in, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'Appointment Summary',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildSummaryRow('Pet', selectedPet!.name, Icons.pets),
            _buildSummaryRow('Date', '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}', Icons.calendar_today),
            _buildSummaryRow('Service', selectedDiscovery!.name, Icons.explore),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          SizedBox(width: 12),
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    if (pets.isEmpty || loadingPets) {
      return SizedBox.shrink(); // Không hiển thị nút khi không có thú cưng hoặc đang tải
    }

    final bool canConfirm = selectedPet != null && selectedDate != null && selectedDiscovery != null;

    return ScaleTransition(
      scale: _buttonAnimation,
      child: GestureDetector(
        onTapDown: (_) => _buttonController.forward(),
        onTapUp: (_) => _buttonController.reverse(),
        onTapCancel: () => _buttonController.reverse(),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            gradient: canConfirm && !isSubmitting
                ? LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : LinearGradient(
              colors: [Color(0xFFCBD5E0), Color(0xFFA0AEC0)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: canConfirm && !isSubmitting
                ? [
              BoxShadow(
                color: Color(0xFF10B981).withOpacity(0.4),
                offset: Offset(0, 8),
                blurRadius: 20,
              ),
            ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: canConfirm && !isSubmitting
                  ? () async {
                final bool? confirmed = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        "Confirm Booking",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: const Color(0xFF1A202C),
                        ),
                      ),
                      content: Text(
                        "Do you want to book this appointment?",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: Text(
                            "Cancel",
                            style: GoogleFonts.poppins(color: Colors.red),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: Text(
                            "Confirm",
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ),
                      ],
                    );
                  },
                );

                if (confirmed == true) {
                  _confirmAppointment();
                }
              }
                  : null,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSubmitting) ...[
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                    ],
                    Text(
                      "Book",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmAppointment() async {
    if (selectedPet == null) {
      _showErrorSnackBar("Please select a pet first!");
      return;
    }
    if (selectedDate == null) {
      _showErrorSnackBar("Please select a date first!");
      return;
    }
    if (selectedDiscovery == null) {
      _showErrorSnackBar("Please select a discovery service!");
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final newAppointmentId = await bookAppointment(
        selectedDate: selectedDate!,
        petId: selectedPet!.id,
        discoveryId: selectedDiscovery!.id,
      );

      if (newAppointmentId == null) {
        throw Exception('Không nhận được ID appointment mới');
      }

      // Hiển thị thông báo thành công
      _showSuccessSnackBar("Appointment booked successfully!");

      // Navigate đến AppointmentDetailPage với appointment mới
      final newAppointment = Appointment(
        id: newAppointmentId,
        petId: selectedPet!.id,
        // ownerId: (await SharedPreferences.getInstance()).getInt('userId') ?? 0,
        discoveryId: selectedDiscovery!.id,
        apptTime: selectedDate,
        status: 'PENDING',
        // Các field khác có thể fetch sau nếu cần, nhưng tạm dùng từ selection
        petName: selectedPet!.name,
        petSpecies: selectedPet!.species,
        petBreed: selectedPet!.breed,
        petAge: selectedPet!.age,
        petAvatar: selectedPet!.avatar,
        discoveryName: selectedDiscovery!.name,
        location: selectedDiscovery!.location ?? 'Hà Nội', // Default nếu null
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AppointmentDetailPage(appointment: newAppointment),
        ),
      );
    } catch (e) {
      _showErrorSnackBar("Failed to book appointment: $e");
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  String _getFormattedDate(DateTime date) {
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    return '${weekdays[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}';
  }
}
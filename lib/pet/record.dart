import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/pet.dart';
import 'add_pet.dart'; // Import AddPetPage

class HealthRecord {
  final int id;
  final int petId;
  final int vetId;
  final int apptId;
  final String? diagnosis;
  final String? treatment;
  final String? notes;

  HealthRecord({
    required this.id,
    required this.petId,
    required this.vetId,
    required this.apptId,
    this.diagnosis,
    this.treatment,
    this.notes,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id'] ?? 0,
      petId: json['petId'] ?? 0,
      vetId: json['vetId'] ?? 0,
      apptId: json['apptId'] ?? 0,
      diagnosis: json['diagnosis'],
      treatment: json['treatment'],
      notes: json['notes'],
    );
  }
}

class PetRecordPage extends StatefulWidget {
  final Pet pet;

  const PetRecordPage({Key? key, required this.pet}) : super(key: key);

  @override
  _PetRecordPageState createState() => _PetRecordPageState();
}

class _PetRecordPageState extends State<PetRecordPage> with TickerProviderStateMixin {
  List<HealthRecord> healthRecords = [];
  bool isLoading = true;
  late TabController _tabController;
  Pet? detailedPet;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Updated to 2 tabs
    _loadPetDetails();
    _loadHealthRecords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPetDetails() async {
    if (widget.pet.id == null) {
      setState(() {
        detailedPet = widget.pet;
        isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/pets/${widget.pet.id}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          detailedPet = Pet.fromJson(data);
        });
      } else {
        setState(() {
          detailedPet = widget.pet;
        });
      }
    } catch (e) {
      setState(() {
        detailedPet = widget.pet;
      });
    }
  }

  Future<void> _loadHealthRecords() async {
    if (widget.pet.id == null) {
      setState(() {
        healthRecords = [];
        isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/health-records/pet/${widget.pet.id}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          healthRecords = data.map<HealthRecord>((json) => HealthRecord.fromJson(json)).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load health records: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        healthRecords = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F8),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildPetInfoCard(),
                const SizedBox(height: 20),
                _buildTabSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      floating: false,
      pinned: true,
      backgroundColor: Color(0xFF3B82F6),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.edit, color: Colors.white),
          onPressed: () async {
            // Navigate to AddPetPage with the pet data for editing
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddPetPage(pet: detailedPet ?? widget.pet),
              ),
            );
            // Refresh pet details if the update was successful
            if (result == true) {
              await _loadPetDetails();
            }
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.pet.name,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF3B82F6),
                Color(0xFF60A5FA),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: Hero(
                    tag: 'pet_avatar_${widget.pet.name}',
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.network(
                          widget.pet.avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white,
                            child: Icon(
                              Icons.pets,
                              size: 60,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetInfoCard() {
    final pet = detailedPet ?? widget.pet;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
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
          Row(
            children: [
              Icon(Icons.pets, color: Color(0xFF3B82F6), size: 24),
              SizedBox(width: 8),
              Text(
                'Pet Information',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2A2D3E),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Species', pet.species, Icons.category),
              ),
              Expanded(
                child: _buildInfoItem('Breed', pet.breed, Icons.pets),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Age', '${pet.age} years', Icons.cake),
              ),
            ],
          ),
          if (pet.color != null) ...[
            SizedBox(height: 12),
            _buildInfoItem('Color', pet.color!, Icons.color_lens),
          ],
          if (pet.description != null) ...[
            SizedBox(height: 16),
            Text(
              'Description',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2A2D3E),
              ),
            ),
            SizedBox(height: 8),
            Text(
              pet.description!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[500]),
            SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2A2D3E),
          ),
        ),
      ],
    );
  }

  Widget _buildTabSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
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
          TabBar(
            controller: _tabController,
            indicatorColor: Color(0xFF3B82F6),
            labelColor: Color(0xFF3B82F6),
            unselectedLabelColor: Colors.grey[500],
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Health Records'),
            ],
          ),
          Container(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHealthRecordsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRecordsTab() {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
      );
    }

    if (healthRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No health records yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: healthRecords.length,
      itemBuilder: (context, index) {
        final record = healthRecords[index];
        return _buildHealthRecordCard(record);
      },
    );
  }

  Widget _buildHealthRecordCard(HealthRecord record) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Health Record #${record.id}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2A2D3E),
                  ),
                ),
              ),
            ],
          ),
          if (record.diagnosis != null) ...[
            SizedBox(height: 8),
            Text(
              'Diagnosis: ${record.diagnosis}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
          if (record.treatment != null) ...[
            SizedBox(height: 8),
            Text(
              'Treatment: ${record.treatment}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
          if (record.notes != null) ...[
            SizedBox(height: 8),
            Text(
              'Notes: ${record.notes}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.event, size: 14, color: Colors.grey[500]),
              SizedBox(width: 4),
              Text(
                'Appt ID: ${record.apptId}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              SizedBox(width: 16),
              Icon(Icons.person, size: 14, color: Colors.grey[500]),
              SizedBox(width: 4),
              Text(
                'Vet ID: ${record.vetId}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
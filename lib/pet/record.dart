import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pawfectcare_mobile/pet/record_details.dart';
import '../models/appointment.dart';
import '../models/health_record.dart';
import '../models/pet.dart';
import 'add_pet.dart'; // Import AddPetPage

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
        List<HealthRecord> tempRecords = data.map<HealthRecord>((json) => HealthRecord.fromJson(json)).toList();

        // Lấy thông tin Appointment và lưu trữ thời gian
        List<Map<String, dynamic>> recordsWithTime = [];
        for (var record in tempRecords) {
          final appointment = await fetchAppointment(record.apptId);
          recordsWithTime.add({
            'record': record,
            'apptTime': appointment?.apptTime ?? DateTime(1970), // Mặc định thời gian xa nếu không có Appointment
          });
        }

        // Ngày hiện tại (14/09/2025)
        final now = DateTime(2025, 9, 14);

        // Sắp xếp theo khoảng cách đến ngày hiện tại
        recordsWithTime.sort((a, b) {
          final timeA = a['apptTime'] as DateTime;
          final timeB = b['apptTime'] as DateTime;

          // Xác định xem bản ghi là quá khứ hay tương lai
          final isAPast = timeA.isBefore(now) || timeA.isAtSameMomentAs(now);
          final isBPast = timeB.isBefore(now) || timeB.isAtSameMomentAs(now);

          // Ưu tiên quá khứ trước, tương lai sau
          if (isAPast && !isBPast) return -1;
          if (!isAPast && isBPast) return 1;

          // Nếu cả hai đều trong quá khứ hoặc tương lai, sắp xếp theo khoảng cách tuyệt đối
          final diffA = (timeA.difference(now).inDays).abs();
          final diffB = (timeB.difference(now).inDays).abs();

          // Trong quá khứ: gần nhất trước (tăng dần)
          // Trong tương lai: gần nhất trước (tăng dần)
          return diffA.compareTo(diffB);
        });

        // Cập nhật danh sách healthRecords
        setState(() {
          healthRecords = recordsWithTime.map<HealthRecord>((item) => item['record'] as HealthRecord).toList();
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

  Future<Appointment?> fetchAppointment(int apptId) async {
    final url = Uri.parse("http://10.0.2.2:8080/api/appointments/$apptId");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return Appointment.fromJson(jsonDecode(response.body));
    } else {
      print("Failed to load appointment");
      return null;
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
                        child: CachedNetworkImage(
                          imageUrl: widget.pet.avatar,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                          ),
                          errorWidget: (context, url, error) => Container(
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
              Expanded(
                child: _buildInfoItem(
                  'Gender',
                  pet.gender ?? "Unknown",
                  pet.gender == "MALE"
                      ? Icons.male
                      : pet.gender == "FEMALE"
                      ? Icons.female
                      : Icons.help_outline,
                  color: pet.gender == "MALE"
                      ? Colors.blue
                      : pet.gender == "FEMALE"
                      ? Colors.pink
                      : Colors.grey,
                ),
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

  Widget _buildInfoItem(String label, String value, IconData icon, {Color? color}) {
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
            height: 740,
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
    final now = DateTime(2025, 9, 14, 11, 37); // Ngày hiện tại: 14/09/2025 11:37

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: Offset(2, 2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8FAFF),
            Color(0xFFEFF3F8),
          ],
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Có thể thêm hành động khi nhấn, ví dụ: mở chi tiết bản ghi
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ngày giờ và trạng thái
            FutureBuilder<Appointment?>(
              future: fetchAppointment(record.apptId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Row(
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Loading appointment...",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  );
                } else if (snapshot.hasError || !snapshot.hasData) {
                  return Row(
                    children: [
                      Icon(Icons.error_outline, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        "No appointment data",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                } else {
                  final appt = snapshot.data!;
                  String formatApptDate(DateTime? date) {
                    if (date == null) return "No appointment date";
                    return "${date.day.toString().padLeft(2, '0')}/"
                        "${date.month.toString().padLeft(2, '0')}/"
                        "${date.year}";
                  }


                  final isPast = appt.apptTime?.isBefore(now) ?? true;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            size: 20,
                            color: isPast ? Colors.blueGrey : Color(0xFF3B82F6),
                          ),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Examination Date",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                formatApptDate(appt.apptTime),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2A2D3E),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
            SizedBox(height: 16),
            // Thông tin chẩn đoán
            if (record.diagnosis != null) ...[
              Row(
                children: [
                  Icon(Icons.medical_services, size: 18, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Diagnosis: ${record.diagnosis}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
            ],
            // Thông tin điều trị
            if (record.treatment != null) ...[
              Row(
                children: [
                  Icon(Icons.healing, size: 18, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Treatment: ${record.treatment}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
            ],
            // Ghi chú
            if (record.notes != null) ...[
              Row(
                children: [
                  Icon(Icons.note, size: 18, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notes: ${record.notes}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
            ],
            // Nút chi tiết
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecordDetailsPage(recordId: record.id),
                    ),
                  );
                },
                child: Text(
                  "View Details",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
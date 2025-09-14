import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../appointments/appointment_detail.dart';
import '../booking/booking.dart' hide Pet;
import '../models/appointment.dart';
import '../pet/add_pet.dart';
import '../pet/record.dart';
import '../models/pet.dart';

class WeatherApiService {
  final String apiKey = "735593bd21224ee7b3e152653251209";

  Future<Map<String, dynamic>> fetchWeather(String city) async {
    final url = Uri.parse(
      "https://api.weatherapi.com/v1/current.json?key=$apiKey&q=$city&aqi=no",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load weather!");
    }
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback showBookingDialog; // Thêm callback để gọi từ NavigationPage
  final Function(int) onNavigate; // Thêm callback để điều hướng
  HomePage({required this.showBookingDialog, required this.onNavigate});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = "User";
  bool isLoading = true;
  String avatar = "avatar";
  int userId = 0;

  final List<Map<String, dynamic>> _emergencyServices = [
    {'name': '24/7 Emergency', 'phone': '1900-1234', 'available': true},
    {'name': 'Poison Control', 'phone': '1900-5678', 'available': true},
    {'name': 'Animal Rescue', 'phone': '1900-9999', 'available': true},
  ];
  List<Map<String, dynamic>> pets = [];
  List<Appointment> appointments = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPets();
    _loadAppointments();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? 'User';
      avatar = prefs.getString('avatar') ?? 'avatar';
      userId = prefs.getInt('userId') ?? 0;
      isLoading = false;
    });
  }

  Future<void> _loadPets() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt('userId') ?? 0;

    if (userId == 0) {
      // Nếu chưa login → hiển thị demo pets
      setState(() {
        pets = [
          {
            'id': null,
            'name': 'Milu',
            'breed': 'Golden Retriever',
            'species': 'Dog',
            'age': 3,
            'avatar': 'assets/images/dog1.jpg',
            'isDemo': true
          },
          {
            'id': null,
            'name': 'Kitty',
            'breed': 'Persian Cat',
            'species': 'Cat',
            'age': 2,
            'avatar': 'assets/images/cat1.jpg',
            'isDemo': true
          },
          {
            'id': null,
            'name': 'Buddy',
            'breed': 'Husky',
            'species': 'Dog',
            'age': 4,
            'avatar': 'assets/images/dog2.jpg',
            'isDemo': true
          },
        ];
        isLoading = false;
      });
    } else {
      try {
        final url = Uri.parse("http://10.0.2.2:8080/api/pets/user/$userId");
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          setState(() {
            pets = data.map((e) {
              return {
                'id': e['id'],
                'name': e['name'],
                'breed': e['breed'],
                'species': e['species'],
                'age': e['age'],
                'avatar': e['avatar'],
                'isDemo': false,
              };
            }).toList();
          });
        } else {
          // fallback nếu lỗi API
          setState(() {
            pets = [];
          });
        }
      } catch (e) {
        setState(() {
          pets = [];
        });
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Xin quyền PHONE
    var status = await Permission.phone.request();

    if (status.isGranted) {
      final Uri callUri = Uri(scheme: 'tel', path: phoneNumber);
      if (!await launchUrl(callUri, mode: LaunchMode.externalApplication)) {
        debugPrint("Could not launch $phoneNumber");
      }
    } else {
      debugPrint("Phone permission denied");
    }
  }

  Future<void> _loadAppointments() async {
    final prefs = await SharedPreferences.getInstance();
     userId = prefs.getInt('userId') ?? 0;

    if (userId == 0) {
      print('No ownerId found, setting appointments to empty');
      setState(() {
        appointments = [];
      });
      return;
    }

    try {
      final url = Uri.parse("http://10.0.2.2:8080/api/appointments/next/$userId");
      print('Fetching appointments from: $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        List<Appointment> loadedAppointments = data.map((e) => Appointment.fromJson(e)).toList();

        // Fetch additional discovery and pet details
        final discoveryIds = loadedAppointments.map((a) => a.discoveryId).toSet().toList();
        final petIds = loadedAppointments.map((a) => a.petId).toSet().toList();

        if (discoveryIds.isNotEmpty) {
          final discoveryRes = await http.get(
            Uri.parse("http://10.0.2.2:8080/api/discoveries/ids?ids=${discoveryIds.join("&ids=")}"),
          );

          if (discoveryRes.statusCode == 200) {
            final discoveryList = jsonDecode(discoveryRes.body);
            final discoveryMap = {
              for (var d in discoveryList) d['id']: {
                'name': d['name'],
                'location': d['location'],
              }
            };

            for (var appt in loadedAppointments) {
              appt.discoveryName = discoveryMap[appt.discoveryId]?['name'] ?? "";
              appt.location = discoveryMap[appt.discoveryId]?['location'] ?? "";
            }
          } else {
            print('Failed to fetch discoveries: ${discoveryRes.statusCode}');
          }
        }

        if (petIds.isNotEmpty) {
          final petRes = await http.get(
            Uri.parse("http://10.0.2.2:8080/api/pets/ids?ids=${petIds.join("&ids=")}"),
          );

          if (petRes.statusCode == 200) {
            final petList = jsonDecode(petRes.body);
            final petMap = {
              for (var p in petList)
                p['id']: {
                  'name': p['name'],
                  'species': p['species'],
                  'breed': p['breed'],
                  'age': p['age'],
                  'avatar': p['avatar'],
                }
            };

            for (var appt in loadedAppointments) {
              final petData = petMap[appt.petId];
              if (petData != null) {
                appt.petName = petData['name'] ?? "";
                appt.petSpecies = petData['species'] ?? "";
                appt.petBreed = petData['breed'] ?? "";
                appt.petAge = petData['age'] ?? 0;
                appt.petAvatar = petData['avatar'] ?? "";
              } else {
                appt.petName = "";
              }
            }
          } else {
            print('Failed to fetch pets: ${petRes.statusCode}');
          }
        }

        // Sort appointments by apptTime (ascending) and limit to 2
        loadedAppointments.sort((a, b) {
          final aTime = a.apptTime ?? DateTime(9999, 12, 31);
          final bTime = b.apptTime ?? DateTime(9999, 12, 31);
          return aTime.compareTo(bTime);
        });

        setState(() {
          appointments = loadedAppointments.take(2).toList();
        });
      } else {
        setState(() {
          appointments = [];
        });
      }
    } catch (e, stackTrace) {
      setState(() {
        appointments = [];
      });
    }
  }

  Future<void> _cancelAppointment(Appointment appointment) async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt('userId') ?? 0;
    try {
      final url = Uri.parse("http://10.0.2.2:8080/api/appointments/${appointment.id}");
      final body = {
        'id': appointment.id,
        'petId': appointment.petId,
        'ownerId': userId, // Lấy từ SharedPreferences hoặc dữ liệu hiện tại
        'discoveryId': appointment.discoveryId,
        'apptTime': appointment.apptTime?.toIso8601String(),
        'status': 'CANCELLED',
      };

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment cancelled successfully!', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _loadAppointments(); // Làm mới danh sách appointments
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel appointment: ${response.statusCode} - ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling appointment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red[600], size: 28),
            SizedBox(width: 12),
            Text('Emergency Services', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _emergencyServices
              .map((service) => _buildEmergencyServiceTile(service['name'], service['phone'], service['available']))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins(color: Color(0xFF3B82F6))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFEFF3F8),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F8),
      appBar: _buildAppBar(),
      body: _buildHomeContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundImage: avatar != 'avatar'
              ? NetworkImage(avatar)
              : const NetworkImage('https://i.pravatar.cc/150?img=3'),
          backgroundColor: Colors.grey[200],
          radius: 18,
        ),

      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello!',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            userName,
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: const Color(0xFF2A2D3E),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.emergency, color: Colors.red[600]),
          onPressed: _showEmergencyDialog,
        ),
        // Stack(
        //   children: [
        //     IconButton(
        //       icon: const Icon(Icons.notifications_outlined, color: Color(0xFF2A2D3E)),
        //       onPressed: () {},
        //     ),
        //     Positioned(
        //       right: 8,
        //       top: 8,
        //       child: Container(
        //         width: 8,
        //         height: 8,
        //         decoration: BoxDecoration(
        //           color: Colors.red,
        //           borderRadius: BorderRadius.circular(4),
        //         ),
        //       ),
        //     ),
        //   ],
        // ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          _buildWeatherPetCareCard(),
          const SizedBox(height: 24),
          _buildYourPetsSection(),
          const SizedBox(height: 32),
          _buildUpcomingAppointmentsSection(),
          const SizedBox(height: 32),
          _buildTipsSection(context),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildWeatherPetCareCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: WeatherApiService().fetchWeather("Hanoi"), // đổi "Hanoi" thành city bạn muốn
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Text(
              "Error: ${snapshot.error}",
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final data = snapshot.data!;
        final temp = data["current"]["temp_c"].toString(); // nhiệt độ °C
        final condition = data["current"]["condition"]["text"]; // mô tả thời tiết
        final iconUrl = "https:${data["current"]["condition"]["icon"]}"; // icon PNG

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF3B82F6).withOpacity(0.3),
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Weather",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "$temp°C - $condition",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Perfect weather for walks!",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Image.network(
                iconUrl,
                width: 50,
                height: 50,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.wb_sunny, color: Colors.white, size: 40),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildYourPetsSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Pets',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2A2D3E),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddPetPage()),
                );

                if (result == true) {
                  _loadPets(); // Reload lại pets
                }
              },
              icon: Icon(Icons.add, size: 18),
              label: Text('Add Pet'),
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF3B82F6),
              ),
            ),

          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...pets.map((pet) => _buildPetCard(pet)).toList(),
              _buildAddPetCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPetCard(Map<String, dynamic> pet) {
    final bool isDemo = pet['isDemo'] ?? false;
    final String avatar = pet['avatar'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PetRecordPage(
              pet: Pet(
                id: pet['id'],
                name: pet['name'],
                species: pet['species'],
                breed: pet['breed'],
                age: pet['age'] ?? 0,
                avatar: pet['avatar'],
              ),
            ),
          ),
        );
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: isDemo
                    ? AssetImage(avatar) as ImageProvider
                    : (avatar.isNotEmpty
                    ? NetworkImage(avatar)
                    : NetworkImage("https://cdn-icons-png.flaticon.com/512/616/616408.png")),
                backgroundColor: Colors.grey[200],
              ),
              const SizedBox(height: 6),
              Text(
                pet['name'] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2A2D3E),
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                pet['breed'] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                pet['species'] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildAddPetCard() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddPetPage()),
        );

        if (result == true) {
          _loadPets(); // Gọi lại API để reload pets
        }
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Color(0xFF3B82F6).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Color(0xFF3B82F6).withOpacity(0.3),
            style: BorderStyle.solid,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              color: Color(0xFF3B82F6),
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              'Add Pet',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAppointmentsSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Appointments',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2A2D3E),
              ),
            ),
            TextButton(
              onPressed: () {
                widget.onNavigate(2); // Chuyển sang tab Appointments (index 2)
              },
              child: Text(
                'View All',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF3B82F6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (appointments.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  offset: const Offset(0, 3),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Text(
              'No upcoming appointments',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...appointments.map((appt) => Padding(
            padding: const EdgeInsets.only(bottom: 12), // Add padding between cards
            child: _buildAppointmentCard(
              appt.discoveryName ?? 'Service',
              '${appt.petName ?? 'Pet'} - ${appt.petBreed ?? ''}',
              appt.apptTime != null
                  ? DateFormat('MMM dd, yyyy, hh:mm a').format(appt.apptTime!)
                  : '',
              appt.location ?? 'Ha Noi',
              const Color(0xFF3B82F6),
              status: appt.status ?? 'CANCELLED',
              appointment: appt, // Pass the Appointment object
            ),
          )).toList(),
      ],
    );
  }

  Widget _buildTipsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Care Tips',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2A2D3E),
          ),
        ),
        const SizedBox(height: 16),
        _buildTipCard(
          context,
          'Winter Fur Care for Dogs & Cats',
          'Winter dry weather can make pet fur dry and brittle. Learn essential care tips...',
          'assets/images/tip1.jpg',
        ),
      ],
    );
  }

  Widget _buildEmergencyServiceTile(String name, String phone, bool available) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: available ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            available ? Icons.phone : Icons.phone_disabled,
            color: available ? Colors.green : Colors.grey,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                Text(
                  phone,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (available)
    ElevatedButton(
      onPressed: () => _makePhoneCall(phone),
      child: Text('Call', style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        minimumSize: Size(60, 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(
      String service,
      String pet,
      String datetime,
      String provider,
      Color color, {
        required String status,
        required Appointment appointment,
      }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentDetailPage(appointment: appointment),
          ),
        ).then((result) {
          if (result == true) {
            _loadAppointments(); // reload sau khi quay lại
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
        child: Row(
          children: [
            Container(
              width: 4,
              height: 70,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          service,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2A2D3E),
                          ),
                        ),
                      ),
                      Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'Confirmed'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: status == 'Confirmed'
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pet,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        datetime,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          provider,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () {
                    _showAppointmentOptions(context, appointment);
                  },
                  color: Colors.grey[600],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  void _showAppointmentOptions(BuildContext context, Appointment appointment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: Text('Cancel Appointment', style: GoogleFonts.poppins(fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                // Hiển thị dialog xác nhận
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(
                      'Confirm Cancellation',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    content: Text(
                      'Are you sure you want to cancel this appointment?',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context), // Đóng dialog
                        child: Text(
                          'No',
                          style: GoogleFonts.poppins(color: Color(0xFF3B82F6)),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context); // Đóng dialog
                          await _cancelAppointment(appointment); // Thực hiện hủy
                        },
                        child: Text(
                          'Yes',
                          style: GoogleFonts.poppins(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.grey),
              title: Text('View Details', style: GoogleFonts.poppins(fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppointmentDetailPage(appointment: appointment),
                  ),
                ).then((result) {
                  if (result == true) {
                    // Load lại danh sách appointments ở đây
                    _loadAppointments(); // Hoặc hàm refresh tương ứng của bạn
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(BuildContext context, String title, String description, String imagePath) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.asset(
              imagePath,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2A2D3E),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFF4ECDC4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'New',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Color(0xFF4ECDC4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      // onTap: () async {
                      //   final url = Uri.parse('http://localhost:4200/blog');
                      //   try {
                      //     if (await canLaunchUrl(url)) {
                      //       await launchUrl(
                      //         url,
                      //         mode: LaunchMode.externalApplication, // Mở trong trình duyệt mặc định
                      //       );
                      //     } else {
                      //       ScaffoldMessenger.of(context).showSnackBar(
                      //         SnackBar(content: Text('Không thể mở $url')),
                      //       );
                      //     }
                      //   } catch (e) {
                      //     ScaffoldMessenger.of(context).showSnackBar(
                      //       SnackBar(content: Text('Lỗi khi mở URL: $e')),
                      //     );
                      //   }
                      // },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          'Read More →',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF3B82F6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.bookmark_border, size: 18, color: Colors.grey[400]),
                        SizedBox(width: 8),
                        Icon(Icons.share, size: 18, color: Colors.grey[400]),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
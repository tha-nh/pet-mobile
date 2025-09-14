import 'package:flutter/material.dart';
import 'package:pawfectcare_mobile/home/home.dart';
import 'package:pawfectcare_mobile/pet/pet.dart';
import 'package:pawfectcare_mobile/user/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'appointments/appointmentList.dart';
import 'booking/booking.dart';

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key});

  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String? userId;
  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final int? id = prefs.getInt('userId');
      userId = id?.toString();
    });
  }

  void _onItemTapped(int index) {
    if (index == 2) { // Index của mục "Book"
      _showBookingDialog(context); // Gọi BookingPage khi nhấn "Book"
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

// ví dụ trong onTap của button
  void _showBookingDialog(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => const BookingPage(),
      ),
    );

    if (result != null) {
      print("Appointment details: $result");
      // Handle the result, e.g., update UI with setState
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      HomePage(
        showBookingDialog: () => _showBookingDialog(context),
        onNavigate: _onItemTapped, // Truyền hàm _onItemTapped
      ),
      const PetPage(),// Services
      Container(),
      const AppointmentListPage(), // ✅ thay vào đây
      userId != null
          ? ProfilePage(userId: userId!)
          : Container(
        color: const Color(0xFFEFF3F8),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person,
                size: 80,
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 16),
              Text(
                'Profile Section',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2A2D3E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please log in to view profile',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ];


    return Scaffold(
      body: _pages[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        heroTag: "nav_fab",
        onPressed: () => _showBookingDialog(context), // sửa ở đây luôn
        backgroundColor: const Color(0xFF3B82F6),
        child: const Icon(Icons.event_available, color: Colors.white),
        elevation: 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF3B82F6),
        unselectedItemColor: Colors.grey[400],
        elevation: 8,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w400),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Pet'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Book'), // Thêm mục Book
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Appointments'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

}
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pawfectcare_mobile/user/profile_update.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';

class ProfilePage extends StatefulWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String errorMessage = '';
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    fetchUserData();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> fetchUserData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/user-pets/${widget.userId}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          userData = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load user data: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching user data: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _showLogoutConfirm() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Confirm Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Color(0xFF3B82F6))),
          ),
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Sign Out', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Signed out successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 80.0, left: 16.0, right: 16.0),
      ),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<String?> _uploadToImgBB(String imagePath) async {
    const String imgbbApiKey = 'fa4176aa6360d22d4809f8799fbdf498'; // Thay bằng key thực từ https://api.imgbb.com/

    try {
      final file = File(imagePath);
      // Kiểm tra size và định dạng
      if (file.lengthSync() > 5 * 1024 * 1024) {
        return null;
      }
      if (!['.jpg', '.jpeg', '.png'].contains(file.path.toLowerCase().substring(file.path.lastIndexOf('.')))) {
        return null;
      }

      final uploadReq = http.MultipartRequest(
        "POST",
        Uri.parse("https://api.imgbb.com/1/upload?key=$imgbbApiKey"),
      );
      uploadReq.files.add(await http.MultipartFile.fromPath("image", file.path));
      final resp = await uploadReq.send();
      if (resp.statusCode == 200) {
        final body = await resp.stream.bytesToString();
        final data = jsonDecode(body);
        final url = data['data']['url'] as String?;
        if (url == null || url.isEmpty) {
          throw Exception("Invalid URL from ImgBB");
        }
        return url;
      } else {
        print('ImgBB upload error: ${resp.statusCode} - ${await resp.stream.bytesToString()}');
        return null;
      }
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  Future<void> _updateAvatar() async {
    final picker = ImagePicker();
    // Show dialog chọn source
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Select Image Source', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Choose to take a photo or select from gallery.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: Text('Camera', style: GoogleFonts.poppins(color: Color(0xFF3B82F6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: Text('Gallery', style: GoogleFonts.poppins(color: Color(0xFF3B82F6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (source == null) return;

    // Request permission
    if (source == ImageSource.gallery) {
      var status = await Permission.photos.request();
      if (!status.isGranted) {
        return;
      }
    } else if (source == ImageSource.camera) {
      var status = await Permission.camera.request();
      if (!status.isGranted) {
        return;
      }
    }

    try {
      final pickedFile = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800);
      if (pickedFile == null) return;

      // Hiển thị loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
        ),
      );

      // Upload ảnh lên ImgBB
      final imageUrl = await _uploadToImgBB(pickedFile.path);
      if (imageUrl == null) {
        Navigator.pop(context); // Đóng loading
        return;
      }

      // Gọi API update avatar
      final userIdInt = int.tryParse(widget.userId);
      if (userIdInt == null) {
        Navigator.pop(context);
        return;
      }

      final apiUrl = Uri.parse('http://10.0.2.2:8080/api/user-pets/$userIdInt/avatar');
      final response = await http.patch(
        apiUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'avatar': imageUrl}),
      );


      Navigator.pop(context); // Đóng loading

      if (response.statusCode == 200) {
        fetchUserData(); // Refresh profile
      } else {
      }
    } catch (e) {
      Navigator.pop(context); // Đóng loading nếu còn
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F8),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Text(
              "Profile",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: _showLogoutConfirm,
              ),
            ],
            iconTheme: const IconThemeData(color: Colors.white),
          ),
        ),
      ),

      body: isLoading
          ? _buildLoadingState()
          : errorMessage.isNotEmpty
          ? _buildErrorState()
          : RefreshIndicator(
        onRefresh: fetchUserData,
        color: const Color(0xFF3B82F6),
        child: CustomScrollView(
          slivers: [
            _buildHeader(),
            SliverToBoxAdapter(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6).withOpacity(0.2), Color(0xFFEFF3F8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
    child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Trong _buildHeader, thay thế CircleAvatar bằng:
                GestureDetector(
                  onTap: _updateAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(
                          (userData?["avatar"] as String?)?.isNotEmpty == true
                              ? userData!["avatar"]
                              : "https://i.pravatar.cc/150?img=5",
                        ),
                        backgroundColor: Colors.grey[200],
                      ),
                      // Icon edit nhỏ ở góc phải dưới
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.edit, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  userData?['name'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2A2D3E),
                  ),
                ),
                Text(
                  'OWNER',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your profile...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2A2D3E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: fetchUserData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Try Again',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            child: _buildPersonalInfo(),
            offset: 0,
          ),
          const SizedBox(height: 16),
          _buildCard(
            child: _buildStats(),
            offset: 8,
          ),
          const SizedBox(height: 16),

        ],
      ),
    );
  }

  Widget _buildCard({required Widget child, required double offset}) {
    return Transform.translate(
      offset: Offset(0, offset),
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  offset: const Offset(5, 5),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  offset: const Offset(-5, -5),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Để nút ở bên phải
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person, color: Color(0xFF3B82F6), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Personal Information',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2A2D3E),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.edit, color: Color(0xFF3B82F6), size: 24),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileUpdatePage(
                        userId: widget.userId,
                        userData: userData ?? {},
                      ),
                    ),
                  ).then((value) {
                    if (value == true) {
                      fetchUserData(); // Refresh dữ liệu sau khi cập nhật
                    }
                  });
                },
                tooltip: 'Edit Profile',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.email_rounded, 'Email', userData?['email'] ?? ''),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.phone_rounded, 'Phone', userData?['phone'] ?? ''),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_on_rounded, 'Address', userData?['address'] ?? ''),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Color(0xFF3B82F6), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2A2D3E),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.analytics_rounded, color: Color(0xFF3B82F6), size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Activity Stats',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2A2D3E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatIndicator('Pets', 5, 10, Icons.pets_rounded),
              _buildStatIndicator('Record', 42, 100, Icons.assignment),
              _buildStatIndicator('Days', 127, 365, Icons.calendar_today_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatIndicator(String label, int value, int max, IconData icon) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: value / max,
                backgroundColor: Color(0xFF3B82F6).withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                strokeWidth: 6,
              ),
            ),
            Icon(icon, color: Color(0xFF3B82F6), size: 24),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$value',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2A2D3E),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }


}
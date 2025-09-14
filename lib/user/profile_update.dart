import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

class ProfileUpdatePage extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const ProfileUpdatePage({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  _ProfileUpdatePageState createState() => _ProfileUpdatePageState();
}

class _ProfileUpdatePageState extends State<ProfileUpdatePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  bool isLoading = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name'] ?? '');
    _emailController = TextEditingController(text: widget.userData['email'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
    _addressController = TextEditingController(text: widget.userData['address'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Parse userId thành int (giả sử API dùng Long, Flutter dùng int)
      final userIdInt = int.tryParse(widget.userId);
      if (userIdInt == null || userIdInt == 0) {
        throw Exception('Invalid user ID: ${widget.userId} (must be a valid number)');
      }

      final url = Uri.parse('http://10.0.2.2:8080/api/user-pets/$userIdInt');
      // Merge tất cả field từ userData, chỉ overwrite các field từ form
      final body = {
        'id': userIdInt,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'avatar': widget.userData['avatar'] ?? '',
        'passwordHash': widget.userData['passwordHash'] ?? '', // Giữ nguyên từ GET
        'role': widget.userData['role'] ?? 'USER', // Giữ nguyên, mặc định 'USER' nếu null
        'createdAt': widget.userData['createdAt'] != null
            ? widget.userData['createdAt'] // Đã là ISO 8601 string từ GET
            : DateTime.now().toUtc().toIso8601String(), // Fallback nếu null
      };

      final jsonBody = jsonEncode(body);
      print('DEBUG: URL: $url');
      print('DEBUG: Request Body: $jsonBody');

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonBody,
      );

      print('DEBUG: Response Status: ${response.statusCode}');
      print('DEBUG: Response Body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true); // Trả về true để refresh profile
      } else {
        final responseBody = response.body;
        setState(() {
          errorMessage = 'Failed to update: ${response.statusCode} - $responseBody';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error updating profile: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Update Profile',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2A2D3E),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2A2D3E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField('Name', _nameController, Icons.person),
                const SizedBox(height: 16),
                _buildTextField('Email', _emailController, Icons.email_rounded, TextInputType.emailAddress),
                const SizedBox(height: 16),
                _buildTextField('Phone', _phoneController, Icons.phone_rounded, TextInputType.phone),
                const SizedBox(height: 16),
                _buildTextField('Address', _addressController, Icons.location_on_rounded, TextInputType.streetAddress),
                if (errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _buildUpdateButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, [TextInputType? keyboardType]) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: Color(0xFF3B82F6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '$label is required';
        }
        if (label == 'Email' && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _updateProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Text(
          'Update Profile',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
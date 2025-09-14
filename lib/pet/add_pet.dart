import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../models/pet.dart';

class AddPetPage extends StatefulWidget {
  final Pet? pet; // Optional pet for editing

  const AddPetPage({Key? key, this.pet}) : super(key: key);

  @override
  _AddPetPageState createState() => _AddPetPageState();
}

class _AddPetPageState extends State<AddPetPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _speciesController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  File? _avatarFile;
  String? _avatarUrl; // Lưu URL ảnh sau khi upload
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const String _imgbbApiKey = 'fa4176aa6360d22d4809f8799fbdf498'; // Thay bằng key từ https://api.imgbb.com/

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    // Prefill form if editing
    if (widget.pet != null) {
      _nameController.text = widget.pet!.name;
      _speciesController.text = widget.pet!.species;
      _breedController.text = widget.pet!.breed;
      _ageController.text = widget.pet!.age.toString();
      _avatarUrl = widget.pet!.avatar;
    }
    _fadeController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Select Image Source", style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: Text("Take Photo", style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: Text("Choose from Gallery", style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (source == null) return;

    // Request permission
    if (source == ImageSource.gallery) {
      var status = await Permission.photos.request();
      if (!status.isGranted) {
        _showSnackBar("Permission denied for gallery", isError: true);
        return;
      }
    } else if (source == ImageSource.camera) {
      var status = await Permission.camera.request();
      if (!status.isGranted) {
        _showSnackBar("Permission denied for camera", isError: true);
        return;
      }
    }

    final picked = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800);
    if (picked != null) {
      final file = File(picked.path);
      // Kiểm tra size và định dạng
      if (file.lengthSync() > 5 * 1024 * 1024) {
        _showSnackBar("Image size exceeds 5MB", isError: true);
        return;
      }
      if (!['.jpg', '.jpeg', '.png'].contains(file.path.toLowerCase().substring(file.path.lastIndexOf('.')))) {
        _showSnackBar("Only JPG/PNG images are supported", isError: true);
        return;
      }

      setState(() {
        _avatarFile = file;
        _isUploadingImage = true;
      });

      // Upload ngay khi chọn ảnh
      if (_imgbbApiKey == 'fa4176aa6360d22d4809f8799fbdf498') {
        _showSnackBar("Please set your ImgBB API key", isError: true);
        setState(() => _isUploadingImage = false);
        return;
      }

      try {
        final uploadReq = http.MultipartRequest(
          "POST",
          Uri.parse("https://api.imgbb.com/1/upload?key=$_imgbbApiKey"),
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
          setState(() => _avatarUrl = url); // Lưu URL
        } else {
          throw Exception("Upload failed: ${resp.statusCode}");
        }
      } catch (e) {
        _showSnackBar("Failed to upload image!", isError: true);
        setState(() => _avatarUrl = null); // Reset URL nếu lỗi
      } finally {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final prefs = await SharedPreferences.getInstance();
    final ownerId = prefs.getInt('userId') ?? 0;

    // Chuẩn hóa body để gửi API
    final body = {
      "ownerId": ownerId,
      "name": _nameController.text.trim(),
      "species": _speciesController.text.trim(),
      "breed": _breedController.text.trim(),
      "age": int.tryParse(_ageController.text.trim()) ?? 0,
      "avatar": _avatarUrl ?? "https://placehold.co/50x50",
    };

    try {
      http.Response response;
      if (widget.pet != null && widget.pet!.id != null) {
        // Update existing pet
        response = await http.put(
          Uri.parse("http://10.0.2.2:8080/api/pets/${widget.pet!.id}"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      } else {
        // Add new pet
        response = await http.post(
          Uri.parse("http://10.0.2.2:8080/api/pets"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar(widget.pet != null ? "Pet updated successfully!" : "Pet added successfully!");
        Navigator.pop(context, true);
      } else {
        // In lỗi chi tiết từ backend
        final errorMsg = jsonDecode(response.body)['message'] ?? 'Unknown error';
        _showSnackBar("Failed to ${widget.pet != null ? 'update' : 'add'} pet: $errorMsg", isError: true);
      }
    } catch (e) {
      _showSnackBar("Failed to ${widget.pet != null ? 'update' : 'add'} pet!", isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.poppins())),
          ],
        ),
        backgroundColor: isError ? Color(0xFFE74C3C) : Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
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
            colors: [Color(0xFFF8FAFC), Color(0xFFEEF2F7)],
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
                    colors: [Color(0xFF3B82F6).withOpacity(0.1), Colors.transparent],
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
                    colors: [Color(0xFF8B5CF6).withOpacity(0.1), Colors.transparent],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildForm(),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _buildSubmitButton(),
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
                  widget.pet != null ? 'Edit Pet' : 'Add New Pet',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A202C),
                  ),
                ),
                Text(
                  widget.pet != null ? 'Update your pet’s details' : 'Register your pet for appointments',
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

  Widget _buildForm() {
    return Container(
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(_nameController, "Name", validator: (val) => val == null || val.isEmpty ? "Required" : null),
            SizedBox(height: 16),
            _buildTextField(_speciesController, "Species", validator: (val) => val == null || val.isEmpty ? "Required" : null),
            SizedBox(height: 16),
            _buildTextField(_breedController, "Breed", validator: (val) => val == null || val.isEmpty ? "Required" : null),
            SizedBox(height: 16),
            _buildTextField(
              _ageController,
              "Age",
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.isEmpty) return "Required";
                final age = int.tryParse(val);
                if (age == null) return "Must be a number";
                if (age <= 0) return "Age must be positive";
                return null;
              },
            ),
            SizedBox(height: 24),
            _buildImagePicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Color(0xFF718096)),
        filled: true,
        fillColor: Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
      ),
      style: GoogleFonts.poppins(fontSize: 16, color: Color(0xFF1A202C)),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _isUploadingImage ? null : _pickImage,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFE2E8F0)),
        ),
        child: _isUploadingImage
            ? Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
          ),
        )
            : _avatarFile != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(_avatarFile!, height: 120, width: double.infinity, fit: BoxFit.cover),
        )
            : _avatarUrl != null && _avatarUrl!.isNotEmpty
            ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(_avatarUrl!, height: 120, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 40, color: Color(0xFF718096)),
                  SizedBox(height: 8),
                  Text(
                    "Tap to select image",
                    style: GoogleFonts.poppins(fontSize: 14, color: Color(0xFF718096)),
                  ),
                ],
              ),
            );
          }),
        )
            : Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, size: 40, color: Color(0xFF718096)),
              SizedBox(height: 8),
              Text(
                "Tap to select image",
                style: GoogleFonts.poppins(fontSize: 14, color: Color(0xFF718096)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting || _isUploadingImage ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF10B981),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        shadowColor: Color(0xFF10B981).withOpacity(0.4),
      ),
      child: _isSubmitting
          ? SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
      )
          : Text(
        widget.pet != null ? "Update Pet" : "Save Pet",
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
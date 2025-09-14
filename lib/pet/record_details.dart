import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/appointment.dart';
import '../models/health_record.dart';

class RecordDetailsPage extends StatefulWidget {
  final int recordId;

  const RecordDetailsPage({Key? key, required this.recordId}) : super(key: key);

  @override
  _RecordDetailsPageState createState() => _RecordDetailsPageState();
}

class _RecordDetailsPageState extends State<RecordDetailsPage>
    with TickerProviderStateMixin {
  HealthRecord? healthRecord;
  Appointment? appointment;
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _loadRecordDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadRecordDetails() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/health-records/${widget.recordId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final record = HealthRecord.fromJson(data);

        final apptResponse = await http.get(
          Uri.parse('http://10.0.2.2:8080/api/appointments/${record.apptId}'),
          headers: {'Content-Type': 'application/json'},
        );

        Appointment? appt;
        if (apptResponse.statusCode == 200) {
          appt = Appointment.fromJson(json.decode(apptResponse.body));
        }

        setState(() {
          healthRecord = record;
          appointment = appt;
          isLoading = false;
        });
        _animationController.forward();
      } else {
        throw Exception('Failed to load health record: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  String formatApptDate(DateTime? date) {
    if (date == null) return "No appointment date";
    return DateFormat('dd MMM yyyy').format(date);
  }

  void _shareRecord() {
    if (healthRecord == null) return;

    // Tạo nội dung chia sẻ
    String shareContent =
        '''


Health Record Details
Examination Date: ${appointment != null ? formatApptDate(appointment!.apptTime) : "No appointment scheduled"}
Diagnosis: ${healthRecord!.diagnosis ?? "Not specified"}
Treatment: ${healthRecord!.treatment ?? "Not specified"}
Additional Notes: ${healthRecord!.notes ?? "None"}
''';
    // Chia sẻ nội dung
    Share.share(shareContent, subject: 'Health Record Details');
  }

  Future<void> _exportRecordAsPDF() async {
    if (healthRecord == null) return;

    // Tạo tài liệu PDF
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Health Record Details',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Examination Date: ${appointment != null ? formatApptDate(appointment!.apptTime) : "No appointment scheduled"}',
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Diagnosis: ${healthRecord!.diagnosis ?? "Not specified"}',
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Treatment: ${healthRecord!.treatment ?? "Not specified"}',
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Additional Notes: ${healthRecord!.notes ?? "None"}',
              style: const pw.TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );

    // Lưu tệp PDF vào thư mục tạm
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/health_record_${widget.recordId}.pdf');
    await file.writeAsBytes(await pdf.save());

    // Mở tệp PDF hoặc thông báo người dùng
    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening PDF: ${result.message}')),
      );
    }

    // Tùy chọn: Chia sẻ tệp PDF
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Health Record PDF',
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color iconColor,
    Color? backgroundColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 15,
            spreadRadius: 0,
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            const Spacer(),
            Text(
              "Health Record",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Unable to Load Record",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Please check your connection and try again",
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              _loadRecordDetails();
            },
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const CircularProgressIndicator(
              color: Color(0xFF3B82F6),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Loading record details...",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: isLoading
                ? _buildLoadingState()
                : healthRecord == null
                ? _buildErrorState()
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Appointment Information
                            _buildInfoCard(
                              icon: Icons.calendar_today_rounded,
                              title: "Examination  Date",
                              content: appointment != null
                                  ? formatApptDate(appointment!.apptTime)
                                  : "No appointment scheduled",
                              iconColor: const Color(0xFF3B82F6),
                              backgroundColor: const Color(
                                0xFF3B82F6,
                              ).withOpacity(0.02),
                            ),

                            // Diagnosis
                            if (healthRecord!.diagnosis != null)
                              _buildInfoCard(
                                icon: Icons.medical_services_rounded,
                                title: "Diagnosis",
                                content: healthRecord!.diagnosis!,
                                iconColor: const Color(0xFFEF4444),
                              ),

                            // Treatment
                            if (healthRecord!.treatment != null)
                              _buildInfoCard(
                                icon: Icons.healing_rounded,
                                title: "Treatment Plan",
                                content: healthRecord!.treatment!,
                                iconColor: const Color(0xFF10B981),
                              ),

                            // Notes
                            if (healthRecord!.notes != null)
                              _buildInfoCard(
                                icon: Icons.sticky_note_2_rounded,
                                title: "Additional Notes",
                                content: healthRecord!.notes!,
                                iconColor: const Color(0xFF8B5CF6),
                              ),

                            const SizedBox(height: 20),

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      _shareRecord();
                                    },
                                    icon: const Icon(Icons.share_rounded),
                                    label: const Text("Share"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF3B82F6),
                                      side: const BorderSide(
                                        color: Color(0xFF3B82F6),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _exportRecordAsPDF();
                                    },
                                    icon: const Icon(Icons.download_rounded),
                                    label: const Text("Export"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 40),
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
}

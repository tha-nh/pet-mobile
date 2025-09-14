import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/appointment.dart';
import '../booking/booking.dart';
import 'appointmentList.dart';

class AppointmentDetailPage extends StatefulWidget {
  final Appointment appointment;

  AppointmentDetailPage({super.key, required this.appointment});

  @override
  _AppointmentDetailPageState createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends State<AppointmentDetailPage> {
  late Appointment appointment;
  final DateFormat dateFormatter = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    appointment = widget.appointment;
  }

  Future<void> _fetchAppointmentDetails() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final ownerId = prefs.getInt('userId') ?? 0;
      if (ownerId == 0) {
        if (mounted) {
          await _showAnimatedMessage(
            context,
            'Error: User ID not found',
            Colors.red,
            Icons.error,
          );
        }
        return;
      }

      final url = Uri.parse("http://10.0.2.2:8080/api/appointments/${appointment.id}");
      print('Fetching appointment details for ID: ${appointment.id}');

      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
      );

      print('GET Response Status: ${response.statusCode}');
      print('GET Response Body: ${response.body}');

      if (response.statusCode == 200 && mounted) {
        final responseData = jsonDecode(response.body);
        print('Parsed JSON: $responseData');

        final updatedAppointment = Appointment.fromJson(responseData);
        print('Updated status after fetch: ${updatedAppointment.status}');
        if (updatedAppointment.id == null) {
          print('Lỗi: ID null sau fetch! Response body: ${response.body}');
          await _showAnimatedMessage(context, 'Lỗi tải dữ liệu: ID không hợp lệ!', Colors.red, Icons.error);
          return;
        }
        if (mounted) {
          setState(() {
            appointment = updatedAppointment;
          });
          print('setState called after fetch - status now: ${appointment.status}');

          // FORCE REBUILD TOÀN BỘ WIDGET
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {}); // Trigger thêm một lần rebuild
            }
          });
        }
      } else if (mounted) {
        print('Failed to fetch: ${response.statusCode} - ${response.body}');
        await _showAnimatedMessage(
          context,
          'Failed to load updated appointment details!',
          Colors.red,
          Icons.error,
        );
      }
    } catch (e) {
      print('Error in _fetchAppointmentDetails: $e');
      if (mounted) {
        await _showAnimatedMessage(
          context,
          'Error loading appointment details!',
          Colors.red,
          Icons.error,
        );
      }
    }
  }

  Future<void> _cancelAppointment(BuildContext context) async {
    Future<void> showCenteredMessage(String message, Color bgColor) async {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          backgroundColor: bgColor,
          content: Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
      await Future.delayed(Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final ownerId = prefs.getInt('userId') ?? 0;
      if (ownerId == 0) {
        if (mounted) await showCenteredMessage('Error: User ID not found', Colors.red);
        return;
      }

      final url = Uri.parse("http://10.0.2.2:8080/api/appointments/${appointment.id}");
      if (appointment.id == null) {
        await _showAnimatedMessage(context, 'Lỗi: Không tìm thấy ID appointment!', Colors.red, Icons.error);
        return;
      }
      final body = {
        'id': appointment.id,  // Thêm lại 'id' với giá trị thực (ví dụ: 2) để backend parse != null
        'petId': appointment.petId,
        'ownerId': ownerId,
        'discoveryId': appointment.discoveryId,
        'apptTime': appointment.apptTime?.toIso8601String(),
        'status': 'CANCELLED',
        // Không cần 'createdAt' vì backend tự handle (null OK)
      };

      print('Cancel PUT body: ${jsonEncode(body)}');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );

      print('PUT Response Status: ${response.statusCode}');
      print('PUT Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // CẬP NHẬT STATE TRƯỚC KHI SHOW MESSAGE
        if (mounted) {
          setState(() {
            try {
              appointment.status = 'CANCELLED';
            } catch (e) {
              print('Status is immutable, creating new Appointment: $e');
              appointment = Appointment(
                id: appointment.id,
                petId: appointment.petId,
                discoveryId: appointment.discoveryId,
                apptTime: appointment.apptTime,
                status: 'CANCELLED',
                discoveryName: appointment.discoveryName,
                location: appointment.location,
                petName: appointment.petName,
                petSpecies: appointment.petSpecies,
                petBreed: appointment.petBreed,
                petAge: appointment.petAge,
                petAvatar: appointment.petAvatar,
              );
            }
          });
          print('Local status updated to: CANCELLED - UI should rebuild now');
        }

        // SAU ĐÓ MỚI SHOW MESSAGE
        if (mounted) {
          await _showAnimatedMessage(
            context,
            'Appointment cancelled successfully!',
            Colors.green,
            Icons.check_circle,
          );
        }

        // FETCH LẠI ĐỂ ĐỒNG BỘ VỚI BACKEND
        await Future.delayed(const Duration(milliseconds: 300));
        await _fetchAppointmentDetails();

      } else if (mounted) {
        await _showAnimatedMessage(
          context,
          'Failed to cancel appointment!',
          Colors.red,
          Icons.error,
        );
      }
    } catch (e) {
      print('Error in _cancelAppointment: $e');
      if (mounted) {
        await _showAnimatedMessage(
          context,
          'Error cancelling appointment!',
          Colors.red,
          Icons.error,
        );
      }
    }
  }

  Future<void> _showAnimatedMessage(
      BuildContext context, String message, Color bgColor, IconData iconData) async {
    if (!mounted) return; // Kiểm tra mounted TRƯỚC khi show dialog
    showGeneralDialog(
      context: context,
      barrierLabel: "Message",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconData, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );

    await Future.delayed(Duration(seconds: 2));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    print('=== BUILD METHOD CALLED - Current status: ${appointment.status} ===');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Appointment Details',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E1E2D),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1E2D)),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SỬ DỤNG KEY DỰA TRÊN TIMESTAMP ĐỂ FORCE REBUILD
              _buildDetailCard(
                key: ValueKey('${appointment.id}-${appointment.status}-${DateTime.now().millisecondsSinceEpoch}'),
                service: appointment.discoveryName ?? 'Service',
                pet: appointment.petName ?? 'Pet',
                datetime: appointment.apptTime != null
                    ? dateFormatter.format(appointment.apptTime!)
                    : '',
                location: appointment.location ?? 'Ha Noi',
                status: appointment.status ?? 'CANCELLED',
                petSpecies: appointment.petSpecies,
                petBreed: appointment.petBreed,
                petAge: appointment.petAge,
                petAvatar: appointment.petAvatar,
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 24),

              // SỬ DỤNG KEY TƯƠNG TỰ CHO ACTION BUTTONS
              _buildActionButtons(context, key: ValueKey('buttons-${appointment.status}')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required Key key,
    required String service,
    required String pet,
    required String datetime,
    required String location,
    required String status,
    String? petSpecies,
    String? petBreed,
    int? petAge,
    String? petAvatar,
  }) {
    print('Building DetailCard with status: $status'); // Log để kiểm tra rebuild
    return Container(
      key: key,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service + Status (sẽ thay đổi màu/text khi status = CANCELLED)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Service',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: status == 'CONFIRMED'
                      ? Colors.blue.withOpacity(0.15)
                      : status == 'PENDING'
                      ? Colors.orange.withOpacity(0.15)
                      : status == 'CANCELLED'
                      ? Colors.red.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: status == 'CONFIRMED'
                        ? Colors.blue[700]
                        : status == 'PENDING'
                        ? Colors.orange[700]
                        : status == 'CANCELLED'
                        ? Colors.red[700]
                        : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            service,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E1E2D),
            ),
          ),
          const SizedBox(height: 24),
          // Pet info (giữ nguyên)
          Text(
            'Pet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: petAvatar != null && petAvatar.isNotEmpty
                    ? NetworkImage(petAvatar)
                    : const NetworkImage("https://cdn-icons-png.flaticon.com/512/616/616408.png"),
                backgroundColor: Colors.grey[200],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2A2D3E),
                      ),
                    ),
                    if (petSpecies != null && petSpecies.isNotEmpty)
                      Text(
                        "Species: $petSpecies",
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                      ),
                    if (petBreed != null && petBreed.isNotEmpty)
                      Text(
                        "Breed: $petBreed",
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                      ),
                    if (petAge != null)
                      Text(
                        "Age: $petAge years",
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Date & Time (giữ nguyên)
          Text(
            'Date & Time',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time, size: 20, color: Colors.grey[500]),
              const SizedBox(width: 12),
              Text(
                datetime,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: const Color(0xFF1E1E2D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Location (giữ nguyên)
          Text(
            'Location',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, size: 20, color: Colors.grey[500]),
              const SizedBox(width: 12),
              Text(
                location,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: const Color(0xFF1E1E2D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, {Key? key}) {
    print('Building ActionButtons - Status: ${appointment.status} - Cancel button visible: ${appointment.status == "PENDING"}');

    return Container(
      key: key,
      child: Row(
        children: [

          // KIỂM TRA STATUS VÀ CHỈ HIỂN THỊ CANCEL BUTTON KHI STATUS = PENDING
          if (appointment.status?.toUpperCase() == 'PENDING') ...[
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
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
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'No',
                            style: GoogleFonts.poppins(color: Color(0xFF3B82F6)),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _cancelAppointment(context);
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
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFFEF4444), width: 2),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
            ),
          ],
        ],
      ),
    );
  }
}
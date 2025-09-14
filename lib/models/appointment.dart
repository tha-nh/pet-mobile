class Appointment {
  int id;
  int discoveryId;
  int petId;
  DateTime? apptTime;
  String? status;
  String? discoveryName;
  String? location;
  String? petName;
  String? petSpecies;
  String? petBreed;
  int? petAge;
  String? petAvatar;

  Appointment({
    required this.id,
    required this.discoveryId,
    required this.petId,
    this.apptTime,
    this.status,
    this.discoveryName,
    this.location,
    this.petName,
    this.petSpecies,
    this.petBreed,
    this.petAge,
    this.petAvatar,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] ?? 0,
      discoveryId: json['discoveryId'] ?? 0,
      petId: json['petId'] ?? 0,
      apptTime: json['apptTime'] != null ? DateTime.parse(json['apptTime']) : null,
      status: json['status'],
      discoveryName: json['discoveryName'],
      location: json['location'],
      petName: json['petName'],
      petSpecies: json['petSpecies'],
      petBreed: json['petBreed'],
      petAge: json['petAge'],
      petAvatar: json['petAvatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'discoveryId': discoveryId,
      'petId': petId,
      'apptTime': apptTime?.toIso8601String(),
      'status': status,
      'discoveryName': discoveryName,
      'location': location,
      'petName': petName,
      'petSpecies': petSpecies,
      'petBreed': petBreed,
      'petAge': petAge,
      'petAvatar': petAvatar,
    };
  }
}
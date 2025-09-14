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
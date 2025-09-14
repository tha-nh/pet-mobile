import 'dart:convert';

class Pet {
  final int? id;
  final String name;
  final String species;
  final String breed;
  final int age;
  final String avatar;
  final String? description;
  final String? medicalHistory;
  final double? weight;
  final String? color;
  final String? gender; // 👈 thêm field gender

  Pet({
    this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.age,
    required this.avatar,
    this.description,
    this.medicalHistory,
    this.weight,
    this.color,
    this.gender,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'],
      name: json['name'] ?? '',
      species: json['species'] ?? '',
      breed: json['breed'] ?? '',
      age: json['age'] ?? 0,
      avatar: json['avatar'] ?? "https://placehold.co/150x150",
      description: json['description'],
      medicalHistory: json['medicalHistory'],
      weight: json['weight']?.toDouble(),
      color: json['color'],
      gender: json['gender'], // 👈 parse thêm gender
    );
  }
}

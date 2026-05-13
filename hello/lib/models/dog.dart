import 'package:uuid/uuid.dart';

class Dog {
  Dog({
    required this.id,
    required this.callName,
    this.breed,
    this.heightInches,
    this.dateOfBirth,
    this.notes,
  });

  final String id;
  final String callName;
  final String? breed;
  final double? heightInches;
  final DateTime? dateOfBirth;
  final String? notes;

  factory Dog.create({
    required String callName,
    String? breed,
    double? heightInches,
    DateTime? dateOfBirth,
    String? notes,
  }) {
    return Dog(
      id: const Uuid().v4(),
      callName: callName,
      breed: breed,
      heightInches: heightInches,
      dateOfBirth: dateOfBirth,
      notes: notes,
    );
  }

  Dog copyWith({
    String? callName,
    String? breed,
    double? heightInches,
    DateTime? dateOfBirth,
    String? notes,
  }) => Dog(
    id: id,
    callName: callName ?? this.callName,
    breed: breed ?? this.breed,
    heightInches: heightInches ?? this.heightInches,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'callName': callName,
    if (breed != null) 'breed': breed,
    if (heightInches != null) 'heightInches': heightInches,
    if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
    if (notes != null) 'notes': notes,
  };

  factory Dog.fromJson(Map<String, dynamic> json) => Dog(
    id: json['id'] as String,
    callName: json['callName'] as String,
    breed: json['breed'] as String?,
    heightInches: (json['heightInches'] as num?)?.toDouble(),
    dateOfBirth: json['dateOfBirth'] != null
        ? DateTime.parse(json['dateOfBirth'] as String)
        : null,
    notes: json['notes'] as String?,
  );
}

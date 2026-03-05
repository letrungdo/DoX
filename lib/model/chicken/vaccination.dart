import 'package:json_annotation/json_annotation.dart';

part 'vaccination.g.dart';

@JsonSerializable()
class Vaccination {
  final String id;
  final String title;
  final DateTime scheduledDate;
  final bool isCompleted;

  Vaccination({
    required this.id,
    required this.title,
    required this.scheduledDate,
    this.isCompleted = false,
  });

  factory Vaccination.fromJson(Map<String, dynamic> json) => _$VaccinationFromJson(json);
  Map<String, dynamic> toJson() => _$VaccinationToJson(this);

  Vaccination copyWith({
    String? id,
    String? title,
    DateTime? scheduledDate,
    bool? isCompleted,
  }) {
    return Vaccination(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

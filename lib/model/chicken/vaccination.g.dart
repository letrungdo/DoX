// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vaccination.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Vaccination _$VaccinationFromJson(Map<String, dynamic> json) => Vaccination(
  id: json['id'] as String,
  title: json['title'] as String,
  scheduledDate: DateTime.parse(json['scheduledDate'] as String),
  isCompleted: json['isCompleted'] as bool? ?? false,
);

Map<String, dynamic> _$VaccinationToJson(Vaccination instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'scheduledDate': instance.scheduledDate.toIso8601String(),
      'isCompleted': instance.isCompleted,
    };

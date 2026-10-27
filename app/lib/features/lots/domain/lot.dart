import 'package:equatable/equatable.dart';
import 'package:parkspot/core/utils/availability.dart';
import 'package:parkspot/core/utils/geo_point.dart';
import 'package:parkspot/core/utils/money.dart';

/// docs/lots-api.md
class Lot extends Equatable {
  const Lot({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.pricePerHour,
    required this.totalSlots,
    required this.freeSlots,
    this.photos = const [],
  });

  factory Lot.fromJson(Map<String, dynamic> json) => Lot(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
    location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
    pricePerHour: Money.fromJson(json['pricePerHour'] as Map<String, dynamic>),
    totalSlots: json['totalSlots'] as int,
    freeSlots: json['freeSlots'] as int,
    photos: (json['photos'] as List<dynamic>).cast<String>(),
  );

  final String id;
  final String name;
  final String address;
  final GeoPoint location;
  final Money pricePerHour;
  final int totalSlots;
  final int freeSlots;
  final List<String> photos;

  Availability get availability =>
      Availability.fromCounts(free: freeSlots, total: totalSlots);

  bool get isFull => availability == Availability.full;

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    location,
    pricePerHour,
    totalSlots,
    freeSlots,
    photos,
  ];
}

import 'package:flutter/foundation.dart';

enum VehicleType { midsized, big, van }

enum VehicleSize { small, big }

enum WashType { inside, outside, both }

enum WashCategory {
  basic,
  standard,
  premium,
  deluxe;

  String get label {
    switch (this) {
      case WashCategory.basic: return 'Basic (Outside Only)';
      case WashCategory.standard: return 'Standard (Outside + Basic Inside)';
      case WashCategory.premium: return 'Premium (Full Inside + Outside)';
      case WashCategory.deluxe: return 'Deluxe (Complete Detail)';
    }
  }
}

class Sale {
  final int id;
  final VehicleType vehicleType;
  final VehicleSize vehicleSize;
  final WashType washType;
  final WashCategory washCategory;
  final double amount;
  final DateTime timestamp;
  final String licensePlate;
  final String carMake;
  final String carColor;
  final String frontCondition;
  final String backCondition;
  final String recordedBy;

  Sale({
    this.id = 0,
    required this.vehicleType,
    required this.vehicleSize,
    required this.washType,
    required this.washCategory,
    required this.amount,
    DateTime? timestamp,
    this.licensePlate = '',
    this.carMake = '',
    this.carColor = '',
    this.frontCondition = '',
    this.backCondition = '',
    this.recordedBy = '',
  }) : timestamp = timestamp ?? DateTime.now();

  String get vehicleTypeLabel {
    switch (vehicleType) {
      case VehicleType.midsized: return 'Mid Sized';
      case VehicleType.big: return 'Big';
      case VehicleType.van: return 'Van';
    }
  }

  String get vehicleSizeLabel {
    switch (vehicleSize) {
      case VehicleSize.small: return 'Small';
      case VehicleSize.big: return 'Big';
    }
  }

  String get washTypeLabel {
    switch (washType) {
      case WashType.inside: return 'Inside Wash';
      case WashType.outside: return 'Outside Wash';
      case WashType.both: return 'Inside + Outside';
    }
  }

  Map<String, dynamic> toJson() => {
    'vehicle_type': vehicleTypeLabel,
    'vehicle_size': vehicleSizeLabel,
    'wash_type': washTypeLabel,
    'wash_category': washCategory.label,
    'amount': amount,
    'license_plate': licensePlate,
    'car_make': carMake,
    'car_color': carColor,
    'front_condition': frontCondition,
    'back_condition': backCondition,
  };

  factory Sale.fromJson(Map<String, dynamic> json) {
    VehicleType _vt(String v) => v == 'Big' ? VehicleType.big : v == 'Van' ? VehicleType.van : VehicleType.midsized;
    VehicleSize _vs(String v) => v == 'Big' ? VehicleSize.big : VehicleSize.small;
    WashType _wt(String v) => v == 'Inside Wash' ? WashType.inside : v == 'Inside + Outside' ? WashType.both : WashType.outside;
    WashCategory _wc(String v) {
      if (v == 'Standard (Outside + Basic Inside)') return WashCategory.standard;
      if (v == 'Premium (Full Inside + Outside)') return WashCategory.premium;
      if (v == 'Deluxe (Complete Detail)') return WashCategory.deluxe;
      return WashCategory.basic;
    }

    return Sale(
      id: json['id'] ?? 0,
      vehicleType: _vt(json['vehicle_type'] ?? 'Mid Sized'),
      vehicleSize: _vs(json['vehicle_size'] ?? 'Small'),
      washType: _wt(json['wash_type'] ?? 'Outside Wash'),
      washCategory: _wc(json['wash_category'] ?? 'Basic (Outside Only)'),
      amount: (json['amount'] as num).toDouble(),
      timestamp: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      licensePlate: json['license_plate'] ?? '',
      carMake: json['car_make'] ?? '',
      carColor: json['car_color'] ?? '',
      frontCondition: json['front_condition'] ?? '',
      backCondition: json['back_condition'] ?? '',
      recordedBy: json['recorded_by'] ?? '',
    );
  }
}

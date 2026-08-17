import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../models/mobile_capability.dart';

abstract final class AppIcons {
  static final IconData home =
      LucideIcons.house;

  static final IconData work =
      LucideIcons.layout_grid;

  static final IconData wallet =
      LucideIcons.wallet_cards;

  static final IconData profile =
      LucideIcons.user_round;

  // Attendance is face/photo based in Salesapp.
  static final IconData attendance =
      LucideIcons.scan_face;

  static final IconData dealer =
      LucideIcons.store;

  static final IconData journey =
      LucideIcons.route;

  static final IconData leave =
      LucideIcons.calendar_x;

  static final IconData location =
      LucideIcons.navigation;

  static final IconData inspection =
      LucideIcons.clipboard_check;

  static final IconData form =
      LucideIcons.file_text;

  static final IconData camera =
      LucideIcons.camera;

  static final IconData receipt =
      LucideIcons.receipt_text;

  static final IconData map =
      LucideIcons.map;

  static final IconData mapPin =
      LucideIcons.map_pin;

  static final IconData cloud =
      LucideIcons.cloud;

  static final IconData cloudOff =
      LucideIcons.cloud_off;

  static final IconData check =
      LucideIcons.circle_check;

  static final IconData clock =
      LucideIcons.clock;

  static final IconData refresh =
      LucideIcons.refresh_cw;

  static final IconData logout =
      LucideIcons.log_out;

  static final IconData chevronRight =
      LucideIcons.chevron_right;

  static final IconData plus =
      LucideIcons.plus;

  static final IconData alert =
      LucideIcons.circle_alert;

  static final IconData indianRupee =
      LucideIcons.indian_rupee;

  static final IconData chart =
      LucideIcons.chart_no_axes_column;

  static final Map<String, IconData>
      _backendIcons = {
    'attendance': attendance,
    'face': attendance,
    'scan_face': attendance,

    // Backend may still call it fingerprint.
    // We translate that name to an icon that
    // actually exists in flutter_lucide.
    'fingerprint': attendance,
    'fingerprint_pattern':
        LucideIcons.fingerprint_pattern,

    'dealer': dealer,
    'dealer_visit': dealer,
    'store': dealer,
    'storefront': dealer,

    'journey': journey,
    'journey_plan': journey,
    'route': journey,

    'leave': leave,
    'calendar_x': leave,

    'location': location,
    'live_location': location,
    'navigation': location,

    'ta_da': wallet,
    'tada': wallet,
    'wallet': wallet,
    'wallet_cards': wallet,

    'inspection': inspection,
    'clipboard_check': inspection,
    'checklist': inspection,

    'form': form,
    'file_text': form,

    'report': chart,
    'chart': chart,

    'camera': camera,
    'photo': camera,
    'image': camera,

    'receipt': receipt,
    'receipt_text': receipt,

    'map': map,
    'map_pin': mapPin,
  };

  static IconData forCapability(
    MobileCapability capability,
  ) {
    final explicit =
        _fromBackendName(
      capability.icon,
    );

    if (explicit != null) {
      return explicit;
    }

    switch (capability.key) {
      case 'attendance':
        return attendance;

      case 'dealer_visit':
        return dealer;

      case 'journey_plan':
        return journey;

      case 'leave':
        return leave;

      case 'live_location':
        return location;

      case 'ta_da':
        return wallet;
    }

    switch (
        capability.type.toLowerCase()) {
      case 'checklist':
        return inspection;

      case 'upload':
        return camera;

      case 'report':
        return chart;

      case 'form':
      default:
        return form;
    }
  }

  static IconData? _fromBackendName(
    String? raw,
  ) {
    if (
        raw == null ||
        raw.trim().isEmpty
    ) {
      return null;
    }

    final key = raw
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    return _backendIcons[key];
  }
}
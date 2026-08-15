import 'package:flutter/material.dart';

import '../../../core/services/location/field_tracking_service.dart';
import '../../../core/session/app_session_controller.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({
    super.key,
    required this.controller,
  });

  final AppSessionController controller;

  @override
  Widget build(BuildContext context) {
    final tracker = FieldTrackingService.instance;
    final session = controller.session!;

    return Scaffold(
      appBar: AppBar(title: const Text('Field tracking')),
      body: ListenableBuilder(
        listenable: tracker,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _HeroDistance(
                distanceKm: tracker.distanceKm,
                isTracking: tracker.isTracking,
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tracker.isTracking ? 'Tracking is ON' : 'Tracking is OFF',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        tracker.message ??
                            'Tracking is normally started when you check in and stopped when you check out.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: tracker.isTracking
                            ? tracker.stop
                            : () => tracker.start(
                                  employeeId: session.user.id,
                                  accessToken: session.accessToken,
                                ),
                        icon: Icon(
                          tracker.isTracking
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outline,
                        ),
                        label: Text(
                          tracker.isTracking ? 'STOP TRACKING' : 'START TRACKING',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('When location is used'),
                  subtitle: Text(
                    'Your route is recorded for field-work visibility and travel-distance calculation. '
                    'The app makes tracking visible and you can see when it is on.',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroDistance extends StatelessWidget {
  const _HeroDistance({
    required this.distanceKm,
    required this.isTracking,
  });

  final double distanceKm;
  final bool isTracking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF303541),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTracking ? 'TODAY · LIVE' : 'TODAY',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${distanceKm.toStringAsFixed(1)} km',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'GPS-filtered field distance',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

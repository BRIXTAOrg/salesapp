import 'package:flutter/material.dart';

import '../../../core/design/app_design.dart';
import 'tracking_controller.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({
    super.key,
    required this.controller,
  });

  final TrackingController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel meter'),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (_, _) {
          final snapshot = controller.snapshot;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              28,
            ),
            children: [
              _MeterHero(
                distanceKm:
                    snapshot.distanceKm,
                speedKmh:
                    snapshot.speedKmh,
                state:
                    controller.meterState,
              ),
              const SizedBox(height: 14),
              _InfoCard(
                icon: Icons.speed_rounded,
                title: 'Motion-aware metering',
                subtitle:
                    snapshot.moving
                        ? 'The phone is moving, so the meter is sampling more closely.'
                        : 'The phone looks still, so the meter reduces sampling to save battery.',
                trailing:
                    snapshot.moving
                        ? 'MOVING'
                        : 'LOW POWER',
              ),
              const SizedBox(height: 10),
              _InfoCard(
                icon: Icons.memory_rounded,
                title: 'Phone-first storage',
                subtitle:
                    'Measurements are kept on the phone first and uploaded when the server is available.',
                trailing: 'OFFLINE SAFE',
              ),
              const SizedBox(height: 10),
              _InfoCard(
                icon: Icons.gps_fixed_rounded,
                title: 'Position fix',
                subtitle:
                    _positionText(snapshot),
                trailing:
                    snapshot.accuracyM > 0
                        ? '±${snapshot.accuracyM.toStringAsFixed(0)} m'
                        : 'WAITING',
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: controller.locateNow,
                icon: const Icon(
                  Icons.my_location_rounded,
                ),
                label: const Text(
                  'REFRESH POSITION NOW',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'The travel meter uses motion sensors to decide when higher-rate phone positioning is worth using. Position access remains required for reliable route distance and for a current admin map position.',
                style: TextStyle(
                  color: AppDesign.muted,
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _positionText(
    dynamic snapshot,
  ) {
    final lastFixAt = snapshot.lastFixAt;

    if (lastFixAt == null) {
      return 'No position fix has been recorded yet.';
    }

    final local = lastFixAt.toLocal();
    final minute =
        local.minute.toString().padLeft(2, '0');

    return 'Last reliable phone position at '
        '${local.hour}:$minute.';
  }
}

class _MeterHero extends StatelessWidget {
  const _MeterHero({
    required this.distanceKm,
    required this.speedKmh,
    required this.state,
  });

  final double distanceKm;
  final double speedKmh;
  final String state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppDesign.line,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppDesign.softBlue,
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.speed_rounded,
                  color: AppDesign.blue,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppDesign.softGray,
                  borderRadius:
                      BorderRadius.circular(999),
                ),
                child: Text(
                  state.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: .4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            '${distanceKm.toStringAsFixed(1)} km',
            style: Theme.of(context)
                .textTheme
                .headlineLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            'Captured travel',
            style: TextStyle(
              color: AppDesign.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SmallMetric(
                  label: 'PHONE SPEED',
                  value:
                      '${speedKmh.toStringAsFixed(0)} km/h',
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: AppDesign.line,
              ),
              Expanded(
                child: _SmallMetric(
                  label: 'MODE',
                  value: state,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppDesign.muted,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppDesign.line,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppDesign.softGray,
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style:
                            const TextStyle(
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      trailing,
                      style: const TextStyle(
                        color:
                            AppDesign.muted,
                        fontSize: 9.5,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppDesign.muted,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

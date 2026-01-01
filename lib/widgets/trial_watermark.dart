import 'package:flutter/material.dart';

class TrialWatermark extends StatelessWidget {
  const TrialWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 12,
      right: 12,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.25,
          child: Text(
            "TRIAL BUILD • NOT FOR REDISTRIBUTION",
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

enum OnboardingRole { learn, teach, both }

class OnboardingOption {
  final String id;
  final String label;
  const OnboardingOption(this.id, this.label);
}

class RoleOption {
  final OnboardingRole role;
  final IconData icon;
  final String label;
  const RoleOption(this.role, this.icon, this.label);
}

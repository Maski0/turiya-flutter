import 'package:flutter/material.dart';

// Debug: flip to preview day gradients.
const bool kPricingDaytime = false;

// Pricing glass tint.
// - Day: subtle black tint (increase alpha to make it darker)
// - Night: white glass tint
const Color kPricingGlassTintDay = Color.fromARGB(14, 0, 0, 0);
const Color kPricingGlassTintNight = Color.fromARGB(25, 255, 255, 255);

// Night gradients (pricing screen).
//
// Stored here for easy tuning and reuse.
const LinearGradient kPricingNightBackgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF004459),
    Color(0xFF004459),
    Color(0xFF004459),
    Color(0xFF00263B),
  ],
);

const LinearGradient kPricingNightKrishnaFadeGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: [0.0, 0.45, 0.8, 1.0],
  colors: [
    Color(0x00004459),
    Color(0xAA004459),
    Color(0xFF004459),
    Color(0xFF004459),
  ],
);

// Day gradients (pricing screen) — same structure as night, different colors.
const LinearGradient kPricingDayBackgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: [0.0, 0.14, 0.66, 1.0],
  colors: [
    Color(0xFF9D9CEB),
    Color(0xFFCBA0AD),
    Color(0xFFCBA0AD), // mid brownish haze tone (from Figma)
    Color(0xFFB3744A), // dark brown (Figma bottom overlay 30% black on #FFA569)
  ],
);

const LinearGradient kPricingDayKrishnaFadeGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: [0.0, 0.45, 0.8, 1.0],
  colors: [
    Color(0x009D9CEB),
    Color(0xAA9D9CEB),
    Color(0xFFCBA0AD),
    Color(0xFFCBA0AD),
  ],
);


import 'package:dues/domain/models/subscription.dart';

/// Offline reference prices, checked against the provider's India pages.
///
/// These are editable defaults for tracking an existing membership. They are
/// neither live quotes nor a purchase/subscription flow. Introductory offers,
/// prepaid top-ups, and account-specific discounts are deliberately excluded.
class PlanPreset {
  const PlanPreset({
    required this.id,
    required this.name,
    required this.amount,
    required this.cycle,
    this.currency = 'INR',
    this.note,
  });

  final String id;
  final String name;
  final double amount;
  final BillingCycle cycle;
  final String currency;
  final String? note;
}

class PopularService {
  const PopularService({
    required this.id,
    required this.name,
    required this.aliases,
    required this.plans,
    required this.sourceUrl,
    required this.checkedOn,
  });

  final String id;
  final String name;
  final List<String> aliases;
  final List<PlanPreset> plans;
  final String sourceUrl;

  /// ISO calendar date. Kept with each service for future catalog maintenance.
  final String checkedOn;
}

const popularServices = <PopularService>[
  PopularService(
    id: 'netflix',
    name: 'Netflix',
    aliases: ['Netflix', 'Netflix India', 'Netflix.com'],
    sourceUrl: 'https://qr.netflix.com/in/title/80178726',
    checkedOn: '2026-11-06',
    plans: [
      PlanPreset(
        id: 'netflix-mobile',
        name: 'Mobile',
        amount: 149,
        cycle: BillingCycle.monthly,
      ),
      PlanPreset(
        id: 'netflix-basic',
        name: 'Basic',
        amount: 199,
        cycle: BillingCycle.monthly,
      ),
      PlanPreset(
        id: 'netflix-standard',
        name: 'Standard',
        amount: 499,
        cycle: BillingCycle.monthly,
      ),
      PlanPreset(
        id: 'netflix-premium',
        name: 'Premium',
        amount: 649,
        cycle: BillingCycle.monthly,
      ),
    ],
  ),
  PopularService(
    id: 'amazon-prime',
    name: 'Amazon Prime',
    aliases: [
      'Amazon',
      'Amazon Prime',
      'Prime',
      'Prime Video',
      'Amazon Prime Video',
      'AMZN Prime',
    ],
    sourceUrl: 'https://www.aboutamazon.in/news/retail/how-to-sign-up-for-a-prime-membership',
    checkedOn: '2026-11-06',
    plans: [
      PlanPreset(
        id: 'prime-monthly',
        name: 'Prime monthly',
        amount: 299,
        cycle: BillingCycle.monthly,
      ),
      PlanPreset(
        id: 'prime-quarterly',
        name: 'Prime quarterly',
        amount: 599,
        cycle: BillingCycle.quarterly,
      ),
      PlanPreset(
        id: 'prime-yearly',
        name: 'Prime annual',
        amount: 1499,
        cycle: BillingCycle.yearly,
      ),
    ],
  ),
  PopularService(
    id: 'spotify',
    name: 'Spotify',
    aliases: ['Spotify', 'Spotify Premium', 'Spotify India'],
    sourceUrl: 'https://www.spotify.com/in-en/premium/',
    checkedOn: '2026-11-06',
    plans: [
      PlanPreset(
        id: 'spotify-standard',
        name: 'Standard',
        amount: 139,
        cycle: BillingCycle.monthly,
      ),
      PlanPreset(
        id: 'spotify-platinum',
        name: 'Platinum',
        amount: 299,
        cycle: BillingCycle.monthly,
      ),
      PlanPreset(
        id: 'spotify-student',
        name: 'Student',
        amount: 69,
        cycle: BillingCycle.monthly,
        note: 'Requires student eligibility',
      ),
    ],
  ),
];

/// Matches explicit aliases without treating every Amazon purchase as Prime.
PopularService? serviceForName(String name) {
  final normalized = _normalize(name);
  if (normalized.isEmpty) return null;
  for (final service in popularServices) {
    if (service.aliases.any((alias) => _normalize(alias) == normalized)) {
      return service;
    }
  }
  return null;
}

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

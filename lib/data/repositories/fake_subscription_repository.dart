import 'package:dues/domain/models/subscription.dart';

class FakeSubscriptionRepository {
  List<Subscription> load(DateTime now) => [
    Subscription(
      id: 'netflix',
      name: 'Netflix',
      amount: 649,
      cycle: BillingCycle.monthly,
      nextDueDate: now.add(const Duration(days: 2)),
    ),
    Subscription(
      id: 'spotify',
      name: 'Spotify',
      amount: 119,
      cycle: BillingCycle.monthly,
      nextDueDate: now.add(const Duration(days: 5)),
    ),
    Subscription(
      id: 'youtube',
      name: 'YouTube Premium',
      amount: 149,
      cycle: BillingCycle.monthly,
      nextDueDate: now.add(const Duration(days: 11)),
    ),
    Subscription(
      id: 'notion',
      name: 'Notion',
      amount: 3999,
      cycle: BillingCycle.yearly,
      nextDueDate: now.add(const Duration(days: 24)),
    ),
    Subscription(
      id: 'cult',
      name: 'Cult.fit',
      amount: 2999,
      cycle: BillingCycle.quarterly,
      nextDueDate: now.add(const Duration(days: 47)),
      isAutoDetected: false,
    ),
  ];
}

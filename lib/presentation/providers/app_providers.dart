import 'package:dues/data/repositories/fake_subscription_repository.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clockProvider = Provider<DateTime>((ref) => DateTime.now());
final repositoryProvider = Provider((ref) => FakeSubscriptionRepository());

class SubscriptionsController extends Notifier<List<Subscription>> {
  @override
  List<Subscription> build() =>
      ref.read(repositoryProvider).load(ref.read(clockProvider));

  void togglePaused(String id) {
    state = [
      for (final subscription in state)
        if (subscription.id == id)
          subscription.copyWith(isPaused: !subscription.isPaused)
        else
          subscription,
    ];
  }

  void remove(String id) {
    state = state.where((subscription) => subscription.id != id).toList();
  }
}

final subscriptionsProvider =
    NotifierProvider<SubscriptionsController, List<Subscription>>(
      SubscriptionsController.new,
    );

class SelectedTabController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final selectedTabProvider = NotifierProvider<SelectedTabController, int>(
  SelectedTabController.new,
);

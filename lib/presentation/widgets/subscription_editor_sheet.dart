import 'dart:async';

import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/core/utils/formatters.dart';
import 'package:dues/data/catalog/popular_plans.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:dues/presentation/providers/reminder_sync_provider.dart';
import 'package:dues/presentation/widgets/receipt_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

Future<bool?> showSubscriptionEditor(
  BuildContext context, {
  Subscription? subscription,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .9,
    minChildSize: .3,
    maxChildSize: .95,
    builder: (context, controller) => SubscriptionEditorSheet(
      subscription: subscription,
      scrollController: controller,
    ),
  ),
);

class SubscriptionEditorSheet extends ConsumerStatefulWidget {
  const SubscriptionEditorSheet({
    this.subscription,
    this.scrollController,
    super.key,
  });
  final Subscription? subscription;
  final ScrollController? scrollController;

  @override
  ConsumerState<SubscriptionEditorSheet> createState() =>
      _SubscriptionEditorSheetState();
}

class _SubscriptionEditorSheetState
    extends ConsumerState<SubscriptionEditorSheet> {
  late final TextEditingController nameController;
  late final TextEditingController amountController;
  late BillingCycle cycle;
  late DateTime nextDueDate;
  late String currency;
  String? selectedPlanId;
  bool saving = false;
  bool currencyChosen = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.subscription;
    nameController = TextEditingController(text: existing?.name ?? '');
    amountController = TextEditingController(
      text: existing == null ? '' : _amountText(existing.amount),
    );
    cycle = existing?.cycle ?? BillingCycle.monthly;
    currency = existing?.currency ?? 'INR';
    nextDueDate =
        existing?.nextDueDate ?? DateTime.now().add(const Duration(days: 30));
    if (existing == null) _loadDefaultCurrency();
  }

  Future<void> _loadDefaultCurrency() async {
    try {
      final preferences = await ref.read(appPreferencesProvider.future);
      if (mounted && !currencyChosen) {
        setState(() => currency = preferences.currency);
      }
    } catch (_) {
      // INR remains usable if local preferences cannot be loaded.
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    super.dispose();
  }

  String _amountText(double amount) => amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toString();

  void _selectService(PopularService service) {
    ref.read(hapticsProvider).selectionClick();
    setState(() {
      nameController.text = service.name;
      selectedPlanId = null;
    });
  }

  void _selectPlan(PlanPreset plan) {
    ref.read(hapticsProvider).selectionClick();
    setState(() {
      selectedPlanId = plan.id;
      amountController.text = _amountText(plan.amount);
      currency = plan.currency;
      currencyChosen = true;
      cycle = plan.cycle;
    });
  }

  Future<void> _chooseDate() async {
    ref.read(hapticsProvider).selectionClick();
    final today = DateUtils.dateOnly(DateTime.now());
    final horizon = today.add(const Duration(days: 3650));
    final tokens = context.receipt;
    final square = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    );
    final date = await showDatePicker(
      context: context,
      initialDate: nextDueDate,
      firstDate: nextDueDate.isBefore(today) ? nextDueDate : today,
      lastDate: nextDueDate.isAfter(horizon) ? nextDueDate : horizon,
      helpText: 'NEXT DUE DATE',
      cancelText: 'CANCEL',
      confirmText: 'SET DATE',
      builder: (context, child) => DatePickerTheme(
        data: DatePickerThemeData(
          backgroundColor: tokens.paper,
          headerBackgroundColor: tokens.paper,
          headerForegroundColor: tokens.ink,
          dividerColor: tokens.divider,
          elevation: 0,
          shape: square.copyWith(side: BorderSide(color: tokens.divider)),
          dayShape: WidgetStatePropertyAll(square),
          yearShape: WidgetStatePropertyAll(square),
          headerHelpStyle: Theme.of(context).textTheme.receiptLabel,
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) setState(() => nextDueDate = date);
  }

  Future<T?> _chooseValue<T>({
    required String title,
    required T current,
    required Map<T, String> options,
  }) {
    ref.read(hapticsProvider).selectionClick();
    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: SectionHeader(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              for (final entry in options.entries)
                _ReceiptOption(
                  label: entry.value,
                  selected: entry.key == current,
                  onPressed: () => Navigator.pop(context, entry.key),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseCurrency() async {
    final code = await _chooseValue(
      title: 'CURRENCY',
      current: currency,
      options: {
        for (final code in {'INR', 'USD', 'EUR', 'GBP', currency}) code: code,
      },
    );
    if (code == null || !mounted) return;
    setState(() {
      currency = code;
      currencyChosen = true;
      selectedPlanId = null;
    });
  }

  Future<void> _chooseCycle() async {
    final selected = await _chooseValue(
      title: 'BILLING CYCLE',
      current: cycle,
      options: {for (final item in BillingCycle.values) item: item.label},
    );
    if (selected == null || !mounted) return;
    setState(() {
      cycle = selected;
      selectedPlanId = null;
    });
  }

  Future<void> _save() async {
    if (saving) return;
    final name = nameController.text.trim();
    final amount = double.tryParse(
      amountController.text.replaceAll(',', '').trim(),
    );
    if (name.isEmpty || amount == null || !amount.isFinite || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name and valid amount.')),
      );
      return;
    }
    setState(() => saving = true);
    final repository = ref.read(repositoryProvider);
    final reminderSync = ref.read(reminderSyncProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final existing = widget.subscription;
      await repository.saveSubscription(
        Subscription(
          id: existing?.id ?? const Uuid().v4(),
          name: name,
          normalizedMerchant: existing?.normalizedMerchant,
          amount: amount,
          currency: currency,
          cycle: cycle,
          nextDueDate: nextDueDate,
          isPaused: existing?.isPaused ?? false,
          // Preserve the SMS link while protecting user changes from rescans.
          isAutoDetected: false,
        ),
      );
      if (!mounted) return;
      ref.read(hapticsProvider).selectionClick();
      Navigator.pop(context, true);
      // Reminders are a separate side effect: a plugin failure must never
      // leave a successful database write spinning in the editor.
      unawaited(() async {
        final refreshed = await reminderSync.sync();
        if (!refreshed && messenger.mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Subscription saved. Reminders could not refresh; retry from Settings.',
              ),
            ),
          );
        }
      }());
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save this subscription. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = serviceForName(nameController.text);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: SizedBox(width: 36, child: Divider(thickness: 3)),
            ),
            const SizedBox(height: 18),
            Text(
              widget.subscription == null
                  ? 'ADD SUBSCRIPTION'
                  : 'EDIT SUBSCRIPTION',
              style: Theme.of(context).textTheme.receiptHeading
                  .copyWith(fontSize: 24),
            ),
            if (widget.subscription == null) ...[
              const SizedBox(height: 20),
              const SectionHeader('POPULAR IN INDIA'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in popularServices)
                    _ReceiptOption(
                      label: item.name.toUpperCase(),
                      selected: service == item,
                      onPressed: saving ? null : () => _selectService(item),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            TextField(
              key: const ValueKey('subscription-name'),
              controller: nameController,
              enabled: !saving,
              onChanged: (_) => setState(() => selectedPlanId = null),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'SERVICE NAME',
                hintText: 'Netflix',
              ),
            ),
            if (service != null) ...[
              const SizedBox(height: 16),
              const SectionHeader('PLAN SUGGESTIONS'),
              const SizedBox(height: 8),
              for (final plan in service.plans) ...[
                _ReceiptOption(
                  label: plan.name.toUpperCase(),
                  price:
                      '${formatReceiptAmount(plan.amount, currency: plan.currency)} / ${switch (plan.cycle) {
                        BillingCycle.weekly => 'WK',
                        BillingCycle.monthly => 'MO',
                        BillingCycle.quarterly => 'QTR',
                        BillingCycle.yearly => 'YR',
                      }}',
                  selected: selectedPlanId == plan.id,
                  onPressed: saving ? null : () => _selectPlan(plan),
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 8),
              Text(
                'India prices checked ${service.checkedOn}. You can edit the amount and cycle.',
                style: TextStyle(
                  color: context.receipt.muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('subscription-amount'),
              controller: amountController,
              enabled: !saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() => selectedPlanId = null),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'AMOUNT',
                hintText: '0.00',
                prefixText: '$currency ',
              ),
            ),
            const SizedBox(height: 16),
            const SectionHeader('BILLING DETAILS'),
            LeaderLine(
              key: ValueKey('currency-$currency'),
              label: 'CURRENCY',
              amount: '[ $currency ]',
              onTap: saving ? null : _chooseCurrency,
            ),
            LeaderLine(
              key: ValueKey('cycle-${cycle.name}'),
              label: 'BILLING CYCLE',
              amount: '[ ${cycle.label} ]',
              onTap: saving ? null : _chooseCycle,
            ),
            LeaderLine(
              label: 'NEXT DUE',
              amount: '[ ${formatShortDate(nextDueDate)} ${nextDueDate.year} ]',
              onTap: saving ? null : _chooseDate,
            ),
            const SizedBox(height: 24),
            ReceiptButton(
              key: const ValueKey('save-subscription'),
              label: widget.subscription == null ? 'SAVE' : 'UPDATE',
              onPressed: _save,
              busy: saving,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptOption extends StatelessWidget {
  const _ReceiptOption({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.price,
  });

  final String label;
  final String? price;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: selected ? context.receipt.ink : context.receipt.paper,
        foregroundColor: selected ? context.receipt.paper : context.receipt.ink,
        side: BorderSide(color: context.receipt.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: Theme.of(context).textTheme.receiptLabel,
      ),
      onPressed: onPressed,
      child: price == null
          ? Text(label)
          : Row(
              children: [
                Expanded(child: Text(label)),
                const SizedBox(width: 8),
                Flexible(child: Text(price!, textAlign: TextAlign.right)),
              ],
            ),
    ),
  );
}

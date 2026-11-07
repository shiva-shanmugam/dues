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
  showDragHandle: true,
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
              const _FieldLabel('POPULAR IN INDIA'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in popularServices)
                    ActionChip(
                      label: Text(item.name),
                      onPressed: saving ? null : () => _selectService(item),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a service for plan suggestions, or enter any name below.',
                style: TextStyle(
                  color: context.receipt.muted,
                  fontSize: 10,
                  height: 1.6,
                ),
              ),
            ],
            const SizedBox(height: 22),
            const _FieldLabel('NAME'),
            TextField(
              key: const ValueKey('subscription-name'),
              controller: nameController,
              enabled: !saving,
              onChanged: (_) => setState(() => selectedPlanId = null),
              textCapitalization: TextCapitalization.words,
              decoration: _decoration(context, 'Netflix'),
            ),
            if (service != null) ...[
              const SizedBox(height: 16),
              const _FieldLabel('PLAN SUGGESTIONS'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final plan in service.plans)
                    ChoiceChip(
                      selected: selectedPlanId == plan.id,
                      onSelected: saving ? null : (_) => _selectPlan(plan),
                      label: Text(
                        '${plan.name} · ${formatMoney(plan.amount, plan.currency)} / ${plan.cycle.label.toLowerCase()}',
                      ),
                      labelStyle: const TextStyle(fontSize: 10),
                      selectedColor: context.receipt.ink.withValues(alpha: .08),
                      checkmarkColor: context.receipt.ink,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'India reference prices · checked ${service.checkedOn}. Your bill may differ. Amount and cycle stay editable.',
                style: TextStyle(
                  color: context.receipt.muted,
                  fontSize: 9,
                  height: 1.6,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const _FieldLabel('AMOUNT'),
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
              decoration: _decoration(context, '649', prefix: '$currency '),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('CURRENCY'),
            DropdownButtonFormField<String>(
              key: ValueKey('currency-$currency'),
              initialValue: currency,
              dropdownColor: context.receipt.paper,
              decoration: _decoration(context, ''),
              items: [
                for (final code in {'INR', 'USD', 'EUR', 'GBP', currency})
                  DropdownMenuItem(value: code, child: Text(code)),
              ],
              onChanged: saving
                  ? null
                  : (value) => setState(() {
                      currency = value ?? currency;
                      currencyChosen = true;
                      selectedPlanId = null;
                    }),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('BILLING CYCLE'),
            DropdownButtonFormField<BillingCycle>(
              key: ValueKey('cycle-${cycle.name}'),
              initialValue: cycle,
              dropdownColor: context.receipt.paper,
              decoration: _decoration(context, ''),
              items: [
                for (final item in BillingCycle.values)
                  DropdownMenuItem(value: item, child: Text(item.label)),
              ],
              onChanged: saving
                  ? null
                  : (value) => setState(() {
                      cycle = value ?? cycle;
                      selectedPlanId = null;
                    }),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('NEXT DUE DATE'),
            InkWell(
              onTap: saving
                  ? null
                  : () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        initialDate: nextDueDate,
                        firstDate: nextDueDate.isBefore(now)
                            ? nextDueDate
                            : DateTime(now.year, now.month, now.day),
                        lastDate:
                            nextDueDate.isAfter(
                              now.add(const Duration(days: 3650)),
                            )
                            ? nextDueDate
                            : now.add(const Duration(days: 3650)),
                      );
                      if (date != null && mounted) {
                        setState(() => nextDueDate = date);
                      }
                    },
              child: InputDecorator(
                decoration: _decoration(context, ''),
                child: Text(
                  '${nextDueDate.day.toString().padLeft(2, '0')}/${nextDueDate.month.toString().padLeft(2, '0')}/${nextDueDate.year}',
                ),
              ),
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

  InputDecoration _decoration(
    BuildContext context,
    String hint, {
    String? prefix,
  }) => InputDecoration(hintText: hint, prefixText: prefix);
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.receiptLabel),
  );
}

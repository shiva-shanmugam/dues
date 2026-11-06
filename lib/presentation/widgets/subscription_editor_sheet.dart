import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class SubscriptionEditorSheet extends ConsumerStatefulWidget {
  const SubscriptionEditorSheet({this.subscription, super.key});
  final Subscription? subscription;

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
  bool saving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.subscription?.name ?? '',
    );
    amountController = TextEditingController(
      text: widget.subscription?.amount.toStringAsFixed(0) ?? '',
    );
    cycle = widget.subscription?.cycle ?? BillingCycle.monthly;
    nextDueDate =
        widget.subscription?.nextDueDate ??
        DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = nameController.text.trim();
    final amount = double.tryParse(
      amountController.text.replaceAll(',', '').trim(),
    );
    if (name.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name and valid amount.')),
      );
      return;
    }
    setState(() => saving = true);
    final existing = widget.subscription;
    await ref
        .read(repositoryProvider)
        .saveSubscription(
          Subscription(
            id: existing?.id ?? const Uuid().v4(),
            name: name,
            normalizedMerchant: existing?.normalizedMerchant,
            amount: amount,
            currency: existing?.currency ?? 'INR',
            cycle: cycle,
            nextDueDate: nextDueDate,
            isPaused: existing?.isPaused ?? false,
            isAutoDetected: existing?.isAutoDetected ?? false,
          ),
        );
    await ref
        .read(notificationServiceProvider)
        .scheduleRenewals(
          await ref.read(repositoryProvider).getSubscriptions(),
        );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
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
              style: const TextStyle(
                fontFamily: 'Doto',
                fontVariations: [FontVariation('wght', 800)],
                fontSize: 25,
              ),
            ),
            const SizedBox(height: 22),
            const _FieldLabel('NAME'),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration('Netflix'),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('AMOUNT'),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: _decoration('649', prefix: '₹ '),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('BILLING CYCLE'),
            DropdownButtonFormField<BillingCycle>(
              initialValue: cycle,
              dropdownColor: DuesColors.surfaceRaised,
              decoration: _decoration(''),
              items: [
                for (final item in BillingCycle.values)
                  DropdownMenuItem(value: item, child: Text(item.label)),
              ],
              onChanged: (value) => setState(() => cycle = value ?? cycle),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('NEXT DUE DATE'),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: nextDueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (date != null) setState(() => nextDueDate = date);
              },
              child: InputDecorator(
                decoration: _decoration(''),
                child: Text(
                  '${nextDueDate.day.toString().padLeft(2, '0')}/${nextDueDate.month.toString().padLeft(2, '0')}/${nextDueDate.year}',
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: DuesColors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: saving
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : const Text(
                        'SAVE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, {String? prefix}) => InputDecoration(
    hintText: hint,
    prefixText: prefix,
    filled: true,
    fillColor: DuesColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: DuesColors.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: DuesColors.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: DuesColors.offWhite),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.label),
  );
}

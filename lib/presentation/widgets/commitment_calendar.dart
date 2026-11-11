import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/core/utils/formatters.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/services/commitment_schedule.dart';
import 'package:dues/presentation/widgets/receipt_widgets.dart';
import 'package:flutter/material.dart';

class CommitmentCalendar extends StatefulWidget {
  const CommitmentCalendar({
    required this.subscriptions,
    required this.now,
    required this.onInteraction,
    this.onClose,
    super.key,
  });

  final List<Subscription> subscriptions;
  final DateTime now;
  final VoidCallback onInteraction;
  final VoidCallback? onClose;

  @override
  State<CommitmentCalendar> createState() => _CommitmentCalendarState();
}

class _CommitmentCalendarState extends State<CommitmentCalendar> {
  late DateTime _month = DateTime(widget.now.year, widget.now.month);

  static const _months = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];
  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final occurrences = CommitmentSchedule.forMonth(
      widget.subscriptions,
      _month,
    );
    final byDay = <int, List<CommitmentOccurrence>>{};
    for (final occurrence in occurrences) {
      byDay.putIfAbsent(occurrence.dueDate.day, () => []).add(occurrence);
    }
    final firstWeekday = DateTime(_month.year, _month.month).weekday;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cellCount = ((firstWeekday - 1 + days) / 7).ceil() * 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'COMMITMENT CALENDAR',
                style: Theme.of(context).textTheme.receiptLabel,
              ),
            ),
            Text(
              '${occurrences.length.toString().padLeft(2, '0')} DUE',
              style: TextStyle(
                color: context.receipt.muted,
                fontSize: 10,
                letterSpacing: .7,
              ),
            ),
            if (widget.onClose != null) ...[
              const SizedBox(width: 10),
              _CloseButton(onTap: widget.onClose!),
            ],
          ],
        ),
        const SizedBox(height: 10),
        const DashedDivider(),
        const SizedBox(height: 14),
        Row(
          children: [
            _MonthButton(
              label: '<',
              semanticLabel: 'Previous month',
              onTap: () => _moveMonth(-1),
            ),
            Expanded(
              child: Text(
                '${_months[_month.month - 1]} ${_month.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            _MonthButton(
              label: '>',
              semanticLabel: 'Next month',
              onTap: () => _moveMonth(1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final day in _weekdays)
              Expanded(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.receipt.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: .9,
          ),
          itemCount: cellCount,
          itemBuilder: (context, index) {
            final day = index - firstWeekday + 2;
            if (day < 1 || day > days) return const SizedBox.shrink();
            final due = byDay[day] ?? const <CommitmentOccurrence>[];
            final date = DateTime(_month.year, _month.month, day);
            final isToday = _sameDay(date, widget.now);
            return _CalendarDay(
              key: ValueKey('calendar-day-${date.year}-${date.month}-$day'),
              day: day,
              dueCount: due.length,
              isToday: isToday,
              onTap: due.isEmpty
                  ? null
                  : (anchorContext) => _showDay(anchorContext, date, due),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          'FILLED DATES HAVE SCHEDULED COMMITMENTS · TAP FOR DETAILS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.receipt.muted,
            fontSize: 9,
            height: 1.4,
            letterSpacing: .4,
          ),
        ),
      ],
    );
  }

  void _moveMonth(int offset) {
    widget.onInteraction();
    setState(() => _month = DateTime(_month.year, _month.month + offset));
  }

  void _showDay(
    BuildContext anchorContext,
    DateTime date,
    List<CommitmentOccurrence> due,
  ) {
    widget.onInteraction();
    final anchor = anchorContext.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = anchor.localToGlobal(
      anchor.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    showMenu<void>(
      context: context,
      elevation: 0,
      color: context.receipt.paper,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 330),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: context.receipt.divider, width: 1.5),
      ),
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: const EdgeInsets.all(14),
          child: _CommitmentBubble(
            date: date,
            occurrences: due,
            now: widget.now,
          ),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Close calendar',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: context.receipt.divider),
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Text(
          '×',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 42,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: context.receipt.divider),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.dueCount,
    required this.isToday,
    required this.onTap,
    super.key,
  });

  final int day;
  final int dueCount;
  final bool isToday;
  final ValueChanged<BuildContext>? onTap;

  @override
  Widget build(BuildContext context) {
    final hasDue = dueCount > 0;
    final tokens = context.receipt;
    return Semantics(
      button: hasDue,
      label: hasDue ? 'Day $day, $dueCount commitments due' : 'Day $day',
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: hasDue ? tokens.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          child: InkWell(
            onTap: onTap == null ? null : () => onTap!(context),
            borderRadius: BorderRadius.circular(3),
            child: Container(
              decoration: BoxDecoration(
                border: isToday && !hasDue
                    ? Border.all(color: tokens.divider)
                    : null,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: hasDue ? tokens.paper : tokens.ink,
                      fontSize: 11,
                      fontWeight: hasDue ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (hasDue)
                    Text(
                      dueCount == 1 ? 'DUE' : 'DUE×$dueCount',
                      style: TextStyle(
                        color: tokens.paper,
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    SizedBox(
                      width: 8,
                      height: 1,
                      child: ColoredBox(
                        color: isToday ? tokens.ink : Colors.transparent,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommitmentBubble extends StatelessWidget {
  const _CommitmentBubble({
    required this.date,
    required this.occurrences,
    required this.now,
  });

  final DateTime date;
  final List<CommitmentOccurrence> occurrences;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final status = date.isBefore(DateTime(now.year, now.month, now.day))
        ? 'DATE PASSED'
        : _CommitmentCalendarState._sameDay(date, now)
        ? 'DUE TODAY'
        : 'UPCOMING';
    final totals = <String, double>{};
    for (final occurrence in occurrences) {
      totals.update(
        occurrence.subscription.currency,
        (value) => value + occurrence.subscription.amount,
        ifAbsent: () => occurrence.subscription.amount,
      );
    }

    return DefaultTextStyle(
      style: TextStyle(color: context.receipt.ink, fontFamily: 'IBMPlexMono'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            formatLongReceiptDate(date),
            maxLines: 2,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$status · ${occurrences.length} DUE',
            style: TextStyle(
              color: context.receipt.muted,
              fontSize: 9,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 9),
          const DashedDivider(height: 1, dash: 4, gap: 3),
          const SizedBox(height: 5),
          for (final occurrence in occurrences) ...[
            _BubbleLine(
              label: occurrence.subscription.name.toUpperCase(),
              amount: formatReceiptAmount(
                occurrence.subscription.amount,
                currency: occurrence.subscription.currency,
              ),
            ),
            Text(
              '${occurrence.subscription.cycle.label} · '
              '${occurrence.subscription.isAutoDetected ? 'FROM SMS' : 'MANUAL'}',
              style: TextStyle(
                color: context.receipt.muted,
                fontSize: 8,
                letterSpacing: .3,
              ),
            ),
            const SizedBox(height: 5),
          ],
          const DashedDivider(height: 1, dash: 4, gap: 3),
          const SizedBox(height: 4),
          for (final total in totals.entries)
            _BubbleLine(
              label: 'TOTAL / ${total.key}',
              amount: formatReceiptAmount(total.value, currency: total.key),
              strong: true,
            ),
        ],
      ),
    );
  }
}

class _BubbleLine extends StatelessWidget {
  const _BubbleLine({
    required this.label,
    required this.amount,
    this.strong = false,
  });

  final String label;
  final String amount;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.receipt.ink,
              fontSize: strong ? 10 : 11,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          amount,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: context.receipt.ink,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

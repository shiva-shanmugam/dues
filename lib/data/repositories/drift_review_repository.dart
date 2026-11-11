import 'package:drift/drift.dart';
import 'package:dues/data/database/app_database.dart';
import 'package:dues/domain/models/change_event.dart' as domain;
import 'package:dues/domain/models/review_candidate.dart' as domain;
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/repositories/review_repository.dart';

class DriftReviewRepository implements ReviewRepository {
  DriftReviewRepository(this.database);

  final AppDatabase database;

  @override
  Stream<List<domain.ReviewCandidate>> watchCandidates() {
    final query = database.select(database.reviewCandidates)
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    return query.watch().map((rows) => rows.map(_candidate).toList());
  }

  @override
  Future<List<domain.ReviewCandidate>> getCandidates() async {
    final rows = await database.select(database.reviewCandidates).get();
    return rows.map(_candidate).toList();
  }

  @override
  Future<void> saveCandidate(domain.ReviewCandidate candidate) => database
      .into(database.reviewCandidates)
      .insertOnConflictUpdate(
        ReviewCandidatesCompanion.insert(
          id: candidate.id,
          merchant: candidate.merchant,
          amount: candidate.amount,
          currency: Value(candidate.currency),
          cycle: candidate.cycle.name,
          nextDueDate: candidate.nextDueDate,
          occurrences: candidate.occurrences,
          signal: Value(candidate.signal),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> removeCandidate(String id) async {
    await (database.delete(
      database.reviewCandidates,
    )..where((row) => row.id.equals(id))).go();
  }

  @override
  Stream<List<domain.ChangeEvent>> watchChangeEvents() {
    final query = database.select(database.changeEvents)
      ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => domain.ChangeEvent(
              id: row.id,
              subscriptionId: row.subscriptionId,
              merchant: row.merchant,
              type: domain.ChangeEventType.values.byName(row.type),
              beforeAmount: row.beforeAmount,
              afterAmount: row.afterAmount,
              currency: row.currency,
              occurredAt: row.occurredAt,
            ),
          )
          .toList(),
    );
  }

  domain.ReviewCandidate _candidate(ReviewCandidate row) =>
      domain.ReviewCandidate(
        id: row.id,
        merchant: row.merchant,
        amount: row.amount,
        currency: row.currency,
        cycle: BillingCycle.values.byName(row.cycle),
        nextDueDate: row.nextDueDate,
        occurrences: row.occurrences,
        signal: row.signal,
      );
}

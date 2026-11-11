import 'package:dues/domain/models/change_event.dart';
import 'package:dues/domain/models/review_candidate.dart';

abstract interface class ReviewRepository {
  Stream<List<ReviewCandidate>> watchCandidates();
  Future<List<ReviewCandidate>> getCandidates();
  Future<void> saveCandidate(ReviewCandidate candidate);
  Future<void> removeCandidate(String id);
  Stream<List<ChangeEvent>> watchChangeEvents();
}

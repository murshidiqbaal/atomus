import '../models/dummy_data.dart';

class FeeRepository {
  Future<List<FeeRecord>> getFeeRecords() async {
    await Future.delayed(const Duration(milliseconds: 700));
    return DummyData.fees;
  }

  Future<void> payFee(String feeTitle) async {
    await Future.delayed(const Duration(seconds: 1));
  }
}

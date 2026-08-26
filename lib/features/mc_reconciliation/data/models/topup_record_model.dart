import 'package:excel/excel.dart';
import '../../domain/entities/topup_record.dart';
class TopUpRecordModel extends TopUpRecord {
  const TopUpRecordModel({
    required super.transactionDate,
    required super.clientId,
    required super.pan,
    required super.initialBalance,
    super.annualFee,
    required super.remainingAmount,
  });

  factory TopUpRecordModel.fromExcelRow(List<dynamic> row) {
    // Helper to safely extract raw value out of Excel Data/CellValue
    dynamic rawCellValue(int index) {
      if (index >= row.length || row[index] == null) return null;
      final cell = row[index];
      // Extract value without triggering Data.toString() formatting exceptions
      return cell is Data ? cell.value : cell;
    }

    String safeString(int index) {
      final val = rawCellValue(index);
      if (val == null) return '';
      if (val is TextCellValue) return val.value.toString().trim();
      return val.toString().trim();
    }
    double safeDouble(int index) {
      final val = rawCellValue(index);
      if (val == null) return 0.0;
      if (val is DoubleCellValue) return val.value;
      if (val is IntCellValue) return val.value.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }
    double? safeNullableDouble(int index) {
      final val = rawCellValue(index);
      if (val == null) return null;
      if (val is DoubleCellValue) return val.value;
      if (val is IntCellValue) return val.value.toDouble();
      return double.tryParse(val.toString());
    }

    return TopUpRecordModel(
      transactionDate: safeString(0),
      clientId: safeString(1),
      pan: safeString(2),
      initialBalance: safeDouble(3),
      annualFee: safeNullableDouble(4),
      remainingAmount: safeDouble(5),
    );
  }
}
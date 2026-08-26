/// Parses initial TopUp Excel/CSV rows into structured maps.
///
/// Supports both header-aware and positional (headerless) parsing.
/// Returns a list of maps with keys: `transactionDate`, `clientId`, `pan`, `topUpAmount`.
class ExcelTopUpParser {
  /// Parse raw Excel/CSV rows into structured top-up data.
  ///
  /// If the first row contains header keywords (client, pan, date, topup/balance/amount),
  /// column indices are auto-detected. Otherwise, positional defaults are used:
  ///   - Col 0: Client ID
  ///   - Col 1: PAN
  ///   - Col 2: TopUp Amount
  static List<Map<String, dynamic>> parseRows(List<List<dynamic>> rawRows) {
    if (rawRows.isEmpty) return [];

    final List<Map<String, dynamic>> parsedRows = [];

    int startRowIndex = 0;
    bool hasHeader = false;

    // Detect header row
    if (rawRows.first.isNotEmpty) {
      final firstRowStr = rawRows.first.join(' ').toLowerCase();
      if (firstRowStr.contains('client') ||
          firstRowStr.contains('pan') ||
          firstRowStr.contains('date')) {
        hasHeader = true;
        startRowIndex = 1;
      }
    }

    int dateIdx = -1;
    int clientIdIdx = -1;
    int panIdx = -1;
    int topUpIdx = -1;

    if (hasHeader) {
      final header =
          rawRows.first.map((e) => e.toString().toLowerCase().trim()).toList();
      dateIdx =
          header.indexWhere((h) => h.contains('date') || h.contains('time'));
      clientIdIdx = header.indexWhere((h) => h.contains('client'));
      panIdx = header.indexWhere((h) => h.contains('pan'));
      topUpIdx = header.indexWhere((h) =>
          h.contains('topup') ||
          h.contains('top-up') ||
          h.contains('top_up') ||
          h.contains('balance') ||
          h.contains('amount'));
    }

    for (int i = startRowIndex; i < rawRows.length; i++) {
      final row = rawRows[i];
      if (row.length < 3) continue;

      String transactionDate = '';
      String clientId = '';
      String pan = '';
      double topUpAmount = 0.0;

      if (hasHeader && clientIdIdx != -1 && panIdx != -1) {
        // Header-aware mode
        transactionDate = dateIdx != -1 && dateIdx < row.length
            ? row[dateIdx]?.toString().trim() ?? ''
            : '';
        clientId = clientIdIdx < row.length
            ? row[clientIdIdx]?.toString().trim() ?? ''
            : '';
        pan =
            panIdx < row.length ? row[panIdx]?.toString().trim() ?? '' : '';

        if (topUpIdx != -1 && topUpIdx < row.length) {
          final rawAmt =
              row[topUpIdx]?.toString().replaceAll(',', '').trim() ?? '0';
          topUpAmount = double.tryParse(rawAmt) ?? 0.0;
        }
      } else {
        // Positional fallback: Col0=ClientID, Col1=PAN, Col2=TopUpAmount
        // Or if Col0 looks like a date: Col0=Date, Col1=ClientID, Col2=PAN, Col3=Amount
        if (row.length >= 4 && row[0].toString().contains('/')) {
          transactionDate = row[0]?.toString().trim() ?? '';
          clientId = row[1]?.toString().trim() ?? '';
          pan = row[2]?.toString().trim() ?? '';
          topUpAmount = double.tryParse(
                  row[3]?.toString().replaceAll(',', '').trim() ?? '0') ??
              0.0;
        } else {
          clientId = row[0]?.toString().trim() ?? '';
          pan = row[1]?.toString().trim() ?? '';
          final rawAmt = row[row.length >= 4 ? 3 : 2]
                  ?.toString()
                  .replaceAll(',', '')
                  .trim() ??
              '0';
          topUpAmount = double.tryParse(rawAmt) ?? 0.0;
        }
      }

      // Skip rows without required identifiers or header echo
      if (clientId.isEmpty ||
          pan.isEmpty ||
          clientId.toLowerCase() == 'client id' ||
          clientId.toLowerCase() == 'client') {
        continue;
      }

      parsedRows.add({
        'transactionDate': transactionDate,
        'clientId': clientId,
        'pan': pan,
        'topUpAmount': topUpAmount,
      });
    }

    return parsedRows;
  }
}
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/utils/csv_parser_util.dart';
import '../../../../core/utils/file_saver_util.dart';
import '../../../../core/widgets/cbo_file_dropzone.dart';
import '../../../../core/widgets/cbo_metric_card.dart';
import '../../../../core/widgets/guided_recon_modal.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../../domain/entities/remote_dispute_models.dart';
import '../../domain/usecases/identify_remote_disputes_usecase.dart';

enum RemoteDisputeFilter {
  all,
  matched,
  mismatch,
  missed,
  candidate,
  settlementOnly,
}

class RemoteDisputeIdentificationDashboard extends StatefulWidget {
  const RemoteDisputeIdentificationDashboard({super.key});

  @override
  State<RemoteDisputeIdentificationDashboard> createState() =>
      _RemoteDisputeIdentificationDashboardState();
}

class _RemoteDisputeIdentificationDashboardState
    extends State<RemoteDisputeIdentificationDashboard> {
  final IdentifyRemoteDisputesUseCase _useCase =
      IdentifyRemoteDisputesUseCase();

  List<Map<String, dynamic>> _cbsRaw = [];
  List<Map<String, dynamic>> _settlementRaw = [];
  String? _cbsFileName;
  String? _settlementFileName;

  RemoteDisputeResult? _result;
  bool _isProcessing = false;
  bool _hasExecuted = false;
  RemoteDisputeFilter _selectedFilter = RemoteDisputeFilter.all;

  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  final NumberFormat _countFormat = NumberFormat('#,##0', 'en_US');

  void _showGuide() {
    GuidedReconModal.show(
      context,
      moduleTitle: 'Remote Dispute Identification Guide',
      modulePurpose:
          'Automatically matches CBS dispute records with settlement journals on 4 criteria: (1) Last 4 digits of PAN, (2) Retrieval Reference Number (RRN), (3) Transaction Amount, and (4) Acquirer Bank. Detects unreported duplicate customer errors on the settlement side and clusters all transactions by PAN.',
      steps: const [
        ReconStepGuide(
          step: 1,
          title: 'Load CBS Report File',
          format: '.CSV / .XLSX / .XLS',
          description:
              'Core Banking dispute report with columns: TRANS.REF, PAN.NUMBER, VALUE.DATE, DEBIT.ACCT.NO, Customer, Acquirer Bank, Branch, TXN.AMOUNT, RETRIEVAL.REF.NO.',
          expectedColumns: [
            'PAN.NUMBER',
            'TXN.AMOUNT',
            'RETRIEVAL.REF.NO',
            'Acquirer Bank'
          ],
        ),
        ReconStepGuide(
          step: 2,
          title: 'Load Settlement Report File',
          format: '.CSV / .XLSX / .XLS',
          description:
              'Switch/Settlement report with columns: Issuer, Acquirer, MTI, Card_Number, Amount, Currency, Transaction_Date, Transaction_Description, Terminal_ID, Transaction_Place, STAN_F11, Refnum_F37, Authidresp_F38, Fe_utrnno, Bo_utrnno.',
          expectedColumns: [
            'Card_Number',
            'Amount',
            'Refnum_F37',
            'Acquirer',
            'Fe_utrnno'
          ],
        ),
        ReconStepGuide(
          step: 3,
          title: 'Multi-Priority Matching & Bank Normalization',
          format: 'Automatic',
          description:
              'Normalizes 28+ Ethiopian bank names (e.g. "CBE ETS SETTL" ↔ "Commercial Bank of Ethiopia", "ABYSSINIA" ↔ "Bank of Abyssinia S.C"). Aligns bank automatically if RRN matches.',
        ),
        ReconStepGuide(
          step: 4,
          title: 'Unreported Duplicate Candidate Detection',
          format: 'Automatic',
          description:
              'Identifies other settlement attempts for the disputed card (same last 4 digits of PAN) and lists them with empty CBS rows to catch un-reported customer dispute errors.',
        ),
      ],
      tips: const [
        'Matching records are automatically grouped together by PAN so all related disputes appear consecutively.',
        'Prioritized matches and candidate settlement duplicates are styled prominently.',
        'Mismatches (PAN/RRN match but amount differs) and Missed CBS disputes are highlighted.',
        'Export multi-sheet Excel reports with full side-by-side reconciliation details.',
      ],
    );
  }

  /// Strips BOM, zero-width characters, and non-printable chars from a header string.
  static String _sanitizeHeader(String header) {
    return header
        .replaceAll('\uFEFF', '') // UTF-8 BOM
        .replaceAll('\uFFFE', '') // UTF-16 LE BOM
        .replaceAll('\u200B', '') // Zero-width space
        .replaceAll('\u200C', '') // Zero-width non-joiner
        .replaceAll('\u200D', '') // Zero-width joiner
        .replaceAll('\u00A0', ' ') // Non-breaking space → regular space
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '') // Control chars
        .trim();
  }

  List<List<dynamic>> _parseBytesToTable(Uint8List bytes, String fileName) {
    if (fileName.toLowerCase().endsWith('.xlsx') ||
        fileName.toLowerCase().endsWith('.xls')) {
      try {
        final excel = excel_pkg.Excel.decodeBytes(bytes);
        for (final table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet != null && sheet.rows.isNotEmpty) {
            return sheet.rows.map((row) {
              return row
                  .map((cell) => _sanitizeHeader(cell?.value?.toString() ?? ''))
                  .toList();
            }).toList();
          }
        }
      } catch (e) {
        debugPrint('Excel decoding fallback: $e');
      }
    }
    return CsvParserUtil.parseBytes(bytes);
  }

  bool _isHeaderRow(List<dynamic> row, bool isCbs) {
    if (row.isEmpty) return false;
    final firstCell = row[0]?.toString().trim().toUpperCase() ?? '';

    if (isCbs) {
      if (firstCell.contains('TRANS') ||
          firstCell.contains('PAN') ||
          firstCell.contains('REF') ||
          firstCell.contains('ACCOUNT') ||
          firstCell.contains('CUSTOMER')) {
        return true;
      }
    } else {
      if (firstCell.contains('ISSUER') ||
          firstCell.contains('ACQUIRER') ||
          firstCell.contains('CARD') ||
          firstCell.contains('PAN') ||
          firstCell.contains('AMOUNT') ||
          firstCell.contains('MTI')) {
        return true;
      }
    }
    return true;
  }

  Future<void> _pickFile(bool isCbs) async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (res != null && res.files.single.bytes != null) {
      final fileName = res.files.single.name;
      final data = _parseBytesToTable(res.files.single.bytes!, fileName);
      if (data.isEmpty) return;

      List<String> headers;
      List<List<dynamic>> dataRows;

      final bool hasHeaders = _isHeaderRow(data[0], isCbs);
      if (hasHeaders) {
        headers = data[0].map((e) => _sanitizeHeader(e.toString())).toList();
        dataRows = data.skip(1).toList();
      } else {
        if (isCbs) {
          headers = [
            'TRANS.REF',
            'PAN.NUMBER',
            'VALUE.DATE',
            'DEBIT.ACCT.NO',
            'Customer',
            'Acquirer Bank',
            'Branch',
            'TXN.AMOUNT',
            'RETRIEVAL.REF.NO'
          ];
        } else {
          headers = [
            'Issuer',
            'Acquirer',
            'MTI',
            'Card_Number',
            'Amount',
            'Currency',
            'Transaction_Date',
            'Transaction_Description',
            'Terminal_ID',
            'Transaction_Place',
            'STAN_F11',
            'Refnum_F37',
            'Authidresp_F38',
            'Fe_utrnno',
            'Bo_utrnno'
          ];
        }
        dataRows = data;
      }

      final mapped = dataRows
          .where((row) => row.any((cell) => cell.toString().trim().isNotEmpty))
          .map((row) {
        final m = <String, dynamic>{};
        for (int i = 0; i < headers.length; i++) {
          if (i < row.length) m[headers[i]] = row[i];
        }
        return m;
      }).where((m) {
        final firstVal = m.values.isNotEmpty
            ? m.values.first.toString().trim().toUpperCase()
            : '';
        return firstVal.isNotEmpty &&
            firstVal != 'GRAND TOTAL' &&
            firstVal != 'TOTAL' &&
            !firstVal.startsWith('TOTAL ');
      }).toList();

      setState(() {
        _hasExecuted = false;
        if (isCbs) {
          _cbsRaw = mapped;
          _cbsFileName = fileName;
        } else {
          _settlementRaw = mapped;
          _settlementFileName = fileName;
        }
      });
    }
  }

  void _runReconciliation() {
    if (_cbsRaw.isEmpty || _settlementRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please upload both CBS Report and Settlement Report files.'),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final result = _useCase(
      cbsRawData: _cbsRaw,
      settlementRawData: _settlementRaw,
    );

    setState(() {
      _result = result;
      _isProcessing = false;
      _hasExecuted = true;
      _selectedFilter = RemoteDisputeFilter.all;
    });
  }

  PlutoGridStateManager? _stateManager;

  void _setFilter(RemoteDisputeFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
    if (_stateManager != null) {
      _stateManager!.removeAllRows();
      _stateManager!.appendRows(_buildRows());
    }
  }

  List<PlutoColumn> _buildColumns() {
    return [
      PlutoColumn(
        title: 'Status',
        field: 'recon_status',
        type: PlutoColumnType.text(),
        width: 125,
        enableEditingMode: false,
        renderer: (ctx) => _statusBadge(ctx.cell.value.toString()),
      ),
      // CBS Columns in exact requested order
      PlutoColumn(
        title: 'TRANS.REF',
        field: 'cbs_trans_ref',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'PAN.NUMBER',
        field: 'cbs_pan_number',
        type: PlutoColumnType.text(),
        width: 165,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'VALUE.DATE',
        field: 'cbs_value_date',
        type: PlutoColumnType.text(),
        width: 110,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'DEBIT.ACCT.NO',
        field: 'cbs_debit_acct_no',
        type: PlutoColumnType.text(),
        width: 160,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Customer',
        field: 'cbs_customer',
        type: PlutoColumnType.text(),
        width: 180,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Acquirer Bank',
        field: 'cbs_acquirer_bank',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Branch',
        field: 'cbs_branch',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'TXN.AMOUNT',
        field: 'cbs_txn_amount',
        type: PlutoColumnType.currency(symbol: 'ETB '),
        width: 140,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'RETRIEVAL.REF.NO',
        field: 'cbs_retrieval_ref_no',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
      ),

      // Settlement Columns in exact requested order
      PlutoColumn(
        title: 'Issuer',
        field: 'set_issuer',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Acquirer',
        field: 'set_acquirer',
        type: PlutoColumnType.text(),
        width: 180,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'MTI',
        field: 'set_mti',
        type: PlutoColumnType.text(),
        width: 90,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Card_Number',
        field: 'set_card_number',
        type: PlutoColumnType.text(),
        width: 165,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Amount',
        field: 'set_amount',
        type: PlutoColumnType.currency(symbol: 'ETB '),
        width: 150,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Currency',
        field: 'set_currency',
        type: PlutoColumnType.text(),
        width: 90,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Transaction_Date',
        field: 'set_transaction_date',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Transaction_Description',
        field: 'set_transaction_description',
        type: PlutoColumnType.text(),
        width: 180,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Terminal_ID',
        field: 'set_terminal_id',
        type: PlutoColumnType.text(),
        width: 130,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Transaction_Place',
        field: 'set_transaction_place',
        type: PlutoColumnType.text(),
        width: 160,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'STAN_F11',
        field: 'set_stan_f11',
        type: PlutoColumnType.text(),
        width: 100,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Refnum_F37',
        field: 'set_refnum_f37',
        type: PlutoColumnType.text(),
        width: 160,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Authidresp_F38',
        field: 'set_authidresp_f38',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Fe_utrnno',
        field: 'set_fe_utrnno',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Bo_utrnno',
        field: 'set_bo_utrnno',
        type: PlutoColumnType.text(),
        width: 140,
        enableEditingMode: false,
      ),
      PlutoColumn(
        title: 'Notes',
        field: 'notes',
        type: PlutoColumnType.text(),
        width: 250,
        enableEditingMode: false,
      ),
    ];
  }

  Widget _statusBadge(String val) {
    Color bg;
    Color fg;

    switch (val) {
      case 'MATCHED':
        bg = CboColors.statusOkBg;
        fg = CboColors.statusOkText;
        break;
      case 'MISMATCH':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        break;
      case 'MISSED':
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
        break;
      case 'CANDIDATE':
        bg = const Color(0xFFE0F7FA);
        fg = const Color(0xFF006064);
        break;
      default:
        bg = const Color(0xFFF5F5F5);
        fg = const Color(0xFF616161);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        val,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  List<PlutoRow> _buildRows() {
    if (_result == null) return [];

    List<RemoteDisputeReconRow> filtered;
    switch (_selectedFilter) {
      case RemoteDisputeFilter.all:
        filtered = _result!.allRows;
        break;
      case RemoteDisputeFilter.matched:
        filtered = _result!.matchedRows;
        break;
      case RemoteDisputeFilter.mismatch:
        filtered = _result!.mismatchRows;
        break;
      case RemoteDisputeFilter.missed:
        filtered = _result!.missedRows;
        break;
      case RemoteDisputeFilter.candidate:
        filtered = _result!.candidateRows;
        break;
      case RemoteDisputeFilter.settlementOnly:
        filtered = _result!.settlementOnlyRows;
        break;
    }

    return filtered.map((r) => r.toPlutoRow()).toList();
  }

  Future<void> _exportResults() async {
    if (_result == null || !_hasExecuted) return;

    final excel = excel_pkg.Excel.createExcel();

    final headers = [
      'Recon Status',
      'TRANS.REF',
      'PAN.NUMBER',
      'VALUE.DATE',
      'DEBIT.ACCT.NO',
      'Customer',
      'Acquirer Bank',
      'Branch',
      'TXN.AMOUNT',
      'RETRIEVAL.REF.NO',
      'Issuer',
      'Acquirer',
      'MTI',
      'Card_Number',
      'Amount',
      'Currency',
      'Transaction_Date',
      'Transaction_Description',
      'Terminal_ID',
      'Transaction_Place',
      'STAN_F11',
      'Refnum_F37',
      'Authidresp_F38',
      'Fe_utrnno',
      'Bo_utrnno',
      'Notes',
    ];

    void appendReconRows(
        excel_pkg.Sheet sheet, List<RemoteDisputeReconRow> rows) {
      sheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());
      for (final r in rows) {
        sheet.appendRow([
          excel_pkg.TextCellValue(r.statusText),
          excel_pkg.TextCellValue(r.cbs?.transRef ?? ''),
          excel_pkg.TextCellValue(r.cbs?.panNumber ?? ''),
          excel_pkg.TextCellValue(r.cbs?.valueDate ?? ''),
          excel_pkg.TextCellValue(r.cbs?.debitAcctNo ?? ''),
          excel_pkg.TextCellValue(r.cbs?.customer ?? ''),
          excel_pkg.TextCellValue(r.cbs?.acquirerBank ?? ''),
          excel_pkg.TextCellValue(r.cbs?.branch ?? ''),
          excel_pkg.DoubleCellValue(r.cbs?.txnAmount ?? 0.0),
          excel_pkg.TextCellValue(r.cbs?.retrievalRefNo ?? ''),
          excel_pkg.TextCellValue(r.settlement?.issuer ?? ''),
          excel_pkg.TextCellValue(r.settlement?.acquirer ?? ''),
          excel_pkg.TextCellValue(r.settlement?.mti ?? ''),
          excel_pkg.TextCellValue(r.settlement?.cardNumber ?? ''),
          excel_pkg.DoubleCellValue(r.settlement?.amount ?? 0.0),
          excel_pkg.TextCellValue(r.settlement?.currency ?? ''),
          excel_pkg.TextCellValue(r.settlement?.transactionDate ?? ''),
          excel_pkg.TextCellValue(r.settlement?.transactionDescription ?? ''),
          excel_pkg.TextCellValue(r.settlement?.terminalId ?? ''),
          excel_pkg.TextCellValue(r.settlement?.transactionPlace ?? ''),
          excel_pkg.TextCellValue(r.settlement?.stanF11 ?? ''),
          excel_pkg.TextCellValue(r.settlement?.refnumF37 ?? ''),
          excel_pkg.TextCellValue(r.settlement?.authidrespF38 ?? ''),
          excel_pkg.TextCellValue(r.settlement?.feUtrnno ?? ''),
          excel_pkg.TextCellValue(r.settlement?.boUtrnno ?? ''),
          excel_pkg.TextCellValue(r.notes),
        ]);
      }
    }

    // 1. Combined Sheet
    final combinedSheet = excel['Combined_Recon'];
    appendReconRows(combinedSheet, _result!.allRows);

    // 2. Matched Prioritized Sheet
    if (_result!.matchedRows.isNotEmpty) {
      final matchedSheet = excel['Matched_Prioritized'];
      appendReconRows(matchedSheet, _result!.matchedRows);
    }

    // 3. Amount Mismatches Sheet
    if (_result!.mismatchRows.isNotEmpty) {
      final mismatchSheet = excel['Amount_Mismatches'];
      appendReconRows(mismatchSheet, _result!.mismatchRows);
    }

    // 4. Candidate Duplicates Sheet
    if (_result!.candidateRows.isNotEmpty) {
      final candidateSheet = excel['Candidate_Duplicates'];
      appendReconRows(candidateSheet, _result!.candidateRows);
    }

    // 5. Missed CBS Sheet
    if (_result!.missedRows.isNotEmpty) {
      final missedSheet = excel['Missed_CBS'];
      appendReconRows(missedSheet, _result!.missedRows);
    }

    // 6. Summary Sheet
    final summarySheet = excel['Summary'];
    summarySheet.appendRow(
        [excel_pkg.TextCellValue('Metric'), excel_pkg.TextCellValue('Value')]);
    summarySheet.appendRow([
      excel_pkg.TextCellValue('Total Matched Records (Prioritized)'),
      excel_pkg.IntCellValue(_result!.totalMatchedCount)
    ]);
    summarySheet.appendRow([
      excel_pkg.TextCellValue('Total Matched Amount (ETB)'),
      excel_pkg.DoubleCellValue(_result!.totalMatchedCbsAmount)
    ]);
    summarySheet.appendRow([
      excel_pkg.TextCellValue('Amount Mismatches Count'),
      excel_pkg.IntCellValue(_result!.totalMismatchCount)
    ]);
    summarySheet.appendRow([
      excel_pkg.TextCellValue('Amount Mismatch CBS Amount (ETB)'),
      excel_pkg.DoubleCellValue(_result!.totalMismatchCbsAmount)
    ]);
    summarySheet.appendRow([
      excel_pkg.TextCellValue('Missed CBS Disputes Count'),
      excel_pkg.IntCellValue(_result!.totalMissedCount)
    ]);
    summarySheet.appendRow([
      excel_pkg.TextCellValue('Missed CBS Amount (ETB)'),
      excel_pkg.DoubleCellValue(_result!.totalMissedCbsAmount)
    ]);
    summarySheet.appendRow([
      excel_pkg.TextCellValue('Unreported Candidate Settlement Entries'),
      excel_pkg.IntCellValue(_result!.totalCandidateCount)
    ]);
    summarySheet.appendRow([
      excel_pkg.TextCellValue('Candidate Settlement Amount (ETB)'),
      excel_pkg.DoubleCellValue(_result!.totalCandidateSettlementAmount)
    ]);
    summarySheet.appendRow([
      excel_pkg.TextCellValue('Total Reconciliation Rows'),
      excel_pkg.IntCellValue(_result!.totalRowCount)
    ]);

    if (excel.sheets.containsKey('Sheet1') && excel.sheets.length > 1) {
      excel.delete('Sheet1');
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      await FileSaverUtil.saveBytes(
        bytes: Uint8List.fromList(fileBytes),
        fileName:
            'Remote_Dispute_Identification_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Remote Dispute Excel report exported successfully!')),
        );
      }
    }
  }

  Widget _buildSummaryBanner() {
    if (_result == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 800;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsBlock(
                  'PRIORITIZED MATCHES:',
                  'Fully Matched: ${_countFormat.format(_result!.totalMatchedCount)} records',
                  'Total Amount: ${_currencyFormat.format(_result!.totalMatchedCbsAmount)} ETB',
                ),
                const Divider(color: Colors.white24, height: 18),
                _buildStatsBlock(
                  'DISPUTE EXCEPTIONS:',
                  'Amount Mismatches: ${_countFormat.format(_result!.totalMismatchCount)} (${_currencyFormat.format(_result!.totalMismatchCbsAmount)} ETB)',
                  'Missed CBS: ${_countFormat.format(_result!.totalMissedCount)} (${_currencyFormat.format(_result!.totalMissedCbsAmount)} ETB)',
                ),
                const Divider(color: Colors.white24, height: 18),
                _buildStatsBlock(
                  'UNREPORTED DUPLICATES:',
                  'Candidate Entries: ${_countFormat.format(_result!.totalCandidateCount)} records',
                  'Settlement Amount: ${_currencyFormat.format(_result!.totalCandidateSettlementAmount)} ETB',
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildStatsBlock(
                  'PRIORITIZED MATCHES:',
                  'Fully Matched: ${_countFormat.format(_result!.totalMatchedCount)} records',
                  'Total Amount: ${_currencyFormat.format(_result!.totalMatchedCbsAmount)} ETB',
                ),
              ),
              Container(width: 1, height: 60, color: Colors.white30),
              Expanded(
                child: _buildStatsBlock(
                  'DISPUTE EXCEPTIONS:',
                  'Amount Mismatches: ${_countFormat.format(_result!.totalMismatchCount)} (${_currencyFormat.format(_result!.totalMismatchCbsAmount)} ETB)',
                  'Missed CBS: ${_countFormat.format(_result!.totalMissedCount)} (${_currencyFormat.format(_result!.totalMissedCbsAmount)} ETB)',
                ),
              ),
              Container(width: 1, height: 60, color: Colors.white30),
              Expanded(
                child: _buildStatsBlock(
                  'UNREPORTED DUPLICATES:',
                  'Candidate Entries: ${_countFormat.format(_result!.totalCandidateCount)} records',
                  'Settlement Amount: ${_currencyFormat.format(_result!.totalCandidateSettlementAmount)} ETB',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsBlock(String title, String line1, String line2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            line1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            line2,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveShell(
      currentRoute: '/remote_dispute_identification',
      title: 'Remote Dispute Identification',
      subtitle:
          'Cross-Bank Card Dispute & Unreported Duplicate Error Detection Engine',
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded,
              color: CboColors.slateMedium),
          tooltip: 'Calculation Guide',
          onPressed: _showGuide,
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Metric Cards HUD
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 900;
                final metrics = [
                  CboMetricCard(
                    title: 'Prioritized Matches',
                    value: _result != null
                        ? '${_currencyFormat.format(_result!.totalMatchedCbsAmount)} ETB'
                        : '0.00 ETB',
                    subtitle: _result != null
                        ? '${_countFormat.format(_result!.totalMatchedCount)} Fully Matched'
                        : 'Awaiting Execution',
                    icon: Icons.check_circle_rounded,
                    color: CboColors.primaryCyan,
                  ),
                  CboMetricCard(
                    title: 'Amount Mismatches',
                    value: _result != null
                        ? '${_currencyFormat.format(_result!.totalMismatchCbsAmount)} ETB'
                        : '0.00 ETB',
                    subtitle: _result != null
                        ? '${_countFormat.format(_result!.totalMismatchCount)} Records Differ'
                        : 'Exceptions Isolated',
                    icon: Icons.error_outline_rounded,
                    color: const Color(0xFFC62828),
                  ),
                  CboMetricCard(
                    title: 'Missed CBS Disputes',
                    value: _result != null
                        ? '${_currencyFormat.format(_result!.totalMissedCbsAmount)} ETB'
                        : '0.00 ETB',
                    subtitle: _result != null
                        ? '${_countFormat.format(_result!.totalMissedCount)} Unmatched in Settlement'
                        : 'Exceptions Isolated',
                    icon: Icons.warning_amber_rounded,
                    color: CboColors.accentGold,
                  ),
                  CboMetricCard(
                    title: 'Unreported Candidates',
                    value: _result != null
                        ? '${_currencyFormat.format(_result!.totalCandidateSettlementAmount)} ETB'
                        : '0.00 ETB',
                    subtitle: _result != null
                        ? '${_countFormat.format(_result!.totalCandidateCount)} Duplicate Settlement Attempts'
                        : 'Duplicate Discovery',
                    icon: Icons.find_in_page_rounded,
                    color: const Color(0xFF00838F),
                  ),
                ];

                if (isCompact) {
                  return Column(
                    children: metrics
                        .map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: m))
                        .toList(),
                  );
                }

                return Row(
                  children: [
                    for (int i = 0; i < metrics.length; i++) ...[
                      Expanded(child: metrics[i]),
                      if (i < metrics.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // Dropzone Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 800;
                final file1 = CboFileDropzone(
                  title: '1. CBS Dispute Report File',
                  subtitle:
                      'Upload CBS extract (TRANS.REF, PAN, Amount, RRN, Acquirer Bank)',
                  icon: Icons.account_balance_rounded,
                  fileName: _cbsFileName,
                  rowCount: _cbsRaw.length,
                  onTap: () => _pickFile(true),
                );

                final file2 = CboFileDropzone(
                  title: '2. Settlement Report File',
                  subtitle:
                      'Upload settlement report (Acquirer, Card_Number, Amount, Refnum_F37, Fe_utrnno)',
                  icon: Icons.receipt_long_rounded,
                  fileName: _settlementFileName,
                  rowCount: _settlementRaw.length,
                  onTap: () => _pickFile(false),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      file1,
                      const SizedBox(height: 14),
                      file2,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: file1),
                    const SizedBox(width: 16),
                    Expanded(child: file2),
                  ],
                );
              },
            ),

            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _runReconciliation,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(_isProcessing
                      ? 'Identifying Disputes...'
                      : 'Identify Remote Disputes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CboColors.primaryCyan,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                if (_hasExecuted)
                  OutlinedButton.icon(
                    onPressed: _exportResults,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Export Multi-Sheet Excel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CboColors.primaryCyanDark,
                      side: const BorderSide(color: CboColors.primaryCyan),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),

            if (_hasExecuted && _result != null) ...[
              const SizedBox(height: 20),
              _buildSummaryBanner(),
              const SizedBox(height: 20),

              // Filter Tabs Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CboColors.cardBorder),
                ),
                child: Row(
                  children: [
                    _buildTabButton(
                      'All Records (${_result!.totalRowCount})',
                      RemoteDisputeFilter.all,
                      Icons.list_alt_rounded,
                    ),
                    _buildTabButton(
                      'Matched (${_result!.totalMatchedCount})',
                      RemoteDisputeFilter.matched,
                      Icons.check_circle_outline_rounded,
                    ),
                    _buildTabButton(
                      'Mismatches (${_result!.totalMismatchCount})',
                      RemoteDisputeFilter.mismatch,
                      Icons.error_outline_rounded,
                    ),
                    _buildTabButton(
                      'Missed CBS (${_result!.totalMissedCount})',
                      RemoteDisputeFilter.missed,
                      Icons.warning_amber_rounded,
                    ),
                    _buildTabButton(
                      'Candidates (${_result!.totalCandidateCount})',
                      RemoteDisputeFilter.candidate,
                      Icons.find_in_page_outlined,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // PlutoGrid Data Table Container
              Container(
                height: 540,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CboColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PlutoGrid(
                    key: ValueKey(
                        'grid_${_selectedFilter}_${_result?.totalRowCount}'),
                    columns: _buildColumns(),
                    rows: _buildRows(),
                    onLoaded: (PlutoGridOnLoadedEvent event) {
                      _stateManager = event.stateManager;
                    },
                    configuration: const PlutoGridConfiguration(
                      style: PlutoGridStyleConfig(
                        gridBorderColor: CboColors.cardBorder,
                        rowHeight: 44,
                        columnHeight: 46,
                        defaultCellPadding:
                            EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(
      String label, RemoteDisputeFilter filter, IconData icon) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: InkWell(
        onTap: () => _setFilter(filter),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? CboColors.primaryCyan.withValues(alpha: 0.12)
                : Colors.transparent,
            border: isSelected
                ? const Border(
                    bottom: BorderSide(color: CboColors.primaryCyan, width: 3))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? CboColors.primaryCyanDark
                    : CboColors.slateMedium,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? CboColors.primaryCyanDark
                        : CboColors.slateDark,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
